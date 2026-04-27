package nem.mcp.controlplane.workflow_tenant_isolation_test

import rego.v1

import data.nem.mcp.controlplane.workflow_tenant_isolation

# ─── Acceptance Scenario 1: Same tenant → allow ──────────────────
# { tenant_id: "A", resource_tenant_id: "A" } → allow == true

test_same_tenant_allowed if {
	workflow_tenant_isolation.allow with input as {
		"tenant_id": "tenant-A",
		"resource_tenant_id": "tenant-A",
	}
}

test_same_tenant_with_action_allowed if {
	workflow_tenant_isolation.allow with input as {
		"tenant_id": "tenant-A",
		"resource_tenant_id": "tenant-A",
		"action": "read",
	}
}

# ─── Acceptance Scenario 2: Tenant mismatch → deny ───────────────
# { tenant_id: "A", resource_tenant_id: "B" } → allow == false

test_tenant_mismatch_denied if {
	not workflow_tenant_isolation.allow with input as {
		"tenant_id": "tenant-A",
		"resource_tenant_id": "tenant-B",
	}
}

test_tenant_mismatch_with_action_denied if {
	not workflow_tenant_isolation.allow with input as {
		"tenant_id": "tenant-A",
		"resource_tenant_id": "tenant-B",
		"action": "write",
	}
}

# ─── Acceptance Scenario 3: FederationAdmin bypass → allow ───────
# { tenant_id: "A", resource_tenant_id: "B", is_federation_admin: true } → allow == true

test_federation_admin_bypasses_mismatch if {
	workflow_tenant_isolation.allow with input as {
		"tenant_id": "tenant-A",
		"resource_tenant_id": "tenant-B",
		"is_federation_admin": true,
	}
}

test_federation_admin_no_tenant_id_allowed if {
	workflow_tenant_isolation.allow with input as {
		"resource_tenant_id": "tenant-A",
		"is_federation_admin": true,
	}
}

test_federation_admin_same_tenant_allowed if {
	workflow_tenant_isolation.allow with input as {
		"tenant_id": "tenant-A",
		"resource_tenant_id": "tenant-A",
		"is_federation_admin": true,
	}
}

# ─── Acceptance Scenario 4: Missing tenant_id → deny ─────────────
# { resource_tenant_id: "A" } (no tenant_id) → allow == false

test_missing_tenant_id_denied if {
	not workflow_tenant_isolation.allow with input as {
		"resource_tenant_id": "tenant-A",
	}
}

test_empty_tenant_id_denied if {
	not workflow_tenant_isolation.allow with input as {
		"tenant_id": "",
		"resource_tenant_id": "tenant-A",
	}
}

test_missing_both_tenant_ids_denied if {
	not workflow_tenant_isolation.allow with input as {"action": "read"}
}

test_is_federation_admin_false_and_mismatch_denied if {
	not workflow_tenant_isolation.allow with input as {
		"tenant_id": "tenant-A",
		"resource_tenant_id": "tenant-B",
		"is_federation_admin": false,
	}
}

# ─── Deny reasons ────────────────────────────────────────────────

test_deny_reason_missing_tenant if {
	reasons := workflow_tenant_isolation.deny_reasons with input as {
		"resource_tenant_id": "tenant-A",
	}
	count(reasons) > 0
}

test_deny_reason_mismatch if {
	reasons := workflow_tenant_isolation.deny_reasons with input as {
		"tenant_id": "tenant-A",
		"resource_tenant_id": "tenant-B",
	}
	count(reasons) > 0
}

test_no_deny_reasons_when_allowed if {
	reasons := workflow_tenant_isolation.deny_reasons with input as {
		"tenant_id": "tenant-A",
		"resource_tenant_id": "tenant-A",
	}
	count(reasons) == 0
}

test_no_deny_reasons_federation_admin if {
	reasons := workflow_tenant_isolation.deny_reasons with input as {
		"tenant_id": "tenant-A",
		"resource_tenant_id": "tenant-B",
		"is_federation_admin": true,
	}
	count(reasons) == 0
}
