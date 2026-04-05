package nem.federation.services.knowhub

default allow := false

import data.nem.federation.common.auth
import data.nem.federation.common.rbac
import data.nem.federation.common.rate_limit

allow if {
  auth.allow
  rbac.allow
  rate_limit.allow
}

# Restrict document deletion to admins.
allow if {
  auth.allow
  input.request.resource == "/api/v1/documents"
  upper(input.request.method) == "DELETE"
  some role in input.auth.roles
  role == "admin"
}
