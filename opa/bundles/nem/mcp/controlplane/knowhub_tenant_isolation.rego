package nem.mcp.controlplane.knowhub_tenant_isolation

import rego.v1

default allow := false

tenant_scoped_actions := {
	"knowhub.search",
	"knowhub.query",
	"knowhub.ingest",
}

allow if {
	not input.action in tenant_scoped_actions
}

allow if {
	input.action in tenant_scoped_actions
	tenant := trim(input.request.tenant_id)
	tenant != ""
	tenant == trim(input.principal.tenant_id)
}

allow if {
	input.action in tenant_scoped_actions
	"PlatformAdmin" in input.principal.roles
}

deny_reasons contains reason if {
	input.action in tenant_scoped_actions
	tenant := trim(input.request.tenant_id)
	tenant == ""
	reason := "tenant_id is required for tenant-scoped KnowHub operations"
}

deny_reasons contains reason if {
	input.action in tenant_scoped_actions
	tenant := trim(input.request.tenant_id)
	tenant != ""
	tenant != trim(input.principal.tenant_id)
	not "PlatformAdmin" in input.principal.roles
	reason := "cross-tenant KnowHub access is forbidden"
}

trim(value) := normalized if {
	normalized := lower(trim_space(sprintf("%v", [value])))
}
