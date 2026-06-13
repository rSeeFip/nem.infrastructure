package nem.federation.tests.config

import rego.v1

import data.nem.federation.services.config

# --- Shared test helpers ---

authenticated_input(roles, method, resource, tenant_id, auth_tenant_id) := {
    "auth": {
        "authenticated": true,
        "issuer": "keycloak",
        "subject": "user:test-user",
        "roles": roles,
        "tenant_id": auth_tenant_id,
    },
    "request": {
        "method": method,
        "resource": resource,
        "path": resource,
        "tenant_id": tenant_id,
    },
}

# ============================================================
# ADMIN ROLE TESTS
# ============================================================

# admin: config:read — GET own tenant
test_admin_can_read_config_own_tenant if {
    config.allow with input as authenticated_input(
        ["admin"], "GET", "/api/v1/config/my-key", "tenant-a", "tenant-a"
    )
}

# admin: config:read — GET cross-tenant (admin bypass)
test_admin_can_read_config_cross_tenant if {
    config.allow with input as authenticated_input(
        ["admin"], "GET", "/api/v1/config/my-key", "tenant-b", "tenant-a"
    )
}

# admin: config:write — POST own tenant
test_admin_can_write_config_post if {
    config.allow with input as authenticated_input(
        ["admin"], "POST", "/api/v1/config", "tenant-a", "tenant-a"
    )
}

# admin: config:write — PUT own tenant
test_admin_can_write_config_put if {
    config.allow with input as authenticated_input(
        ["admin"], "PUT", "/api/v1/config/my-key", "tenant-a", "tenant-a"
    )
}

# admin: config:write — PATCH own tenant
test_admin_can_write_config_patch if {
    config.allow with input as authenticated_input(
        ["admin"], "PATCH", "/api/v1/config/my-key", "tenant-a", "tenant-a"
    )
}

# admin: config:admin — DELETE own tenant
test_admin_can_delete_config if {
    config.allow with input as authenticated_input(
        ["admin"], "DELETE", "/api/v1/config/my-key", "tenant-a", "tenant-a"
    )
}

# admin: config:admin — DELETE cross-tenant
test_admin_can_delete_config_cross_tenant if {
    config.allow with input as authenticated_input(
        ["admin"], "DELETE", "/api/v1/config/my-key", "tenant-b", "tenant-a"
    )
}

# admin: config:admin — bulk operations
test_admin_can_bulk_config if {
    config.allow with input as authenticated_input(
        ["admin"], "POST", "/api/v1/config/bulk", "tenant-a", "tenant-a"
    )
}

# admin: config:admin — cross-tenant admin endpoint
test_admin_can_access_admin_config_endpoint if {
    config.allow with input as authenticated_input(
        ["admin"], "GET", "/api/v1/admin/config", "tenant-b", "tenant-a"
    )
}

# ============================================================
# OPERATOR ROLE TESTS
# ============================================================

# operator: config:read — GET own tenant
test_operator_can_read_config_own_tenant if {
    config.allow with input as authenticated_input(
        ["operator"], "GET", "/api/v1/config/my-key", "tenant-a", "tenant-a"
    )
}

# operator: config:write — POST own tenant
test_operator_can_write_config_post if {
    config.allow with input as authenticated_input(
        ["operator"], "POST", "/api/v1/config", "tenant-a", "tenant-a"
    )
}

# operator: config:write — PUT own tenant
test_operator_can_write_config_put if {
    config.allow with input as authenticated_input(
        ["operator"], "PUT", "/api/v1/config/my-key", "tenant-a", "tenant-a"
    )
}

# operator: DENIED — DELETE (no config:admin)
test_operator_cannot_delete_config if {
    not config.allow with input as authenticated_input(
        ["operator"], "DELETE", "/api/v1/config/my-key", "tenant-a", "tenant-a"
    )
}

# operator: DENIED — cross-tenant read
test_operator_cannot_read_config_cross_tenant if {
    not config.allow with input as authenticated_input(
        ["operator"], "GET", "/api/v1/config/my-key", "tenant-b", "tenant-a"
    )
}

# operator: DENIED — cross-tenant write
test_operator_cannot_write_config_cross_tenant if {
    not config.allow with input as authenticated_input(
        ["operator"], "POST", "/api/v1/config", "tenant-b", "tenant-a"
    )
}

# operator: DENIED — bulk operations (no config:admin)
test_operator_cannot_bulk_config if {
    not config.allow with input as authenticated_input(
        ["operator"], "POST", "/api/v1/config/bulk", "tenant-a", "tenant-a"
    )
}

# operator: DENIED — admin config endpoint
test_operator_cannot_access_admin_config_endpoint if {
    not config.allow with input as authenticated_input(
        ["operator"], "GET", "/api/v1/admin/config", "tenant-a", "tenant-a"
    )
}

# ============================================================
# SERVICE ROLE TESTS
# ============================================================

# service: config:read — GET own tenant
test_service_can_read_config_own_tenant if {
    config.allow with input as authenticated_input(
        ["service"], "GET", "/api/v1/config/my-key", "tenant-a", "tenant-a"
    )
}

