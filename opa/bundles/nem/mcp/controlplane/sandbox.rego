package nem.mcp.controlplane.sandbox

default allow := false

allow if {
	input.operation_class == "sandbox.execute"
	input.subject_clearance
	input.resource == "sandbox"
	"SandboxOperator" in input.user.roles
}
