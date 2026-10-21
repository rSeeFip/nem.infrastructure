package io.nem.keycloak.knowhub.auth;

import org.keycloak.models.ClientModel;
import org.keycloak.models.UserModel;
import org.keycloak.representations.AccessToken;

public record TenantCaller(
        String tenantId,
        ClientModel provisionerClient,
        UserModel serviceAccount,
        AccessToken token) {
}
