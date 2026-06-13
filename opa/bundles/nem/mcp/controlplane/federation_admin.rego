package nem.mcp.controlplane.federation_admin

default allow := false

allow if {
	input.operation_class
	input.subject_clearance
	input.request.path[0] == "admin"
	"FederationAdmin" in input.user.roles
}
