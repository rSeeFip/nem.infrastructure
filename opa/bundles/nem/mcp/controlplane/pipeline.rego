package nem.mcp.controlplane.pipeline

default allow := false

allow if {
	input.operation_class == "pipeline.trigger"
	input.subject_clearance
	input.action == "pipeline.trigger"
	"PipelineAdmin" in input.user.roles
}
