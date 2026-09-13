package nem.federation.tests.config_service_principal

import rego.v1

import data.nem.federation.services.config

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

test_mimir_client_can_read_its_default_tenant_snapshot if {
    config.allow with input as managed_client_input(
        "nem-mimir-configuration", ["service"], "GET", "/api/v1/config/mimir", "default", "default"
    )
}

test_inference_client_can_read_its_default_tenant_key if {
    config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration", ["service"], "GET", "/api/v1/config/inferencegateway/Feature:Enabled", "default", "default"
    )
}

test_managed_client_cannot_read_a_mismatched_tenant if {
    not config.allow with input as managed_client_input(
        "nem-mimir-configuration", ["service"], "GET", "/api/v1/config/mimir", "other", "default"
    )
}

test_managed_client_cannot_read_another_service if {
    not config.allow with input as managed_client_input(
        "nem-mimir-configuration", ["service"], "GET", "/api/v1/config/inferencegateway", "default", "default"
    )
}

test_managed_client_cannot_read_global_configuration if {
    not config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration", ["service"], "GET", "/api/v1/config/global/Feature:Enabled", "default", "default"
    )
}

test_managed_client_cannot_read_bulk_or_admin_routes if {
    not config.allow with input as managed_client_input(
        "nem-mimir-configuration", ["service"], "GET", "/api/v1/config/mimir/admin/metadata", "default", "default"
    )
}

test_managed_client_cannot_write_or_bulk_update if {
    not config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration", ["service"], "PUT", "/api/v1/config/inferencegateway/Feature:Enabled", "default", "default"
    )
    not config.allow with input as managed_client_input(
        "nem-inferencegateway-configuration", ["service"], "PUT", "/api/v1/config/inferencegateway/bulk", "default", "default"
    )
}

test_managed_client_cannot_use_an_admin_role_bypass if {
    not config.allow with input as managed_client_input(
        "nem-mimir-configuration", ["service", "admin"], "GET", "/api/v1/config/mimir", "default", "default"
    )
}
