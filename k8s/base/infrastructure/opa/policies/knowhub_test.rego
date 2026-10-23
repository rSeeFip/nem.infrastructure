package nem.knowhub.rbac_test

import rego.v1
import data.nem.knowhub.rbac

test_allows_knowhub_admin if {
    rbac.allow with input as {"roles": ["KnowHub.Admin"], "path": "/api/v1/admin/mcp-credentials", "method": "GET"}
}

test_denies_other_roles if {
    not rbac.allow with input as {"roles": ["KnowHub.Viewer", "admin"], "path": "/api/v1/admin/mcp-credentials", "method": "GET"}
}

test_denies_missing_roles if {
    not rbac.allow with input as {"path": "/api/v1/admin/mcp-credentials", "method": "GET"}
}
