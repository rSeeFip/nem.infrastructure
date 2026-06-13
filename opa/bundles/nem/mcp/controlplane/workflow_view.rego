# Workflow View Policy for nem.Workflow
# Package: nem.mcp.controlplane.workflow_view
#
# Controls who can view workflow definitions and run history.
# All workflow roles can view — this is the broadest permission.
# Allowed roles: WorkflowViewer, WorkflowExecutor, WorkflowDesigner,
#                WorkflowApprover, WorkflowAdmin, FederationAdmin

package nem.mcp.controlplane.workflow_view

import rego.v1

default allow := false

# All workflow-specific roles can view
view_roles := {
	"WorkflowViewer",
	"WorkflowExecutor",
	"WorkflowDesigner",
	"WorkflowApprover",
	"WorkflowAdmin",
}

# Allow if subject has any workflow role
allow if {
	some role in input.subject_roles
	role in view_roles
}

# FederationAdmin bypasses all checks
allow if {
	some role in input.subject_roles
	role == "FederationAdmin"
}

# Deny reasons for audit trail
deny_reasons contains reason if {
	not allow
	reason := sprintf("Subject lacks view permission. Required roles: %v, subject roles: %v", [view_roles, input.subject_roles])
}
