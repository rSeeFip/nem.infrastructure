package nem.mcp.controlplane.workflow_approve_test

import rego.v1

import data.nem.mcp.controlplane.workflow_approve

# ─── Allowed cases ───────────────────────────────────────────────

test_approver_allowed if {
	workflow_approve.allow with input as {
		"subject_roles": ["WorkflowApprover"],
	}
}

test_admin_can_approve if {
	workflow_approve.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
	}
}

test_federation_admin_bypass if {
	workflow_approve.allow with input as {
		"subject_roles": ["FederationAdmin"],
	}
}

test_multiple_roles_with_approver if {
	workflow_approve.allow with input as {
		"subject_roles": ["WorkflowViewer", "WorkflowApprover"],
	}
}

# ─── Denied cases ────────────────────────────────────────────────

test_executor_denied if {
	not workflow_approve.allow with input as {
		"subject_roles": ["WorkflowExecutor"],
	}
}

test_designer_denied if {
	not workflow_approve.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
	}
}

test_viewer_denied if {
	not workflow_approve.allow with input as {
		"subject_roles": ["WorkflowViewer"],
	}
}

test_empty_roles_denied if {
	not workflow_approve.allow with input as {
		"subject_roles": [],
	}
}

test_executor_and_viewer_denied if {
	not workflow_approve.allow with input as {
		"subject_roles": ["WorkflowExecutor", "WorkflowViewer"],
	}
}

# ─── Deny reasons ────────────────────────────────────────────────

test_deny_reasons_populated if {
	reasons := workflow_approve.deny_reasons with input as {
		"subject_roles": ["WorkflowExecutor"],
	}
	count(reasons) > 0
}

test_deny_reasons_empty_when_allowed if {
	reasons := workflow_approve.deny_reasons with input as {
		"subject_roles": ["WorkflowApprover"],
	}
	count(reasons) == 0
}
