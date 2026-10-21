package io.nem.keycloak.knowhub.client;

import static io.nem.keycloak.knowhub.KnowHubConstants.API_AUDIENCE;
import static io.nem.keycloak.knowhub.KnowHubConstants.CREDENTIAL_CLAIM;
import static io.nem.keycloak.knowhub.KnowHubConstants.ATTR_CREDENTIAL;
import static io.nem.keycloak.knowhub.KnowHubConstants.ATTR_MANAGED;
import static io.nem.keycloak.knowhub.KnowHubConstants.ATTR_SPEC_HASH;
import static io.nem.keycloak.knowhub.KnowHubConstants.ATTR_TENANT;
import static io.nem.keycloak.knowhub.KnowHubConstants.TENANT_CLAIM;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.keycloak.representations.idm.ClientRepresentation;
import org.keycloak.representations.idm.ProtocolMapperRepresentation;

public final class ClientSpecFactory {
    public ClientRepresentation create(
            String tenantId, UUID credentialId, ManagedClientIdentity identity) {
        ClientRepresentation representation = new ClientRepresentation();
        representation.setClientId(identity.clientId());
        representation.setName("KnowHub MCP credential " + credentialId);
        representation.setDescription("Tenant-scoped KnowHub MCP service account");
        representation.setProtocol("openid-connect");
        representation.setEnabled(true);
        representation.setPublicClient(false);
        representation.setBearerOnly(false);
        representation.setStandardFlowEnabled(false);
        representation.setImplicitFlowEnabled(false);
        representation.setDirectAccessGrantsEnabled(false);
        representation.setServiceAccountsEnabled(true);
        representation.setFullScopeAllowed(false);
        representation.setAttributes(Map.of(
                ATTR_MANAGED, "true",
                ATTR_TENANT, tenantId,
                ATTR_CREDENTIAL, credentialId.toString(),
                ATTR_SPEC_HASH, identity.specHash()));
        representation.setProtocolMappers(List.of(
                hardcodedClaim("tenant-id", TENANT_CLAIM, tenantId),
                hardcodedClaim("mcp-credential-id", CREDENTIAL_CLAIM, credentialId.toString()),
                audienceMapper()));
        return representation;
    }

    private static ProtocolMapperRepresentation hardcodedClaim(
            String name, String claimName, String value) {
        ProtocolMapperRepresentation mapper = new ProtocolMapperRepresentation();
        mapper.setName(name);
        mapper.setProtocol("openid-connect");
        mapper.setProtocolMapper("oidc-hardcoded-claim-mapper");
        mapper.setConfig(Map.of(
                "claim.name", claimName,
                "claim.value", value,
                "jsonType.label", "String",
                "access.token.claim", "true",
                "id.token.claim", "false",
                "userinfo.token.claim", "false",
                "introspection.token.claim", "true"));
        return mapper;
    }

    private static ProtocolMapperRepresentation audienceMapper() {
        ProtocolMapperRepresentation mapper = new ProtocolMapperRepresentation();
        mapper.setName("knowhub-api-audience");
        mapper.setProtocol("openid-connect");
        mapper.setProtocolMapper("oidc-audience-mapper");
        mapper.setConfig(Map.of(
                "included.client.audience", API_AUDIENCE,
                "access.token.claim", "true",
                "id.token.claim", "false",
                "introspection.token.claim", "true"));
        return mapper;
    }
}
