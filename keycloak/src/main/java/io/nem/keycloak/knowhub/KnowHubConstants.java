package io.nem.keycloak.knowhub;

public final class KnowHubConstants {
    public static final String PROVIDER_ID = "knowhub";
    public static final String PROVISIONING_AUDIENCE = "knowhub-tenant-provisioning";
    public static final String API_AUDIENCE = "knowhub-api";
    public static final String READER_ROLE = "KnowHub.ArachneReader";
    public static final String TENANT_CLAIM = "tenant_id";
    public static final String CREDENTIAL_CLAIM = "mcp_credential_id";

    public static final String ATTR_PROVISIONER = "knowhub.provisioner";
    public static final String ATTR_MANAGED = "knowhub.managed";
    public static final String ATTR_TENANT = "knowhub.tenant_id";
    public static final String ATTR_CREDENTIAL = "knowhub.mcp_credential_id";
    public static final String ATTR_SPEC_HASH = "knowhub.spec_hash";

    private KnowHubConstants() {
    }
}
