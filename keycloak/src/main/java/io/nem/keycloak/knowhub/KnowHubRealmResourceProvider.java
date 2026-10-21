package io.nem.keycloak.knowhub;

import org.keycloak.models.KeycloakSession;
import org.keycloak.services.resource.RealmResourceProvider;

public final class KnowHubRealmResourceProvider implements RealmResourceProvider {
    private final KeycloakSession session;

    public KnowHubRealmResourceProvider(KeycloakSession session) {
        this.session = session;
    }

    @Override
    public Object getResource() {
        return new TenantClientsResource(session);
    }

    @Override
    public void close() {
    }
}
