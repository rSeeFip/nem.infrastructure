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

managed_allowed(value) if {
    config.allow with input as value with data.nem.federation.common.auth.allow as true
}

test_mimir_client_can_read_its_default_tenant_snapshot if {
    managed_allowed(managed_client_input(
        "nem-mimir-configuration", ["service"], "GET", "/api/v1/config/mimir", "00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000001"
    ))
}

test_inference_client_can_read_its_default_tenant_key if {
    managed_allowed(managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/inferencegateway/Feature:Enabled", "00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000001"
    ))
}

test_managed_clients_are_denied_outside_their_read_scope if {
    not managed_allowed(managed_client_input(
        "nem-mimir-configuration", ["service"], "GET", "/api/v1/config/inferencegateway", "00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000001"
    ))
    not managed_allowed(managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/global/Feature:Enabled", "00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000001"
    ))
    not managed_allowed(managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service"], "PUT", "/api/v1/config/inferencegateway/Feature:Enabled", "00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000001"
    ))
    not managed_allowed(managed_client_input(
        "nem-mimir-configuration", ["service", "admin"], "GET", "/api/v1/config/mimir", "00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000001"
    ))
}

test_managed_clients_are_denied_for_non_guid_or_foreign_tenant if {
    not managed_allowed(managed_client_input(
        "nem-inferencegateway-configuration-reader", ["service"], "GET", "/api/v1/config/inferencegateway", "default", "default"
    ))
    not managed_allowed(managed_client_input(
        "nem-mimir-configuration", ["service"], "GET", "/api/v1/config/mimir", "00000000-0000-0000-0000-000000000001", "11111111-1111-1111-1111-111111111111"
    ))
}
