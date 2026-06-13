# Workflow Design Policy for nem.Workflow
# Package: nem.mcp.controlplane.workflow_design
#
# Controls who can create/edit workflow definitions.
# Allowed roles: WorkflowDesigner, WorkflowAdmin, FederationAdmin

package nem.mcp.controlplane.workflow_design

import rego.v1

default allow := false

# Roles permitted to design (create/edit) workflows
design_roles := {"WorkflowDesigner", "WorkflowAdmin"}

# Allow if subject has any design-permitted role
allow if {
	some role in input.subject_roles
	role in design_roles
}

# FederationAdmin bypasses all checks
allow if {
	some role in input.subject_roles
	role == "FederationAdmin"
}

# Deny reasons for audit trail
deny_reasons contains reason if {
	not allow
	reason := sprintf("Subject lacks design permission. Required roles: %v, subject roles: %v", [design_roles, input.subject_roles])
}
