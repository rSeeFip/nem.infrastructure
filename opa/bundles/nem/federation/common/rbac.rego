package nem.federation.common.rbac

default allow := false

required_roles := {
  "GET:/api/admin": {"admin", "FederationAdmin"},
  "POST:/api/admin": {"admin", "FederationAdmin"},
  "PUT:/api/admin": {"admin", "FederationAdmin"},
  "DELETE:/api/admin": {"admin", "FederationAdmin"}
}

request_key := sprintf("%s:%s", [upper(input.request.method), input.request.resource])

allow if {
  some role in input.auth.roles
  role in required_roles[request_key]
}

# Default user access for non-admin resources.
allow if {
  startswith(input.request.resource, "/api/")
  not startswith(input.request.resource, "/api/admin")
  input.auth.authenticated == true
}
