package nem.mcp.controlplane.audit_log

default allow := false

allow if {
	input.operation_class == "audit.read"
	input.subject_clearance
	input.resource == "audit-log"
	"AuditViewer" in input.user.roles
}
