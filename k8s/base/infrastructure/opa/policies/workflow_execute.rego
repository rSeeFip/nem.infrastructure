package nem.mcp.controlplane.workflow_execute

import rego.v1

default allow := false

execute_roles := {"WorkflowExecutor", "WorkflowDesigner", "WorkflowAdmin"}

has_subject_tenant if {
	object.get(input, "subject_tenant_id", "") != ""
}

has_resource_tenant if {
	object.get(input, "resource_tenant_id", "") != ""
}

tenant_context_complete if {
	has_subject_tenant
	has_resource_tenant
}

tenant_mismatch if {
	tenant_context_complete
	object.get(input, "subject_tenant_id", "") != object.get(input, "resource_tenant_id", "")
}

allow if {
	tenant_context_complete
	not tenant_mismatch
	some role in input.subject_roles
	role in execute_roles
}

allow if {
	tenant_context_complete
	not tenant_mismatch
	some role in input.subject_roles
	role == "FederationAdmin"
}

deny_reasons contains "Subject tenant context is required." if {
	not has_subject_tenant
}

deny_reasons contains "Resource tenant context is required." if {
	not has_resource_tenant
}

deny_reasons contains reason if {
	tenant_mismatch
	reason := sprintf("Subject tenant '%v' cannot access resource tenant '%v'", [object.get(input, "subject_tenant_id", ""), object.get(input, "resource_tenant_id", "")])
}

deny_reasons contains reason if {
	not allow
	tenant_context_complete
	not tenant_mismatch
	reason := sprintf("Subject lacks execute permission. Required roles: %v, subject roles: %v", [execute_roles, input.subject_roles])
}
