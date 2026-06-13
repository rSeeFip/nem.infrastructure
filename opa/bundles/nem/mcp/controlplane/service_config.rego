package nem.mcp.controlplane.service_config

default allow := false

allow if {
	input.operation_class == "config.update"
	input.subject_clearance
	input.action == "config.update"
	"ConfigManager" in input.user.roles
}
