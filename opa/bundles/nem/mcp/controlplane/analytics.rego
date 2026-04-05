package nem.mcp.controlplane.analytics

default allow := false

allow if {
	input.operation_class == "analytics.read"
	input.subject_clearance
	input.resource == "analytics"
	"AnalyticsViewer" in input.user.roles
}
