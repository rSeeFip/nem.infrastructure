package nem.mcp.controlplane.rate_limit_override

default exempt := false

exempt if {
	input.operation_class
	input.subject_clearance
	"FederationAdmin" in input.user.roles
}
