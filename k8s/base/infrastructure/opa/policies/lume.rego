package nem.lume.main

import rego.v1

# Calendar and workspace ACLs are evaluated by the Lume API after this shared
# authentication gate. The OPA authorization handler provides JWT roles, the
# HTTP method, and the request path, but does not provide resource ACL data.
default allow := false

allow if {
    count(object.get(input, "roles", [])) > 0
}
