package nem.federation.tests.config_service_principal

import rego.v1

import data.nem.federation.services.config

fixed_tenant := "00000000-0000-0000-0000-000000000001"

managed_client_input(client_id, roles, method, path, request_tenant, auth_tenant) := {
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

test_mimir_client_can_read_its_fixed_tenant_snapshot if {
    config.allow with input as managed_client_input(
        "nem-mimir-configuration", ["service"], "GET", "/api/v1/config/mimir", fixed_tenant, fixed_tenant
    )
}

test_inference_reader_can_read_its_fixed_tenant_key if {
    config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/inferencegateway/Feature:Enabled", fixed_tenant, fixed_tenant
    )
}

test_managed_reader_rejects_default_tenant if {
    not config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/inferencegateway", "default", "default"
    )
}

test_managed_reader_cannot_read_another_service if {
    not config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/mimir", fixed_tenant, fixed_tenant
    )
}

test_managed_reader_cannot_read_global_bulk_or_admin_routes if {
    not config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/global/Feature:Enabled", fixed_tenant, fixed_tenant
    )
    not config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/inferencegateway/bulk", fixed_tenant, fixed_tenant
    )
    not config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/admin/config", fixed_tenant, fixed_tenant
    )
}

test_managed_reader_cannot_write if {
    not config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service"], "PUT", "/api/v1/config/inferencegateway/Feature:Enabled", fixed_tenant, fixed_tenant
    )
    not config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service"], "POST", "/api/v1/config/inferencegateway/Feature:Enabled", fixed_tenant, fixed_tenant
    )
    not config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service"], "DELETE", "/api/v1/config/inferencegateway/Feature:Enabled", fixed_tenant, fixed_tenant
    )
}

test_managed_reader_cannot_use_an_admin_role_bypass if {
    not config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service", "admin"], "GET", "/api/v1/config/inferencegateway", fixed_tenant, fixed_tenant
    )
}

test_legacy_inference_client_uses_generic_service_behavior if {
    config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration", ["service"], "GET", "/api/v1/config/mimir", "default", "default"
    )
}
