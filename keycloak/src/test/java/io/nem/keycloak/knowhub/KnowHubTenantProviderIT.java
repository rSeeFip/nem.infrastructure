package io.nem.keycloak.knowhub;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import java.net.http.HttpResponse;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.stream.StreamSupport;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
final class KnowHubTenantProviderIT {
    private static final String REALM = "knowhub-test";
    private static final String ROLLBACK_REALM = "knowhub-rollback-test";
    private static final String TENANT_A = "tenant-a";
    private static final String TENANT_B = "tenant-b";

    private KeycloakTestServer server;
    private String tenantAToken;
    private String tenantBToken;
    private String wrongAudienceToken;
    private String normalUserToken;
    private String rollbackToken;

    @BeforeAll
    void startKeycloak() throws Exception {
        server = new KeycloakTestServer();
        server.start();
        server.createRealm(REALM, true);
        String tenantASecret = server.createProvisioner(
                REALM, "tenant-a-provisioner", TENANT_A, KnowHubConstants.PROVISIONING_AUDIENCE);
        String tenantBSecret = server.createProvisioner(
                REALM, "tenant-b-provisioner", TENANT_B, KnowHubConstants.PROVISIONING_AUDIENCE);
        String wrongAudienceSecret = server.createProvisioner(
                REALM, "wrong-audience-provisioner", TENANT_A, "not-provisioning");
        String userPassword = server.createNormalUserClient(
                REALM, "normal-user-client", "normal-user", TENANT_A);

        tenantAToken = token(REALM, "tenant-a-provisioner", tenantASecret);
        tenantBToken = token(REALM, "tenant-b-provisioner", tenantBSecret);
        wrongAudienceToken = token(REALM, "wrong-audience-provisioner", wrongAudienceSecret);
        normalUserToken = server.userToken(
                REALM, "normal-user-client", "normal-user", userPassword)
                .path("access_token").asText();

        server.createRealm(ROLLBACK_REALM, false);
        String rollbackSecret = server.createProvisioner(
                ROLLBACK_REALM,
                "rollback-provisioner",
                TENANT_A,
                KnowHubConstants.PROVISIONING_AUDIENCE);
        rollbackToken = token(ROLLBACK_REALM, "rollback-provisioner", rollbackSecret);
    }

    @AfterAll
    void stopKeycloak() {
        if (server != null) {
            server.close();
        }
    }

    @Test
    void createsExactlyScopedCredentialAndReturnsSecretOnlyOnce() throws Exception {
        assertEquals("KnowHub.ArachneReader", KnowHubConstants.READER_ROLE);
        UUID credentialId = UUID.fromString("11111111-1111-4111-8111-111111111111");
        HttpResponse<String> created = create(REALM, tenantAToken, credentialId);
        assertStatus(created, 201);
        assertTrue(created.headers().firstValue("Cache-Control").orElse("").contains("no-store"));
        assertEquals("no-cache", created.headers().firstValue("Pragma").orElse(""));
        JsonNode createdBody = server.parse(created.body());
        assertTrue(createdBody.path("created").asBoolean());
        String clientId = createdBody.path("client_id").asText();
        String clientSecret = createdBody.path("client_secret").asText();
        assertFalse(clientId.isBlank());
        assertFalse(clientSecret.isBlank());
        assertEquals(credentialId.toString(), createdBody.path("mcp_credential_id").asText());

        JsonNode tokenResponse = server.clientCredentialsToken(REALM, clientId, clientSecret);
        String issuedToken = tokenResponse.path("access_token").asText();
        JsonNode claims = server.decodeJwtPayload(issuedToken);
        assertEquals(TENANT_A, claims.path(KnowHubConstants.TENANT_CLAIM).asText());
        assertEquals(credentialId.toString(), claims.path(KnowHubConstants.CREDENTIAL_CLAIM).asText());
        assertAudience(claims.path("aud"), KnowHubConstants.API_AUDIENCE);
        assertEquals(Set.of(KnowHubConstants.READER_ROLE), stringSet(
                claims.path("realm_access").path("roles")));

        HttpResponse<String> duplicate = create(REALM, tenantAToken, credentialId);
        assertStatus(duplicate, 200);
        JsonNode duplicateBody = server.parse(duplicate.body());
        assertFalse(duplicateBody.path("created").asBoolean());
        assertEquals(clientId, duplicateBody.path("client_id").asText());
        assertFalse(duplicateBody.has("client_secret"));
    }

    @Test
    void deniesWrongAudienceNormalUserAndCrossTenantInput() throws Exception {
        UUID credentialId = UUID.fromString("22222222-2222-4222-8222-222222222222");
        assertStatus(create(REALM, wrongAudienceToken, credentialId), 401);
        assertStatus(create(REALM, normalUserToken, credentialId), 403);

        String crossTenantBody = "{\"mcp_credential_id\":\"" + credentialId
                + "\",\"tenant_id\":\"" + TENANT_A + "\"}";
        assertStatus(server.providerRequest(
                "POST", REALM, "", tenantBToken, crossTenantBody), 400);
    }

