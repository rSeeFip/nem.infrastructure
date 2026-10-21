package io.nem.keycloak.knowhub.api;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record TenantClientResponse(
        @JsonProperty("client_id") String clientId,
        @JsonProperty("mcp_credential_id") String credentialId,
        boolean created,
        @JsonProperty("client_secret") String clientSecret) {

    public static TenantClientResponse created(String clientId, String credentialId, String secret) {
        return new TenantClientResponse(clientId, credentialId, true, secret);
    }

    public static TenantClientResponse existing(String clientId, String credentialId) {
        return new TenantClientResponse(clientId, credentialId, false, null);
    }
}
