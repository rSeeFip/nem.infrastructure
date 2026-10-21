package io.nem.keycloak.knowhub.api;

import jakarta.ws.rs.BadRequestException;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

public record CreateTenantClientRequest(UUID credentialId) {
    private static final String FIELD = "mcp_credential_id";

    public static CreateTenantClientRequest parse(Map<String, Object> body) {
        if (body == null || !body.keySet().equals(Set.of(FIELD))) {
            throw new BadRequestException("request must contain only mcp_credential_id");
        }
        Object raw = body.get(FIELD);
        if (!(raw instanceof String value)) {
            throw new BadRequestException("mcp_credential_id must be a UUID string");
        }
        try {
            UUID id = UUID.fromString(value);
            if (!id.toString().equals(value)) {
                throw new IllegalArgumentException("non-canonical UUID");
            }
            return new CreateTenantClientRequest(id);
        } catch (IllegalArgumentException exception) {
            throw new BadRequestException("mcp_credential_id must be a canonical UUID");
        }
    }
}
