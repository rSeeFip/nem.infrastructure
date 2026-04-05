# Workflow Execute Policy for nem.Workflow
# Package: nem.mcp.controlplane.workflow_execute
#
# Controls who can execute/run workflows.
# Allowed roles: WorkflowExecutor, WorkflowDesigner, WorkflowAdmin, FederationAdmin

package nem.mcp.controlplane.workflow_execute

import rego.v1

default allow := false

# Roles permitted to execute workflows
execute_roles := {"WorkflowExecutor", "WorkflowDesigner", "WorkflowAdmin"}

# Allow if subject has any execute-permitted role
allow if {
	some role in input.subject_roles
	role in execute_roles
}

# FederationAdmin bypasses all checks
allow if {
	some role in input.subject_roles
	role == "FederationAdmin"
}

# Deny reasons for audit trail
deny_reasons contains reason if {
	not allow
	reason := sprintf("Subject lacks execute permission. Required roles: %v, subject roles: %v", [execute_roles, input.subject_roles])
}
