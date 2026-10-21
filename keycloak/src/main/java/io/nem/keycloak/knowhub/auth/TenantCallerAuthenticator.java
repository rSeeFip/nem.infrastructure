package io.nem.keycloak.knowhub.auth;

import static io.nem.keycloak.knowhub.KnowHubConstants.ATTR_PROVISIONER;
import static io.nem.keycloak.knowhub.KnowHubConstants.ATTR_TENANT;
import static io.nem.keycloak.knowhub.KnowHubConstants.PROVISIONING_AUDIENCE;
import static io.nem.keycloak.knowhub.KnowHubConstants.TENANT_CLAIM;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotAuthorizedException;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.UriInfo;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Set;
import org.keycloak.models.ClientModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;
import org.keycloak.representations.AccessToken;
import org.keycloak.services.managers.AppAuthManager;
import org.keycloak.services.managers.AuthenticationManager.AuthResult;

public final class TenantCallerAuthenticator {
    private static final Set<String> BROAD_ROLES =
            Set.of("manage-clients", "manage-users", "realm-admin");

    private final KeycloakSession session;
    private final RealmModel realm;

    public TenantCallerAuthenticator(KeycloakSession session, RealmModel realm) {
        this.session = session;
        this.realm = realm;
    }

    public TenantCaller authenticate(HttpHeaders headers, UriInfo uriInfo) {
        AuthResult auth = new AppAuthManager.BearerTokenAuthenticator(session)
                .setRealm(realm)
                .setUriInfo(uriInfo)
                .setHeaders(headers)
                .setAudience(PROVISIONING_AUDIENCE)
                .authenticate();
        if (auth == null) {
            throw new NotAuthorizedException("Bearer");
        }

        AccessToken token = auth.getToken();
        ClientModel client = auth.getClient();
        UserModel user = auth.getUser();
        if (token == null || client == null || user == null) {
            throw new ForbiddenException();
        }
        if (!"true".equals(client.getAttribute(ATTR_PROVISIONER))) {
            throw new ForbiddenException();
        }
        if (!client.getId().equals(user.getServiceAccountClientLink())) {
            throw new ForbiddenException();
        }
        rejectBroadRealmManagementRoles(token);

        Object rawTenant = token.getOtherClaims().get(TENANT_CLAIM);
        String clientTenant = client.getAttribute(ATTR_TENANT);
        if (!(rawTenant instanceof String tenant)
                || tenant.isBlank()
                || tenant.length() > 128
                || clientTenant == null
                || !constantTimeEquals(tenant, clientTenant)) {
            throw new ForbiddenException();
        }
        return new TenantCaller(tenant, client, user, token);
    }

    private static void rejectBroadRealmManagementRoles(AccessToken token) {
        AccessToken.Access access = token.getResourceAccess("realm-management");
        if (access != null && access.getRoles() != null
                && access.getRoles().stream().anyMatch(BROAD_ROLES::contains)) {
            throw new ForbiddenException();
        }
    }

    private static boolean constantTimeEquals(String left, String right) {
        return MessageDigest.isEqual(
                left.getBytes(StandardCharsets.UTF_8),
                right.getBytes(StandardCharsets.UTF_8));
    }
}
