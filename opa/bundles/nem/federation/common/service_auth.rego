package nem.federation.common.service_auth

default allow := false

# Service-to-service caller identity should be a service principal.
allow if {
  input.service.authenticated == true
  startswith(input.service.subject, "svc:")
  input.service.token_type == "service-jwt"
}

# Optional mTLS pinning metadata check when provided.
allow if {
  input.service.authenticated == true
  startswith(input.service.subject, "svc:")
  input.service.mtls_verified == true
}
