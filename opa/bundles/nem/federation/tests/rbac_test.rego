package nem.federation.tests.rbac

import data.nem.federation.common.rbac

test_rbac_allows_admin_endpoint_for_admin_role if {
  rbac.allow with input as {
    "auth": {"authenticated": true, "roles": ["admin"]},
    "request": {"method": "GET", "resource": "/api/admin"}
  }
}

test_rbac_denies_admin_endpoint_for_user_role if {
  not rbac.allow with input as {
    "auth": {"authenticated": true, "roles": ["user"]},
    "request": {"method": "GET", "resource": "/api/admin"}
  }
}

test_rbac_allows_non_admin_api_for_authenticated_user if {
  rbac.allow with input as {
    "auth": {"authenticated": true, "roles": ["user"]},
    "request": {"method": "GET", "resource": "/api/v1/items"}
  }
}
