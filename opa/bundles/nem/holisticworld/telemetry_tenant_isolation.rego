package nem.holisticworld.telemetry_tenant_isolation

import rego.v1

default allow := false

tenant_scoped_actions := {
	"telemetry.ingest",
	"telemetry.latest",
	"telemetry.range",
	"telemetry.aggregate",
}

allow if {
	input.action in tenant_scoped_actions
	trim(input.claims.tenant_id) != ""
	trim(input.resource.tenant_id) != ""
	trim(input.claims.tenant_id) == trim(input.resource.tenant_id)
}

reasons contains "tenant_id claim is required for telemetry access" if {
	input.action in tenant_scoped_actions
	trim(input.claims.tenant_id) == ""
}

reasons contains "resource tenant_id is required for telemetry access" if {
	input.action in tenant_scoped_actions
	trim(input.claims.tenant_id) != ""
	trim(input.resource.tenant_id) == ""
}

reasons contains "cross-tenant telemetry access is forbidden" if {
	input.action in tenant_scoped_actions
	trim(input.claims.tenant_id) != ""
	trim(input.resource.tenant_id) != ""
	trim(input.claims.tenant_id) != trim(input.resource.tenant_id)
}

reasons contains "telemetry action is not covered by tenant isolation policy" if {
	not input.action in tenant_scoped_actions
}

result := {
	"allow": allow,
	"reasons": sort([reason | reason := reasons[_]]),
}

trim(value) := normalized if {
	normalized := lower(trim_space(sprintf("%v", [value])))
}
