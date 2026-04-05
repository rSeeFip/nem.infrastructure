package nem.mcp.controlplane.data_access

default allow := false

allow if {
	input.operation_class == "data.export"
	input.subject_clearance
	input.action == "data.export"
	"DataAdmin" in input.user.roles
}
