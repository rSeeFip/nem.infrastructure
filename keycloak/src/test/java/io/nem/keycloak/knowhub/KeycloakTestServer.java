package io.nem.keycloak.knowhub;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Map;
import java.util.UUID;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.images.builder.Transferable;
import org.testcontainers.utility.DockerImageName;

final class KeycloakTestServer implements AutoCloseable {
    static final String IMAGE = "quay.io/keycloak/keycloak@sha256:4883630ef9db14031cde3e60700c9a9a8eaf1b5c24db1589d6a2d43de38ba2a9";

    private final ObjectMapper json = new ObjectMapper();
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();
    private final String adminPassword = UUID.randomUUID().toString();
    private final GenericContainer<?> container;
    private String baseUrl;
    private String adminToken;

    KeycloakTestServer() throws IOException {
        byte[] provider = java.nio.file.Files.readAllBytes(
                Path.of("target", "knowhub-tenant-provider-1.0.0-SNAPSHOT.jar"));
        container = new GenericContainer<>(DockerImageName.parse(IMAGE))
                .withEnv("KC_BOOTSTRAP_ADMIN_USERNAME", "integration-admin")
                .withEnv("KC_BOOTSTRAP_ADMIN_PASSWORD", adminPassword)
                .withExposedPorts(8080)
                .withCopyToContainer(
                        Transferable.of(provider, 0644),
                        "/opt/keycloak/providers/knowhub-tenant-provider.jar")
                .withCommand("start-dev", "--http-port=8080")
                .waitingFor(Wait.forHttp("/realms/master")
                        .forStatusCode(200)
                        .withStartupTimeout(Duration.ofMinutes(3)));
    }

    void start() throws Exception {
        container.start();
        baseUrl = "http://" + container.getHost() + ":" + container.getMappedPort(8080);
        adminToken = passwordToken("master", "admin-cli", null,
                "integration-admin", adminPassword).path("access_token").asText();
        if (adminToken.isBlank()) {
            throw new IllegalStateException("bootstrap administrator token was unavailable");
        }
    }

    void createRealm(String realm, boolean withReaderRole) throws Exception {
        ObjectNode body = json.createObjectNode().put("realm", realm).put("enabled", true);
        requireStatus(sendJson("POST", "/admin/realms", body, adminToken), 201);
        if (withReaderRole) {
            ObjectNode role = json.createObjectNode().put("name", KnowHubConstants.READER_ROLE);
            requireStatus(sendJson("POST", "/admin/realms/" + realm + "/roles", role, adminToken), 201);
        }
    }

    String createProvisioner(String realm, String clientId, String tenant, String audience)
            throws Exception {
        String secret = UUID.randomUUID() + UUID.randomUUID().toString();
        ObjectNode client = confidentialClient(clientId, secret);
        ObjectNode attributes = client.putObject("attributes");
        attributes.put(KnowHubConstants.ATTR_PROVISIONER, "true");
        attributes.put(KnowHubConstants.ATTR_TENANT, tenant);
        ArrayNode mappers = client.putArray("protocolMappers");
        mappers.add(hardcodedClaim("tenant-id", KnowHubConstants.TENANT_CLAIM, tenant));
        mappers.add(audienceMapper(audience));
        requireStatus(sendJson("POST", "/admin/realms/" + realm + "/clients", client, adminToken), 201);
        return secret;
    }

    String createNormalUserClient(String realm, String clientId, String username, String tenant)
            throws Exception {
        ObjectNode client = json.createObjectNode();
        client.put("clientId", clientId).put("enabled", true).put("publicClient", true);
        client.put("directAccessGrantsEnabled", true).put("standardFlowEnabled", false);
        client.putArray("protocolMappers")
                .add(hardcodedClaim("tenant-id", KnowHubConstants.TENANT_CLAIM, tenant))
                .add(audienceMapper(KnowHubConstants.PROVISIONING_AUDIENCE));
        requireStatus(sendJson("POST", "/admin/realms/" + realm + "/clients", client, adminToken), 201);

        String password = UUID.randomUUID().toString();
        ObjectNode user = json.createObjectNode()
                .put("username", username)
                .put("firstName", "Normal")
                .put("lastName", "User")
                .put("email", username + "@invalid.example")
                .put("emailVerified", true)
                .put("enabled", true);
        ObjectNode credential = json.createObjectNode()
                .put("type", "password").put("value", password).put("temporary", false);
        user.putArray("credentials").add(credential);
        requireStatus(sendJson("POST", "/admin/realms/" + realm + "/users", user, adminToken), 201);
        return password;
    }

    JsonNode clientCredentialsToken(String realm, String clientId, String secret) throws Exception {
        return passwordToken(realm, clientId, secret, null, null);
    }

    int clientCredentialsTokenStatus(String realm, String clientId, String secret) throws Exception {
        return tokenRequest(realm, clientId, secret, null, null).statusCode();
    }

    JsonNode userToken(String realm, String clientId, String username, String password) throws Exception {
        return passwordToken(realm, clientId, null, username, password);
    }

