package nem.federation.tests.auth

import data.nem.federation.common.auth

test_auth_allows_authenticated_user if {
  auth.allow with input as {
    "auth": {"authenticated": true, "issuer": "keycloak", "subject": "user:alice"},
    "request": {"path": "/api/v1/items"}
  }
}

test_auth_denies_unauthenticated_user if {
  not auth.allow with input as {
    "auth": {"authenticated": false, "issuer": "keycloak", "subject": "user:alice"},
    "request": {"path": "/api/v1/items"}
  }
}

test_auth_allows_health_endpoint if {
  auth.allow with input as {
    "auth": {"authenticated": false, "issuer": "none", "subject": "anonymous"},
    "request": {"path": "/health"}
  }
}
