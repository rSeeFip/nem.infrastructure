package nem.federation.tests.service_auth

import data.nem.federation.common.service_auth

test_service_auth_allows_valid_service_jwt if {
  service_auth.allow with input as {
    "service": {
      "authenticated": true,
      "subject": "svc:nem.mcp",
      "token_type": "service-jwt",
      "mtls_verified": false
    }
  }
}

test_service_auth_allows_mtls_verified_service if {
  service_auth.allow with input as {
    "service": {
      "authenticated": true,
      "subject": "svc:nem.inference",
      "token_type": "opaque",
      "mtls_verified": true
    }
  }
}

test_service_auth_denies_non_service_subject if {
  not service_auth.allow with input as {
    "service": {
      "authenticated": true,
      "subject": "user:alice",
      "token_type": "service-jwt",
      "mtls_verified": true
    }
  }
}
