# Config Endpoint RBAC Policy for nem.* Ecosystem
# Package: nem.federation.services.config
#
# Controls access to configuration endpoints based on Keycloak roles.
# Permissions:
#   config:read  — read config values (all authenticated roles)
#   config:write — create/update config values (admin, operator)
#   config:admin — delete, cross-tenant, bulk operations (admin only)
#
# Role → Permission mapping:
#   admin    → config:read + config:write + config:admin
#   operator → config:read + config:write (own tenant only)
#   service  → config:read (own tenant only)

package nem.federation.services.config

import rego.v1

import data.nem.federation.common.auth

default allow := false

# --- Permission derivation from Keycloak roles ---

# admin role grants all config permissions
role_permissions["admin"] := {"config:read", "config:write", "config:admin"}

# operator role grants read + write (own tenant only)
role_permissions["operator"] := {"config:read", "config:write"}

# service role grants read only (own tenant only)
role_permissions["service"] := {"config:read"}

# Collect all permissions for the current user based on their roles
user_permissions contains perm if {
    some role in input.auth.roles
    some perm in role_permissions[role]
}

# --- Tenant isolation helpers ---

# True when the request is scoped to the caller's own tenant
own_tenant if {
    input.request.tenant_id == input.auth.tenant_id
}

# Admin role bypasses tenant isolation (cross-tenant access)
cross_tenant_allowed if {
    "admin" in input.auth.roles
}

# Tenant access is valid when own-tenant or admin cross-tenant
tenant_access_valid if {
    own_tenant
}

tenant_access_valid if {
    cross_tenant_allowed
}

# --- Read access ---
# GET /api/v1/config/**
allow if {
    auth.allow
    "config:read" in user_permissions
    upper(input.request.method) == "GET"
    startswith(input.request.resource, "/api/v1/config")
    tenant_access_valid
}

# --- Write access (create/update) ---
# POST /api/v1/config/**  (excluding /bulk which requires config:admin)
# PUT  /api/v1/config/**
# PATCH /api/v1/config/**
allow if {
    auth.allow
    "config:write" in user_permissions
    upper(input.request.method) in {"POST", "PUT", "PATCH"}
    startswith(input.request.resource, "/api/v1/config")
    not startswith(input.request.resource, "/api/v1/config/bulk")
    tenant_access_valid
}

# --- Admin access (delete, bulk, cross-tenant) ---
# DELETE /api/v1/config/**
allow if {
    auth.allow
    "config:admin" in user_permissions
    upper(input.request.method) == "DELETE"
    startswith(input.request.resource, "/api/v1/config")
}

# Bulk operations endpoint — admin only
allow if {
    auth.allow
    "config:admin" in user_permissions
    startswith(input.request.resource, "/api/v1/config/bulk")
}

# Cross-tenant admin endpoint
allow if {
    auth.allow
    "config:admin" in user_permissions
    startswith(input.request.resource, "/api/v1/admin/config")
}

# --- Health endpoints (always allowed) ---
allow if {
    input.request.path == "/health"
}

allow if {
    input.request.path == "/health/live"
}

allow if {
    input.request.path == "/health/ready"
}

# --- Deny reasons for audit ---
deny_reasons contains reason if {
    not auth.allow
    reason := "Request is not authenticated via Keycloak"
}

deny_reasons contains reason if {
    auth.allow
    upper(input.request.method) == "GET"
    startswith(input.request.resource, "/api/v1/config")
    not "config:read" in user_permissions
    reason := sprintf("Role(s) %v do not grant config:read permission", [input.auth.roles])
}

deny_reasons contains reason if {
    auth.allow
    upper(input.request.method) in {"POST", "PUT", "PATCH"}
    startswith(input.request.resource, "/api/v1/config")
    not "config:write" in user_permissions
    reason := sprintf("Role(s) %v do not grant config:write permission", [input.auth.roles])
}

deny_reasons contains reason if {
    auth.allow
    upper(input.request.method) == "DELETE"
    startswith(input.request.resource, "/api/v1/config")
    not "config:admin" in user_permissions
    reason := sprintf("Role(s) %v do not grant config:admin permission", [input.auth.roles])
}

deny_reasons contains reason if {
    auth.allow
    "config:write" in user_permissions
    not "config:admin" in user_permissions
    not own_tenant
    reason := sprintf("Operator/service role cannot access tenant %v (own tenant: %v)", [input.request.tenant_id, input.auth.tenant_id])
}
