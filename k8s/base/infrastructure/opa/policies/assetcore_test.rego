package nem.assetcore.rbac_test

import rego.v1
import data.nem.assetcore.rbac

test_allows_equipment_post_for_admin if {
    rbac.allow with input as {
        "roles": ["admin"],
        "path": "/api/v1/equipment",
        "method": "POST",
    }
}

test_allows_equipment_put_for_federation_admin if {
    rbac.allow with input as {
        "roles": ["FederationAdmin"],
        "path": "/api/v1/equipment/11111111-1111-1111-1111-111111111111",
        "method": "PUT",
    }
}

test_allows_assetcore_admin if {
    rbac.allow with input as {
        "roles": ["assetcore:admin"],
        "path": "/api/v1/work-requests",
        "method": "POST",
    }
}

test_denies_equipment_post_for_user if {
    not rbac.allow with input as {
        "roles": ["user"],
        "path": "/api/v1/equipment",
        "method": "POST",
    }
}

test_denies_admin_write_outside_equipment if {
    not rbac.allow with input as {
        "roles": ["admin"],
        "path": "/api/v1/work-requests",
        "method": "POST",
    }
}

test_denies_empty_roles if {
    not rbac.allow with input as {
        "roles": [],
        "path": "/api/v1/equipment",
        "method": "DELETE",
    }
}
