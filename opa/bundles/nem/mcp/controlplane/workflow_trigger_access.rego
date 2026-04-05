# Workflow Trigger Access Policy for nem.Workflow
# Package: nem.mcp.controlplane.workflow_trigger_access
#
# Controls who can manage workflow triggers (cron, webhook, event).
# Creating/updating/deleting triggers requires elevated roles.
# Viewing triggers follows the standard view policy.

package nem.mcp.controlplane.workflow_trigger_access

import rego.v1

default allow := false

# ─── Trigger operations ─────────────────────────────────────────
# Read operations
read_operations := {"trigger.list", "trigger.get"}

# Write operations (create/update/delete)
write_operations := {"trigger.create", "trigger.update", "trigger.delete"}

# ─── Roles for trigger management ────────────────────────────────
# Read: any workflow role can view triggers
read_roles := {
	"WorkflowViewer",
	"WorkflowExecutor",
	"WorkflowDesigner",
	"WorkflowApprover",
	"WorkflowAdmin",
}

# Write: only designers and admins can manage triggers
write_roles := {"WorkflowDesigner", "WorkflowAdmin"}

# ─── Allow read operations ───────────────────────────────────────
allow if {
	input.operation in read_operations
	some role in input.subject_roles
	role in read_roles
}

# ─── Allow write operations ──────────────────────────────────────
allow if {
	input.operation in write_operations
	some role in input.subject_roles
	role in write_roles
}

# ─── FederationAdmin bypasses all checks ─────────────────────────
allow if {
	some role in input.subject_roles
	role == "FederationAdmin"
}

# ─── Deny reasons for audit trail ────────────────────────────────
deny_reasons contains reason if {
	input.operation in read_operations
	not allow
	reason := sprintf("Subject lacks trigger read permission for operation '%s'. Required roles: %v, subject roles: %v", [input.operation, read_roles, input.subject_roles])
}

deny_reasons contains reason if {
	input.operation in write_operations
	not allow
	reason := sprintf("Subject lacks trigger write permission for operation '%s'. Required roles: %v, subject roles: %v", [input.operation, write_roles, input.subject_roles])
}

deny_reasons contains reason if {
	not input.operation in read_operations
	not input.operation in write_operations
	reason := sprintf("Unknown trigger operation '%s'", [input.operation])
}
