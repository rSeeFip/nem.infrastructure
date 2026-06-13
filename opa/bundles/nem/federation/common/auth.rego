package nem.federation.common.auth

default allow := false

# Validates caller authentication context produced by API gateway/service.
allow if {
  input.auth.authenticated == true
  input.auth.issuer == "keycloak"
  startswith(input.auth.subject, "user:")
}

# Health and readiness endpoints are always allowed.
allow if {
  input.request.path == "/health"
}

allow if {
  input.request.path == "/health/live"
}

allow if {
  input.request.path == "/health/ready"
}
