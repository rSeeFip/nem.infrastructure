# Workflow Admin Policy for nem.Workflow
# Package: nem.mcp.controlplane.workflow_admin
#
# Controls who can manage workflow settings, users, and permissions.
# Allowed roles: WorkflowAdmin, FederationAdmin

package nem.mcp.controlplane.workflow_admin

import rego.v1

default allow := false

# Only WorkflowAdmin can manage workflow settings/users/permissions
admin_roles := {"WorkflowAdmin"}

# Allow if subject has admin role
allow if {
	some role in input.subject_roles
	role in admin_roles
}

# FederationAdmin bypasses all checks
allow if {
	some role in input.subject_roles
	role == "FederationAdmin"
}

# Deny reasons for audit trail
deny_reasons contains reason if {
	not allow
	reason := sprintf("Subject lacks admin permission. Required roles: %v, subject roles: %v", [admin_roles, input.subject_roles])
}
