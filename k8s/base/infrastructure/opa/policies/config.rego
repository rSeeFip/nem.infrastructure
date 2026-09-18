# Config Endpoint RBAC Policy for nem.* Ecosystem
# Package: nem.federation.services.config
# Authentication is enforced by the ASP.NET service before OPA is called.
# This policy authorizes based on the OPA input actually sent by nem.Configuration.

package nem.federation.services.config

import rego.v1

default allow := false

admin_roles := {"admin", "FederationAdmin"}

# These client IDs are narrowly scoped configuration readers. They must not
# inherit the general service/admin rules below, even if their role mapping is
# accidentally broadened after provisioning.
managed_service_principals := {
    "nem-mimir-configuration": "mimir",
    "nem-inferencegateway-configuration-reader": "inferencegateway",
}

role_permissions["admin"] := {"config:read", "config:write", "config:admin"}
role_permissions["FederationAdmin"] := {"config:read", "config:write", "config:admin"}
role_permissions["operator"] := {"config:read", "config:write"}
role_permissions["service"] := {"config:read"}

user_roles := object.get(input.auth, "roles", [])

request_authenticated if {
    count(user_roles) > 0
}

user_permissions contains perm if {
    some role in user_roles
    some perm in role_permissions[role]
}

managed_service_principal if {
    object.get(managed_service_principals, input.auth.service_principal, "") != ""
}

managed_service_has_only_service_role if {
    count(user_roles) == 1
    user_roles[0] == "service"
}

managed_service_route_ids := {
    "nem-mimir-configuration": {"mimir"},
    "nem-inferencegateway-configuration-reader": {"inferencegateway", "nem.InferenceGateway"},
}

managed_service_own_read_route if {
    service_ids := managed_service_route_ids[input.auth.service_principal]
    some service_id in service_ids
    regex.match(sprintf("^/api/v1/config/%s(/[^/]+)?$", [service_id]), input.request.path)
    not endswith(input.request.path, "/bulk")
}

own_tenant if {
    input.request.tenant_id == input.auth.tenant_id
}

managed_service_fixed_tenant if {
    input.auth.tenant_id == "00000000-0000-0000-0000-000000000001"
    input.request.tenant_id == "00000000-0000-0000-0000-000000000001"
}

cross_tenant_allowed if {
    some role in user_roles
    role in admin_roles
}

tenant_access_valid if {
    own_tenant
}

tenant_access_valid if {
    cross_tenant_allowed
}

allow if {
    input.auth.authenticated == true
    input.auth.service_principal == "nem-mimir-configuration"
    managed_service_has_only_service_role
    upper(input.request.method) == "GET"
    input.request.path == "/api/v1/config/tenant/ContextCompaction"
    own_tenant
    managed_service_fixed_tenant
}

allow if {
    managed_service_principal
    managed_service_has_only_service_role
    upper(input.request.method) == "GET"
    managed_service_own_read_route
    own_tenant
    managed_service_fixed_tenant
}

allow if {
    not managed_service_principal
    request_authenticated
    "config:read" in user_permissions
    upper(input.request.method) == "GET"
    startswith(input.request.resource, "/api/v1/config")
    tenant_access_valid
}

allow if {
    not managed_service_principal
    request_authenticated
    "config:write" in user_permissions
    upper(input.request.method) in {"POST", "PUT", "PATCH"}
    startswith(input.request.resource, "/api/v1/config")
    not startswith(input.request.resource, "/api/v1/config/bulk")
    tenant_access_valid
}

allow if {
    not managed_service_principal
    request_authenticated
    "config:admin" in user_permissions
    upper(input.request.method) == "DELETE"
    startswith(input.request.resource, "/api/v1/config")
}

allow if {
    not managed_service_principal
    request_authenticated
    "config:admin" in user_permissions
    startswith(input.request.resource, "/api/v1/config/bulk")
}

allow if {
    not managed_service_principal
    request_authenticated
    "config:admin" in user_permissions
    startswith(input.request.resource, "/api/v1/admin/config")
}

allow if {
    input.request.path == "/health"
}

allow if {
    input.request.path == "/healthz"
}

allow if {
    input.request.path == "/health/live"
}

allow if {
    input.request.path == "/health/ready"
}

deny_reasons contains reason if {
    not request_authenticated
    reason := "Request is missing role context for authorization"
}

deny_reasons contains reason if {
    request_authenticated
    upper(input.request.method) == "GET"
    startswith(input.request.resource, "/api/v1/config")
    not "config:read" in user_permissions
    reason := sprintf("Role(s) %v do not grant config:read permission", [user_roles])
}

deny_reasons contains reason if {
    request_authenticated
    upper(input.request.method) in {"POST", "PUT", "PATCH"}
    startswith(input.request.resource, "/api/v1/config")
    not "config:write" in user_permissions
    reason := sprintf("Role(s) %v do not grant config:write permission", [user_roles])
}

deny_reasons contains reason if {
    request_authenticated
    upper(input.request.method) == "DELETE"
    startswith(input.request.resource, "/api/v1/config")
    not "config:admin" in user_permissions
    reason := sprintf("Role(s) %v do not grant config:admin permission", [user_roles])
}

deny_reasons contains reason if {
    request_authenticated
    "config:write" in user_permissions
    not "config:admin" in user_permissions
    not own_tenant
    reason := sprintf("Operator/service role cannot access tenant %v (own tenant: %v)", [input.request.tenant_id, input.auth.tenant_id])
}
