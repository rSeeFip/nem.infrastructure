package io.nem.keycloak.knowhub;

import io.nem.keycloak.knowhub.api.CreateTenantClientRequest;
import io.nem.keycloak.knowhub.api.TenantClientResponse;
import io.nem.keycloak.knowhub.auth.TenantCaller;
import io.nem.keycloak.knowhub.auth.TenantCallerAuthenticator;
import io.nem.keycloak.knowhub.client.TenantClientService;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.UriInfo;
import jakarta.ws.rs.ext.Provider;
import java.util.Map;
import java.util.UUID;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;

@Provider
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public final class TenantClientsResource {
    private final KeycloakSession session;

    public TenantClientsResource(KeycloakSession session) {
        this.session = session;
    }

    @POST
    @Path("tenant-clients")
    public Response create(
            Map<String, Object> body,
            @Context HttpHeaders headers,
            @Context UriInfo uriInfo) {
        RealmModel realm = requireRealm();
        TenantCaller caller = new TenantCallerAuthenticator(session, realm)
                .authenticate(headers, uriInfo);
        CreateTenantClientRequest request = CreateTenantClientRequest.parse(body);
        TenantClientResponse result = new TenantClientService(session, realm)
                .create(caller.tenantId(), request.credentialId());
        return Response.status(result.created() ? Response.Status.CREATED : Response.Status.OK)
                .header("Cache-Control", "no-store")
                .header("Pragma", "no-cache")
                .entity(result)
                .build();
    }

    @DELETE
    @Path("tenant-clients/{mcpCredentialId}")
    public Response revoke(
            @PathParam("mcpCredentialId") String rawCredentialId,
            @Context HttpHeaders headers,
            @Context UriInfo uriInfo) {
        RealmModel realm = requireRealm();
        TenantCaller caller = new TenantCallerAuthenticator(session, realm)
                .authenticate(headers, uriInfo);
        UUID credentialId = canonicalUuid(rawCredentialId);
        new TenantClientService(session, realm).revoke(caller.tenantId(), credentialId);
        return Response.noContent().build();
    }

    private RealmModel requireRealm() {
        RealmModel realm = session.getContext().getRealm();
        if (realm == null) {
            throw new BadRequestException("realm is required");
        }
        return realm;
    }

    private static UUID canonicalUuid(String raw) {
        try {
            UUID id = UUID.fromString(raw);
            if (!id.toString().equals(raw)) {
                throw new IllegalArgumentException("non-canonical UUID");
            }
            return id;
        } catch (IllegalArgumentException exception) {
            throw new BadRequestException("mcp_credential_id must be a canonical UUID");
        }
    }
}
