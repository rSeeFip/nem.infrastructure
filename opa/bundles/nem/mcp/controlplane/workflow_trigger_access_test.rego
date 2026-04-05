package nem.mcp.controlplane.workflow_trigger_access_test

import rego.v1

import data.nem.mcp.controlplane.workflow_trigger_access

# ─── Read operations: all workflow roles allowed ─────────────────

test_viewer_can_list_triggers if {
	workflow_trigger_access.allow with input as {
		"subject_roles": ["WorkflowViewer"],
		"operation": "trigger.list",
	}
}

test_executor_can_get_trigger if {
	workflow_trigger_access.allow with input as {
		"subject_roles": ["WorkflowExecutor"],
		"operation": "trigger.get",
	}
}

test_designer_can_list_triggers if {
	workflow_trigger_access.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
		"operation": "trigger.list",
	}
}

test_admin_can_list_triggers if {
	workflow_trigger_access.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
		"operation": "trigger.list",
	}
}

# ─── Write operations: designer and admin allowed ────────────────

test_designer_can_create_trigger if {
	workflow_trigger_access.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
		"operation": "trigger.create",
	}
}

test_admin_can_create_trigger if {
	workflow_trigger_access.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
		"operation": "trigger.create",
	}
}

test_admin_can_update_trigger if {
	workflow_trigger_access.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
		"operation": "trigger.update",
	}
}

test_designer_can_delete_trigger if {
	workflow_trigger_access.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
		"operation": "trigger.delete",
	}
}

# ─── Write operations: non-write roles denied ────────────────────

test_viewer_cannot_create_trigger if {
	not workflow_trigger_access.allow with input as {
		"subject_roles": ["WorkflowViewer"],
		"operation": "trigger.create",
	}
}

test_executor_cannot_update_trigger if {
	not workflow_trigger_access.allow with input as {
		"subject_roles": ["WorkflowExecutor"],
		"operation": "trigger.update",
	}
}

test_approver_cannot_delete_trigger if {
	not workflow_trigger_access.allow with input as {
		"subject_roles": ["WorkflowApprover"],
		"operation": "trigger.delete",
	}
}

# ─── Empty roles denied ──────────────────────────────────────────

test_empty_roles_read_denied if {
	not workflow_trigger_access.allow with input as {
		"subject_roles": [],
		"operation": "trigger.list",
	}
}

test_empty_roles_write_denied if {
	not workflow_trigger_access.allow with input as {
		"subject_roles": [],
		"operation": "trigger.create",
	}
}

# ─── FederationAdmin bypass ──────────────────────────────────────

test_federation_admin_read if {
	workflow_trigger_access.allow with input as {
		"subject_roles": ["FederationAdmin"],
		"operation": "trigger.list",
	}
}

test_federation_admin_write if {
	workflow_trigger_access.allow with input as {
		"subject_roles": ["FederationAdmin"],
		"operation": "trigger.create",
	}
}

# ─── Unknown operation ───────────────────────────────────────────

test_unknown_operation_denied if {
	not workflow_trigger_access.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
		"operation": "trigger.explode",
	}
}

# ─── Deny reasons ────────────────────────────────────────────────

test_deny_reasons_write_denied if {
	reasons := workflow_trigger_access.deny_reasons with input as {
		"subject_roles": ["WorkflowViewer"],
		"operation": "trigger.create",
	}
	count(reasons) > 0
}

test_deny_reasons_read_denied if {
	reasons := workflow_trigger_access.deny_reasons with input as {
		"subject_roles": ["SomeRole"],
		"operation": "trigger.list",
	}
	count(reasons) > 0
}

test_deny_reasons_unknown_operation if {
	reasons := workflow_trigger_access.deny_reasons with input as {
		"subject_roles": ["WorkflowAdmin"],
		"operation": "trigger.explode",
	}
	count(reasons) > 0
}

test_deny_reasons_empty_when_allowed if {
	reasons := workflow_trigger_access.deny_reasons with input as {
		"subject_roles": ["WorkflowDesigner"],
		"operation": "trigger.create",
	}
	count(reasons) == 0
}
