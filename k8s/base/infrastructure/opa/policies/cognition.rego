package nem.cognition

import rego.v1

# Cognition.Host memory APIs (episodes, semantic facts, consolidation) carry
# tenant-scoped cognitive memory. Reads and writes require an authenticated
# principal holding an operator-grade role; everything else stays denied.
default allow := false

operator_roles := {"admin", "platform-admin", "FederationAdmin", "nem:developer"}

allow if {
	some role in object.get(input, "roles", [])
	role in operator_roles
	startswith(lower(object.get(input, "path", "")), "/api/")
}
