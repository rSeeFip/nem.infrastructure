package nem.knowhub.rbac

import rego.v1

default allow := false

allow if {
    "KnowHub.Admin" in input.roles
}