    HttpResponse<String> providerRequest(
            String method, String realm, String suffix, String token, String body) throws Exception {
        HttpRequest.Builder request = HttpRequest.newBuilder(
                        URI.create(baseUrl + "/realms/" + realm + "/knowhub/tenant-clients" + suffix))
                .timeout(Duration.ofSeconds(20))
                .header("Authorization", "Bearer " + token)
                .header("Content-Type", "application/json");
        request.method(method, body == null
                ? HttpRequest.BodyPublishers.noBody()
                : HttpRequest.BodyPublishers.ofString(body));
        return http.send(request.build(), HttpResponse.BodyHandlers.ofString());
    }

    HttpResponse<String> adminClientOperation(
            String method, String realm, String path, String token, String body) throws Exception {
        return sendJson(method, "/admin/realms/" + realm + "/clients" + path,
                body == null ? null : json.readTree(body), token);
    }

    ArrayNode findClients(String realm, String clientId) throws Exception {
        String path = "/admin/realms/" + realm + "/clients?clientId=" + encode(clientId);
        HttpResponse<String> response = sendJson("GET", path, null, adminToken);
        requireStatus(response, 200);
        return (ArrayNode) json.readTree(response.body());
    }

    JsonNode parse(String body) throws IOException {
        return json.readTree(body);
    }

    JsonNode decodeJwtPayload(String token) throws IOException {
        String[] segments = token.split("\\.");
        if (segments.length != 3) {
            throw new IllegalArgumentException("token is not a compact signed JWT");
        }
        byte[] payload = java.util.Base64.getUrlDecoder().decode(segments[1]);
        return json.readTree(payload);
    }

    @Override
    public void close() {
        container.stop();
    }

    private JsonNode passwordToken(
            String realm, String clientId, String clientSecret, String username, String password)
            throws Exception {
        HttpResponse<String> response = tokenRequest(
                realm, clientId, clientSecret, username, password);
        if (response.statusCode() != 200) {
            String error = json.readTree(response.body()).path("error").asText("unknown");
            throw new IllegalStateException(
                    "token endpoint returned status " + response.statusCode() + " (" + error + ")");
        }
        return json.readTree(response.body());
    }

    private HttpResponse<String> tokenRequest(
            String realm, String clientId, String clientSecret, String username, String password)
            throws Exception {
        StringBuilder form = new StringBuilder("grant_type=")
                .append(encode(username == null ? "client_credentials" : "password"))
                .append("&client_id=").append(encode(clientId));
        appendForm(form, "client_secret", clientSecret);
        appendForm(form, "username", username);
        appendForm(form, "password", password);
        HttpRequest request = HttpRequest.newBuilder(
                        URI.create(baseUrl + "/realms/" + realm + "/protocol/openid-connect/token"))
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(form.toString()))
                .build();
        return http.send(request, HttpResponse.BodyHandlers.ofString());
    }

    private HttpResponse<String> sendJson(
            String method, String path, JsonNode body, String token) throws Exception {
        HttpRequest.Builder request = HttpRequest.newBuilder(URI.create(baseUrl + path))
                .timeout(Duration.ofSeconds(20))
                .header("Authorization", "Bearer " + token)
                .header("Content-Type", "application/json");
        request.method(method, body == null
                ? HttpRequest.BodyPublishers.noBody()
                : HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)));
        return http.send(request.build(), HttpResponse.BodyHandlers.ofString());
    }

    private ObjectNode confidentialClient(String clientId, String secret) {
        ObjectNode client = json.createObjectNode();
        client.put("clientId", clientId).put("secret", secret).put("enabled", true);
        client.put("publicClient", false).put("serviceAccountsEnabled", true);
        client.put("standardFlowEnabled", false).put("directAccessGrantsEnabled", false);
        client.put("fullScopeAllowed", false);
        return client;
    }

    private ObjectNode hardcodedClaim(String name, String claim, String value) {
        ObjectNode mapper = json.createObjectNode();
        mapper.put("name", name).put("protocol", "openid-connect");
        mapper.put("protocolMapper", "oidc-hardcoded-claim-mapper");
        ObjectNode config = mapper.putObject("config");
        config.put("claim.name", claim).put("claim.value", value);
        config.put("jsonType.label", "String").put("access.token.claim", "true");
        return mapper;
    }

    private ObjectNode audienceMapper(String audience) {
        ObjectNode mapper = json.createObjectNode();
        mapper.put("name", "provisioning-audience").put("protocol", "openid-connect");
        mapper.put("protocolMapper", "oidc-audience-mapper");
        mapper.putObject("config")
                .put("included.client.audience", audience)
                .put("access.token.claim", "true");
        return mapper;
    }

    private static void appendForm(StringBuilder form, String name, String value) {
        if (value != null) {
            form.append('&').append(encode(name)).append('=').append(encode(value));
        }
    }

    private static String encode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }

    private static void requireStatus(HttpResponse<String> response, int expected) {
        if (response.statusCode() != expected) {
            throw new IllegalStateException(
                    "unexpected HTTP status " + response.statusCode() + ", expected " + expected);
        }
    }
}
