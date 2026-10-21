package io.nem.keycloak.knowhub.client;

import static io.nem.keycloak.knowhub.KnowHubConstants.ATTR_CREDENTIAL;
import static io.nem.keycloak.knowhub.KnowHubConstants.ATTR_MANAGED;
import static io.nem.keycloak.knowhub.KnowHubConstants.ATTR_SPEC_HASH;
import static io.nem.keycloak.knowhub.KnowHubConstants.ATTR_TENANT;
import static io.nem.keycloak.knowhub.KnowHubConstants.READER_ROLE;

import io.nem.keycloak.knowhub.api.TenantClientResponse;
import jakarta.ws.rs.ClientErrorException;
import jakarta.ws.rs.InternalServerErrorException;
import jakarta.ws.rs.NotFoundException;
import java.util.UUID;
import org.keycloak.models.ClientModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.RoleModel;
import org.keycloak.models.UserModel;
import org.keycloak.services.managers.ClientManager;
import org.keycloak.services.managers.RealmManager;
import org.keycloak.validation.ValidationUtil;

public final class TenantClientService {
    private final KeycloakSession session;
    private final RealmModel realm;
    private final ClientSpecFactory specFactory = new ClientSpecFactory();

    public TenantClientService(KeycloakSession session, RealmModel realm) {
        this.session = session;
        this.realm = realm;
    }

    public TenantClientResponse create(String tenantId, UUID credentialId) {
        ManagedClientIdentity identity = ManagedClientIdentity.from(tenantId, credentialId);
        ClientModel existing = session.clients().getClientByClientId(realm, identity.clientId());
        if (existing != null) {
            return existingResponse(existing, tenantId, credentialId, identity);
        }

        try {
            ClientModel client = ClientManager.createClient(
                    session, realm, specFactory.create(tenantId, credentialId, identity));
            ValidationUtil.validateClient(session, client, true, result -> {
                session.getTransactionManager().setRollbackOnly();
                throw new IllegalArgumentException(result.getAllErrorsAsString());
            });
            new ClientManager(new RealmManager(session)).enableServiceAccount(client);
            UserModel serviceAccount = session.users().getServiceAccount(client);
            RoleModel readerRole = realm.getRole(READER_ROLE);
            if (serviceAccount == null || readerRole == null) {
                throw new IllegalStateException("required service-account role is unavailable");
            }
            serviceAccount.getRealmRoleMappingsStream().forEach(serviceAccount::deleteRoleMapping);
            serviceAccount.grantRole(readerRole);
            client.addScopeMapping(readerRole);
            String secret = client.getSecret();
            if (secret == null || secret.isBlank()) {
                throw new IllegalStateException("confidential client secret was not generated");
            }
            return TenantClientResponse.created(
                    client.getClientId(), credentialId.toString(), secret);
        } catch (RuntimeException exception) {
            session.getTransactionManager().setRollbackOnly();
            throw new InternalServerErrorException("tenant client provisioning failed");
        }
    }

    public void revoke(String tenantId, UUID credentialId) {
        ManagedClientIdentity identity = ManagedClientIdentity.from(tenantId, credentialId);
        ClientModel client = session.clients().getClientByClientId(realm, identity.clientId());
        if (!isOwned(client, tenantId, credentialId)) {
            throw new NotFoundException();
        }
        boolean removed = new ClientManager(new RealmManager(session)).removeClient(realm, client);
        if (!removed) {
            session.getTransactionManager().setRollbackOnly();
            throw new InternalServerErrorException("tenant client revocation failed");
        }
    }

    private static TenantClientResponse existingResponse(
            ClientModel client,
            String tenantId,
            UUID credentialId,
            ManagedClientIdentity identity) {
        if (!isOwned(client, tenantId, credentialId)) {
            throw new NotFoundException();
        }
        if (!identity.specHash().equals(client.getAttribute(ATTR_SPEC_HASH))) {
            throw new ClientErrorException(
                    "existing credential specification differs",
                    jakarta.ws.rs.core.Response.Status.CONFLICT);
        }
        return TenantClientResponse.existing(client.getClientId(), credentialId.toString());
    }

    private static boolean isOwned(ClientModel client, String tenantId, UUID credentialId) {
        return client != null
                && "true".equals(client.getAttribute(ATTR_MANAGED))
                && tenantId.equals(client.getAttribute(ATTR_TENANT))
                && credentialId.toString().equals(client.getAttribute(ATTR_CREDENTIAL));
    }
}
