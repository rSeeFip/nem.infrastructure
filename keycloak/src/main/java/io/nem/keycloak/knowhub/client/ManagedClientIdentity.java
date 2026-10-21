package io.nem.keycloak.knowhub.client;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.UUID;

public record ManagedClientIdentity(String clientId, String specHash) {
    private static final String SPEC_VERSION = "knowhub-mcp-client/v1";

    public static ManagedClientIdentity from(String tenantId, UUID credentialId) {
        String tenantHash = hex(sha256(tenantId)).substring(0, 24);
        String clientId = "knowhub-mcp-" + tenantHash + "-" + credentialId.toString().replace("-", "");
        String canonicalSpec = String.join("\n",
                SPEC_VERSION,
                tenantId,
                credentialId.toString(),
                "aud=" + io.nem.keycloak.knowhub.KnowHubConstants.API_AUDIENCE,
                "role=" + io.nem.keycloak.knowhub.KnowHubConstants.READER_ROLE);
        return new ManagedClientIdentity(clientId, hex(sha256(canonicalSpec)));
    }

    private static byte[] sha256(String value) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }

    private static String hex(byte[] bytes) {
        return HexFormat.of().formatHex(bytes);
    }
}
