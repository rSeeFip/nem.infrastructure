# Workflow Tenant Isolation Policy for nem.Workflow
# Package: nem.mcp.controlplane.workflow_tenant_isolation
#
# Controls cross-tenant resource access at the federation boundary.
# This policy is intentionally ROLE-FREE: it enforces only tenant ownership.
# Consumers: FederationTenantMiddleware, WorkflowFederationContextAccessor
#
# Input schema:
#   {
#     "tenant_id":           string   — caller's resolved tenant id (from X-Nem-Tenant-Id header or JWT)
#     "resource_tenant_id":  string   — owning tenant id of the resource being accessed
#     "action":              string   — optional; reserved for future use
#     "is_federation_admin": boolean  — true when caller holds FederationAdmin bypass privilege
#   }
#
# Rules:
#   allow = true  iff  tenant_id == resource_tenant_id
#   allow = true  iff  is_federation_admin == true
#   allow = false (default) — missing tenant_id, mismatch, or no bypass

package nem.mcp.controlplane.workflow_tenant_isolation

import rego.v1

default allow := false

# Allow when the caller's tenant matches the resource's tenant
allow if {
	object.get(input, "tenant_id", "") != ""
	object.get(input, "resource_tenant_id", "") != ""
	input.tenant_id == input.resource_tenant_id
}

# FederationAdmin bypasses tenant ownership checks entirely
allow if {
	input.is_federation_admin == true
}

# Deny reasons for audit trail
deny_reasons contains reason if {
	not allow
	object.get(input, "tenant_id", "") == ""
	reason := "Access denied: tenant_id is missing or empty"
}

deny_reasons contains reason if {
	not allow
	object.get(input, "tenant_id", "") != ""
	object.get(input, "resource_tenant_id", "") != ""
	input.tenant_id != input.resource_tenant_id
	reason := sprintf(
		"Access denied: caller tenant '%v' does not match resource tenant '%v'",
		[input.tenant_id, input.resource_tenant_id],
	)
}
