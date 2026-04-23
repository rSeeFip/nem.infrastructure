package nem.holisticworld.telemetry_tenant_isolation_test

import rego.v1

import data.nem.holisticworld.telemetry_tenant_isolation

test_same_tenant_ingest_allowed if {
	result := telemetry_tenant_isolation.result with input as {
		"action": "telemetry.ingest",
		"claims": {"tenant_id": "Tenant-A"},
		"resource": {"tenant_id": "tenant-a"},
	}
	result.allow
}

test_same_tenant_latest_allowed if {
	result := telemetry_tenant_isolation.result with input as {
		"action": "telemetry.latest",
		"claims": {"tenant_id": "tenant-a"},
		"resource": {"tenant_id": "tenant-a"},
	}
	result.allow
}

test_cross_tenant_denied if {
	result := telemetry_tenant_isolation.result with input as {
		"action": "telemetry.range",
		"claims": {"tenant_id": "tenant-a"},
		"resource": {"tenant_id": "tenant-b"},
	}
	not result.allow
	"cross-tenant telemetry access is forbidden" in result.reasons
}

test_missing_claim_denied if {
	result := telemetry_tenant_isolation.result with input as {
		"action": "telemetry.aggregate",
		"claims": {},
		"resource": {"tenant_id": "tenant-a"},
	}
	not result.allow
	"tenant_id claim is required for telemetry access" in result.reasons
}

test_unknown_action_denied if {
	result := telemetry_tenant_isolation.result with input as {
		"action": "telemetry.delete",
		"claims": {"tenant_id": "tenant-a"},
		"resource": {"tenant_id": "tenant-a"},
	}
	not result.allow
	"telemetry action is not covered by tenant isolation policy" in result.reasons
}
