package nem.erp.authz

import rego.v1

default allow := false

administrator_roles := {"admin", "FederationAdmin"}

allow if {
    is_administrator
    upper(object.get(input, "method", "")) == "GET"
    object.get(input, "path", "") == "/api/v1/configuration/status"
}

allow if {
    is_administrator
    upper(object.get(input, "method", "")) == "POST"
    object.get(input, "path", "") == "/api/v1/configuration/refresh"
}

is_administrator if {
    roles := object.get(input, "roles", [])
    some role in roles
    role in administrator_roles
}
