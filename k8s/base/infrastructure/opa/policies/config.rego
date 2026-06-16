# Config Endpoint RBAC Policy for nem.* Ecosystem
# Package: nem.federation.services.config
# Authentication is enforced by the ASP.NET service before OPA is called.
# This policy authorizes based on the OPA input actually sent by nem.Configuration.

package nem.federation.services.config

import rego.v1

default allow := false

admin_roles := {"admin", "FederationAdmin"}

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

own_tenant if {
    input.request.tenant_id == input.auth.tenant_id
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
    request_authenticated
    "config:read" in user_permissions
    upper(input.request.method) == "GET"
    startswith(input.request.resource, "/api/v1/config")
    tenant_access_valid
}

allow if {
    request_authenticated
    "config:write" in user_permissions
    upper(input.request.method) in {"POST", "PUT", "PATCH"}
    startswith(input.request.resource, "/api/v1/config")
    not startswith(input.request.resource, "/api/v1/config/bulk")
    tenant_access_valid
}

allow if {
    request_authenticated
    "config:admin" in user_permissions
    upper(input.request.method) == "DELETE"
    startswith(input.request.resource, "/api/v1/config")
}

allow if {
    request_authenticated
    "config:admin" in user_permissions
    startswith(input.request.resource, "/api/v1/config/bulk")
}

allow if {
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
