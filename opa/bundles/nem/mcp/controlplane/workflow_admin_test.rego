package nem.mcp.controlplane.workflow_admin_test

import rego.v1

import data.nem.mcp.controlplane.workflow_admin

# ─── Allowed cases ───────────────────────────────────────────────

test_admin_allowed if {
	workflow_admin.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
	}
}

test_federation_admin_bypass if {
	workflow_admin.allow with input as {
		"subject_roles": ["FederationAdmin"],
	}
}

test_admin_with_multiple_roles if {
	workflow_admin.allow with input as {
		"subject_roles": ["WorkflowViewer", "WorkflowAdmin"],
	}
}

# ─── Denied cases ────────────────────────────────────────────────

test_designer_denied if {
	not workflow_admin.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
	}
}

test_executor_denied if {
	not workflow_admin.allow with input as {
		"subject_roles": ["WorkflowExecutor"],
	}
}

test_viewer_denied if {
	not workflow_admin.allow with input as {
		"subject_roles": ["WorkflowViewer"],
	}
}

test_approver_denied if {
	not workflow_admin.allow with input as {
		"subject_roles": ["WorkflowApprover"],
	}
}

test_empty_roles_denied if {
	not workflow_admin.allow with input as {
		"subject_roles": [],
	}
}

test_multiple_non_admin_roles_denied if {
	not workflow_admin.allow with input as {
		"subject_roles": ["WorkflowDesigner", "WorkflowExecutor", "WorkflowViewer"],
	}
}

# ─── Deny reasons ────────────────────────────────────────────────

test_deny_reasons_populated if {
	reasons := workflow_admin.deny_reasons with input as {
		"subject_roles": ["WorkflowDesigner"],
	}
	count(reasons) > 0
}

test_deny_reasons_empty_when_allowed if {
	reasons := workflow_admin.deny_reasons with input as {
		"subject_roles": ["WorkflowAdmin"],
	}
	count(reasons) == 0
}
