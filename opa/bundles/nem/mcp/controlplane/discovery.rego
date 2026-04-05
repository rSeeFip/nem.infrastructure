package nem.mcp.controlplane.discovery

# Service Visibility Policy
# Controls which services a user can discover based on their roles
# and the service's visibility tag.
#
# Input schema:
#   input.user.roles       — list of role names (e.g., ["FederationAdmin", "ServiceOperator"])
#   input.service.visibility — visibility tag ("public", "internal", "operator")
#   input.action           — the action being performed (e.g., "discover", "register")

default allow := false

# FederationAdmin can discover ALL services regardless of visibility
allow if {
	"FederationAdmin" in input.user.roles
}

# ServiceOperator can discover public, internal, and operator services
allow if {
	"ServiceOperator" in input.user.roles
	input.service.visibility in {"public", "internal", "operator"}
}

# Any authenticated user can discover public services only
allow if {
	count(input.user.roles) > 0
	input.service.visibility == "public"
}

# Registration requires FederationAdmin or ServiceOperator role
allow if {
	input.action == "register"
	{"FederationAdmin", "ServiceOperator"} & {role | role := input.user.roles[_]} != set()
}

# Deregistration requires FederationAdmin role only
allow if {
	input.action == "deregister"
	"FederationAdmin" in input.user.roles
}

# Deny reasons for audit trail
reasons[msg] if {
	not allow
	count(input.user.roles) == 0
	msg := "No roles present — deny-safe default applied."
}

reasons[msg] if {
	not allow
	input.action == "discover"
	input.service.visibility != "public"
	not "FederationAdmin" in input.user.roles
	not "ServiceOperator" in input.user.roles
	msg := sprintf("User lacks required role to discover '%s' service.", [input.service.visibility])
}

reasons[msg] if {
	not allow
	input.action == "register"
	not "FederationAdmin" in input.user.roles
	not "ServiceOperator" in input.user.roles
	msg := "Service registration requires FederationAdmin or ServiceOperator role."
}

reasons[msg] if {
	not allow
	input.action == "deregister"
	not "FederationAdmin" in input.user.roles
	msg := "Service deregistration requires FederationAdmin role."
}
