package nem.mcp.controlplane.config_admin

default allow := false

allow if {
	input.operation_class
	input.subject_clearance
	input.user.roles[_] == "nem:config:admin"
}