    @Test
    void callerHasNoBroadRolesAndCannotUseAdminClientOperations() throws Exception {
        JsonNode claims = server.decodeJwtPayload(tenantAToken);
        JsonNode managementRoles = claims.path("resource_access")
                .path("realm-management").path("roles");
        assertTrue(managementRoles.isMissingNode() || managementRoles.isEmpty());

        JsonNode unrelated = server.findClients(REALM, "normal-user-client").get(0);
        String unrelatedId = unrelated.path("id").asText();
        assertFalse(unrelatedId.isBlank());
        assertStatus(server.adminClientOperation(
                "POST", REALM, "", tenantAToken, "{\"clientId\":\"forbidden\"}"), 403);
        assertStatus(server.adminClientOperation(
                "PUT", REALM, "/" + unrelatedId, tenantAToken,
                "{\"clientId\":\"normal-user-client\",\"enabled\":false}"), 403);
        assertStatus(server.adminClientOperation(
                "DELETE", REALM, "/" + unrelatedId, tenantAToken, null), 403);
    }

    @Test
    void onlyOwnerCanRevokeAndRevocationInvalidatesSecret() throws Exception {
        UUID credentialId = UUID.fromString("33333333-3333-4333-8333-333333333333");
        JsonNode created = server.parse(create(REALM, tenantAToken, credentialId).body());
        String clientId = created.path("client_id").asText();
        String secret = created.path("client_secret").asText();
        assertNotNull(secret);

        assertStatus(server.providerRequest(
                "DELETE", REALM, "/" + credentialId, tenantBToken, null), 404);
        assertStatus(server.providerRequest(
                "DELETE", REALM, "/" + credentialId, tenantAToken, null), 204);
        assertEquals(401, server.clientCredentialsTokenStatus(REALM, clientId, secret));
        assertStatus(server.providerRequest(
                "DELETE", REALM, "/" + credentialId, tenantAToken, null), 404);
    }

    @Test
    void requiredRoleValidationFailureRollsBackCreatedClient() throws Exception {
        UUID credentialId = UUID.fromString("44444444-4444-4444-8444-444444444444");
        HttpResponse<String> response = create(ROLLBACK_REALM, rollbackToken, credentialId);
        assertStatus(response, 500);
        String clientId = io.nem.keycloak.knowhub.client.ManagedClientIdentity
                .from(TENANT_A, credentialId).clientId();
        assertTrue(server.findClients(ROLLBACK_REALM, clientId).isEmpty());
    }

    @Test
    void rejectsUnknownFieldsUnsupportedMethodsAndUnknownRevocation() throws Exception {
        UUID credentialId = UUID.fromString("55555555-5555-4555-8555-555555555555");
        String unknownField = "{\"mcp_credential_id\":\"" + credentialId
                + "\",\"client_id\":\"arbitrary\"}";
        assertStatus(server.providerRequest(
                "POST", REALM, "", tenantAToken, unknownField), 400);
        assertStatus(server.providerRequest(
                "PUT", REALM, "", tenantAToken, "{}"), 405);
        assertStatus(server.providerRequest(
                "DELETE", REALM, "/" + credentialId, tenantAToken, null), 404);
    }

    @Test
    void acceptsPublicIssuerOnInternalProviderRequest() throws Exception {
        String hostname = "http://auth.knowhub.test";
        String realm = "fixed-hostname-test";
        try (KeycloakTestServer fixedHostnameServer = new KeycloakTestServer(hostname)) {
            fixedHostnameServer.start();
            fixedHostnameServer.createRealm(realm, true);
            String secret = fixedHostnameServer.createProvisioner(
                    realm, "internal-route-provisioner", TENANT_A,
                    KnowHubConstants.PROVISIONING_AUDIENCE);
            String bearer = fixedHostnameServer.clientCredentialsToken(
                    realm, "internal-route-provisioner", secret).path("access_token").asText();
            assertEquals(hostname + "/realms/" + realm,
                    fixedHostnameServer.decodeJwtPayload(bearer).path("iss").asText());

            assertStatus(fixedHostnameServer.providerRequest(
                    "POST", realm, "", bearer, "{\"mcp_credential_id\":\"not-a-uuid\"}"), 400);
        }
    }

    private String token(String realm, String clientId, String secret) throws Exception {
        return server.clientCredentialsToken(realm, clientId, secret)
                .path("access_token").asText();
    }

    private HttpResponse<String> create(String realm, String token, UUID credentialId)
            throws Exception {
        return server.providerRequest(
                "POST",
                realm,
                "",
                token,
                "{\"mcp_credential_id\":\"" + credentialId + "\"}");
    }

    private static Set<String> stringSet(JsonNode values) {
        return StreamSupport.stream(values.spliterator(), false)
                .map(JsonNode::asText)
                .collect(Collectors.toUnmodifiableSet());
    }

    private static void assertAudience(JsonNode audience, String expected) {
        if (audience.isTextual()) {
            assertEquals(expected, audience.asText());
            return;
        }
        assertTrue(stringSet(audience).contains(expected));
    }

    private static void assertStatus(HttpResponse<String> response, int expected) {
        assertEquals(expected, response.statusCode());
    }
}
