package nem.mcp.controlplane.deployment

default allow := false

allow if {
	input.operation_class == "deployment.execute"
	input.subject_clearance
	input.action == "deployment.execute"
	"DeploymentAdmin" in input.user.roles
}
