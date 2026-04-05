package nem.federation.services.inference

default allow := false

import data.nem.federation.common.auth
import data.nem.federation.common.rate_limit
import data.nem.federation.common.service_auth

# User inference requests need auth + rate-limit checks.
allow if {
  auth.allow
  rate_limit.allow
}

# Service-to-service inference calls must carry service auth.
allow if {
  input.request.resource == "/api/v1/inference/internal"
  service_auth.allow
}
