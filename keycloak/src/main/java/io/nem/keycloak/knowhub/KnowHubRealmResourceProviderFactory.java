package io.nem.keycloak.knowhub;

import org.keycloak.Config;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.KeycloakSessionFactory;
import org.keycloak.services.resource.RealmResourceProviderFactory;

public final class KnowHubRealmResourceProviderFactory
        implements RealmResourceProviderFactory {

    @Override
    public KnowHubRealmResourceProvider create(KeycloakSession session) {
        return new KnowHubRealmResourceProvider(session);
    }

    @Override
    public void init(Config.Scope config) {
    }

    @Override
    public void postInit(KeycloakSessionFactory factory) {
    }

    @Override
    public void close() {
    }

    @Override
    public String getId() {
        return KnowHubConstants.PROVIDER_ID;
    }
}
