package nem.federation.services.mcp

default allow := false

import data.nem.federation.common.auth
import data.nem.federation.common.rbac
import data.nem.federation.common.rate_limit

allow if {
  auth.allow
  rbac.allow
  rate_limit.allow
}

# MCP lifecycle and control plane admin operations require elevated roles.
allow if {
  auth.allow
  input.request.resource == "/api/v1/federation/services"
  some role in input.auth.roles
  role == "FederationAdmin"
}
