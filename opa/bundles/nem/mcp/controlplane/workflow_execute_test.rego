package nem.mcp.controlplane.workflow_execute_test

import rego.v1

import data.nem.mcp.controlplane.workflow_execute

# ─── Allowed cases ───────────────────────────────────────────────

test_executor_allowed if {
	workflow_execute.allow with input as {
		"subject_roles": ["WorkflowExecutor"],
	}
}

test_designer_can_execute if {
	workflow_execute.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
	}
}

test_admin_can_execute if {
	workflow_execute.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
	}
}

test_federation_admin_bypass if {
	workflow_execute.allow with input as {
		"subject_roles": ["FederationAdmin"],
	}
}

test_multiple_roles_allowed if {
	workflow_execute.allow with input as {
		"subject_roles": ["WorkflowViewer", "WorkflowExecutor"],
	}
}

# ─── Denied cases ────────────────────────────────────────────────

test_viewer_denied if {
	not workflow_execute.allow with input as {
		"subject_roles": ["WorkflowViewer"],
	}
}

test_approver_denied if {
	not workflow_execute.allow with input as {
		"subject_roles": ["WorkflowApprover"],
	}
}

test_empty_roles_denied if {
	not workflow_execute.allow with input as {
		"subject_roles": [],
	}
}

test_unknown_role_denied if {
	not workflow_execute.allow with input as {
		"subject_roles": ["SomeOtherRole"],
	}
}

# ─── Deny reasons ────────────────────────────────────────────────

test_deny_reasons_populated if {
	reasons := workflow_execute.deny_reasons with input as {
		"subject_roles": ["WorkflowViewer"],
	}
	count(reasons) > 0
}

test_deny_reasons_empty_when_allowed if {
	reasons := workflow_execute.deny_reasons with input as {
		"subject_roles": ["WorkflowExecutor"],
	}
	count(reasons) == 0
}