# service: DENIED — POST (no config:write)
test_service_cannot_write_config if {
    not config.allow with input as authenticated_input(
        ["service"], "POST", "/api/v1/config", "tenant-a", "tenant-a"
    )
}

# service: DENIED — PUT (no config:write)
test_service_cannot_update_config if {
    not config.allow with input as authenticated_input(
        ["service"], "PUT", "/api/v1/config/my-key", "tenant-a", "tenant-a"
    )
}

# service: DENIED — DELETE (no config:admin)
test_service_cannot_delete_config if {
    not config.allow with input as authenticated_input(
        ["service"], "DELETE", "/api/v1/config/my-key", "tenant-a", "tenant-a"
    )
}

# service: DENIED — cross-tenant read
test_service_cannot_read_config_cross_tenant if {
    not config.allow with input as authenticated_input(
        ["service"], "GET", "/api/v1/config/my-key", "tenant-b", "tenant-a"
    )
}

# service: DENIED — bulk operations
test_service_cannot_bulk_config if {
    not config.allow with input as authenticated_input(
        ["service"], "POST", "/api/v1/config/bulk", "tenant-a", "tenant-a"
    )
}

# ============================================================
# UNAUTHENTICATED / UNKNOWN ROLE TESTS
# ============================================================

# unauthenticated: DENIED — GET
test_unauthenticated_cannot_read_config if {
    not config.allow with input as {
        "auth": {
            "authenticated": false,
            "issuer": "keycloak",
            "subject": "user:anon",
            "roles": [],
            "tenant_id": "tenant-a",
        },
        "request": {
            "method": "GET",
            "resource": "/api/v1/config/my-key",
            "path": "/api/v1/config/my-key",
            "tenant_id": "tenant-a",
        },
    }
}

# unknown role: DENIED — GET
test_unknown_role_cannot_read_config if {
    not config.allow with input as authenticated_input(
        ["viewer"], "GET", "/api/v1/config/my-key", "tenant-a", "tenant-a"
    )
}

# unknown role: DENIED — POST
test_unknown_role_cannot_write_config if {
    not config.allow with input as authenticated_input(
        ["viewer"], "POST", "/api/v1/config", "tenant-a", "tenant-a"
    )
}

# ============================================================
# HEALTH ENDPOINT TESTS
# ============================================================

test_health_always_allowed if {
    config.allow with input as {
        "request": {"path": "/health", "resource": "/health", "method": "GET"},
    }
}

test_health_live_always_allowed if {
    config.allow with input as {
        "request": {"path": "/health/live", "resource": "/health/live", "method": "GET"},
    }
}

test_health_ready_always_allowed if {
    config.allow with input as {
        "request": {"path": "/health/ready", "resource": "/health/ready", "method": "GET"},
    }
}

# ============================================================
# PERMISSION DERIVATION TESTS
# ============================================================

# admin has all three permissions
test_admin_has_all_permissions if {
    perms := config.user_permissions with input as {
        "auth": {"roles": ["admin"], "tenant_id": "tenant-a"},
        "request": {"tenant_id": "tenant-a"},
    }
    "config:read" in perms
    "config:write" in perms
    "config:admin" in perms
}

# operator has read + write only
test_operator_has_read_write_permissions if {
    perms := config.user_permissions with input as {
        "auth": {"roles": ["operator"], "tenant_id": "tenant-a"},
        "request": {"tenant_id": "tenant-a"},
    }
    "config:read" in perms
    "config:write" in perms
    not "config:admin" in perms
}

# service has read only
test_service_has_read_only_permission if {
    perms := config.user_permissions with input as {
        "auth": {"roles": ["service"], "tenant_id": "tenant-a"},
        "request": {"tenant_id": "tenant-a"},
    }
    "config:read" in perms
    not "config:write" in perms
    not "config:admin" in perms
}

# ============================================================
# DENY REASON TESTS
# ============================================================

# deny reason for unauthenticated
test_deny_reason_unauthenticated if {
    reasons := config.deny_reasons with input as {
        "auth": {
            "authenticated": false,
            "issuer": "keycloak",
            "subject": "user:anon",
            "roles": [],
            "tenant_id": "tenant-a",
        },
        "request": {
            "method": "GET",
            "resource": "/api/v1/config/my-key",
            "path": "/api/v1/config/my-key",
            "tenant_id": "tenant-a",
        },
    }
    count(reasons) > 0
}

# deny reason for service trying to write
test_deny_reason_service_write if {
    reasons := config.deny_reasons with input as authenticated_input(
        ["service"], "POST", "/api/v1/config", "tenant-a", "tenant-a"
    )
    count(reasons) > 0
}

# deny reason for operator cross-tenant
test_deny_reason_operator_cross_tenant if {
    reasons := config.deny_reasons with input as authenticated_input(
        ["operator"], "POST", "/api/v1/config", "tenant-b", "tenant-a"
    )
    count(reasons) > 0
}
