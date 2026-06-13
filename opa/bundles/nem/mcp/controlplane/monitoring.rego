package nem.mcp.controlplane.monitoring

default allow := false

allow if {
	input.operation_class == "monitoring.read"
	input.subject_clearance
	input.resource == "monitoring"
	"MonitoringViewer" in input.user.roles
}
