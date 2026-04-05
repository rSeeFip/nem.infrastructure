# Workflow Approve Policy for nem.Workflow
# Package: nem.mcp.controlplane.workflow_approve
#
# Controls who can approve workflow runs (for suspend/wait steps).
# Allowed roles: WorkflowApprover, WorkflowAdmin, FederationAdmin

package nem.mcp.controlplane.workflow_approve

import rego.v1

default allow := false

# Roles permitted to approve workflow runs
approve_roles := {"WorkflowApprover", "WorkflowAdmin"}

# Allow if subject has any approve-permitted role
allow if {
	some role in input.subject_roles
	role in approve_roles
}

# FederationAdmin bypasses all checks
allow if {
	some role in input.subject_roles
	role == "FederationAdmin"
}

# Deny reasons for audit trail
deny_reasons contains reason if {
	not allow
	reason := sprintf("Subject lacks approval permission. Required roles: %v, subject roles: %v", [approve_roles, input.subject_roles])
}
