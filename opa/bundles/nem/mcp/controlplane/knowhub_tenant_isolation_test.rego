package nem.mcp.controlplane.knowhub_tenant_isolation_test

import rego.v1

import data.nem.mcp.controlplane.knowhub_tenant_isolation

test_non_scoped_action_allowed if {
	knowhub_tenant_isolation.allow with input as {
		"action": "pipeline.trigger",
		"request": {"tenant_id": "tenant-a"},
		"principal": {"tenant_id": "tenant-b", "roles": []},
	}
}

test_same_tenant_allowed if {
	knowhub_tenant_isolation.allow with input as {
		"action": "knowhub.search",
		"request": {"tenant_id": "Tenant-A"},
		"principal": {"tenant_id": "tenant-a", "roles": ["User"]},
	}
}

test_cross_tenant_denied if {
	not knowhub_tenant_isolation.allow with input as {
		"action": "knowhub.query",
		"request": {"tenant_id": "tenant-b"},
		"principal": {"tenant_id": "tenant-a", "roles": ["User"]},
	}
}

test_missing_tenant_denied if {
	not knowhub_tenant_isolation.allow with input as {
		"action": "knowhub.ingest",
		"request": {},
		"principal": {"tenant_id": "tenant-a", "roles": ["User"]},
	}
}

test_platform_admin_override_allowed if {
	knowhub_tenant_isolation.allow with input as {
		"action": "knowhub.search",
		"request": {"tenant_id": "tenant-b"},
		"principal": {"tenant_id": "tenant-a", "roles": ["PlatformAdmin"]},
	}
}

test_deny_reason_present_for_cross_tenant if {
	reasons := knowhub_tenant_isolation.deny_reasons with input as {
		"action": "knowhub.query",
		"request": {"tenant_id": "tenant-b"},
		"principal": {"tenant_id": "tenant-a", "roles": ["User"]},
	}
	"cross-tenant KnowHub access is forbidden" in reasons
}
