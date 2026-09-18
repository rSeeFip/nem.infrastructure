package nem.federation.tests.config_service_principal_matrix

import rego.v1

import data.nem.federation.services.config

fixed_tenant := "00000000-0000-0000-0000-000000000001"

service_input(client_id, roles, method, path, request_tenant, auth_tenant) := {
    "auth": {
        "authenticated": true,
        "roles": roles,
        "tenant_id": auth_tenant,
        "service_principal": client_id,
    },
    "request": {
        "method": method,
        "resource": path,
        "path": path,
        "tenant_id": request_tenant,
    },
}

unauthenticated_service_input(client_id, roles, method, path, request_tenant, auth_tenant) := {
    "auth": {
        "authenticated": false,
        "roles": roles,
        "tenant_id": auth_tenant,
        "service_principal": client_id,
    },
    "request": {
        "method": method,
        "resource": path,
        "path": path,
        "tenant_id": request_tenant,
    },
}

allowed(value) if {
    config.allow with input as value with data.nem.federation.common.auth.allow as true
}

test_reader_allows_fixed_tenant_own_key if {
    allowed(service_input("nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/inferencegateway/Feature:Enabled", fixed_tenant, fixed_tenant))
}

test_reader_allows_fixed_tenant_canonical_gateway_key if {
    allowed(service_input("nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/nem.InferenceGateway/Sentinel:HealthReportIntervalSeconds", fixed_tenant, fixed_tenant))
}

test_mimir_allows_fixed_tenant_context_compaction_key if {
    allowed(service_input("nem-mimir-configuration", ["service"], "GET", "/api/v1/config/tenant/ContextCompaction", fixed_tenant, fixed_tenant))
}

test_mimir_denies_other_tenant_key if {
    not allowed(service_input("nem-mimir-configuration", ["service"], "GET", "/api/v1/config/tenant/OtherKey", fixed_tenant, fixed_tenant))
}

test_other_managed_principal_denies_context_compaction_key if {
    not allowed(service_input("nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/tenant/ContextCompaction", fixed_tenant, fixed_tenant))
}

test_mimir_denies_tenant_mismatch if {
    not allowed(service_input("nem-mimir-configuration", ["service"], "GET", "/api/v1/config/tenant/ContextCompaction", fixed_tenant, "11111111-1111-1111-1111-111111111111"))
}

test_mimir_denies_nonfixed_matching_tenant if {
    not allowed(service_input("nem-mimir-configuration", ["service"], "GET", "/api/v1/config/tenant/ContextCompaction", "default", "default"))
}

test_mimir_denies_unauthenticated_context_compaction_key if {
    not allowed(unauthenticated_service_input("nem-mimir-configuration", ["service"], "GET", "/api/v1/config/tenant/ContextCompaction", fixed_tenant, fixed_tenant))
}

test_mimir_denies_non_get_context_compaction_key if {
    not allowed(service_input("nem-mimir-configuration", ["service"], "POST", "/api/v1/config/tenant/ContextCompaction", fixed_tenant, fixed_tenant))
}

test_mimir_denies_extra_role_context_compaction_key if {
    not allowed(service_input("nem-mimir-configuration", ["service", "admin"], "GET", "/api/v1/config/tenant/ContextCompaction", fixed_tenant, fixed_tenant))
}

test_mimir_denies_context_compaction_path_prefix if {
    not allowed(service_input("nem-mimir-configuration", ["service"], "GET", "/api/v1/config/tenant/ContextCompactionExtra", fixed_tenant, fixed_tenant))
}

test_mimir_denies_context_compaction_path_suffix if {
    not allowed(service_input("nem-mimir-configuration", ["service"], "GET", "/api/v1/config/tenant/ContextCompaction/child", fixed_tenant, fixed_tenant))
}

test_legacy_client_retains_generic_service_access if {
    allowed(service_input("nem-inferencegateway-configuration", ["service"], "GET", "/api/v1/config/mimir", "default", "default"))
}

test_reader_denies_default_tenant if {
    not allowed(service_input("nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/inferencegateway", "default", "default"))
}

test_reader_denies_cross_service_get if {
    not allowed(service_input("nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/mimir", fixed_tenant, fixed_tenant))
}

test_reader_denies_global_get if {
    not allowed(service_input("nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/global/Feature:Enabled", fixed_tenant, fixed_tenant))
}

test_reader_denies_service_bulk_get if {
    not allowed(service_input("nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/inferencegateway/bulk", fixed_tenant, fixed_tenant))
}

test_reader_denies_reserved_bulk_get if {
    not allowed(service_input("nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/bulk", fixed_tenant, fixed_tenant))
}

test_reader_denies_admin_get if {
    not allowed(service_input("nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/admin/config", fixed_tenant, fixed_tenant))
}

test_reader_denies_put if {
    not allowed(service_input("nem-inferencegateway-configuration-reader", ["service"], "PUT", "/api/v1/config/inferencegateway/Feature:Enabled", fixed_tenant, fixed_tenant))
}

test_reader_denies_post if {
    not allowed(service_input("nem-inferencegateway-configuration-reader", ["service"], "POST", "/api/v1/config/inferencegateway/Feature:Enabled", fixed_tenant, fixed_tenant))
}

test_reader_denies_delete if {
    not allowed(service_input("nem-inferencegateway-configuration-reader", ["service"], "DELETE", "/api/v1/config/inferencegateway/Feature:Enabled", fixed_tenant, fixed_tenant))
}

test_reader_denies_admin_role_bypass if {
    not allowed(service_input("nem-inferencegateway-configuration-reader", ["service", "admin"], "GET", "/api/v1/config/inferencegateway", fixed_tenant, fixed_tenant))
}
