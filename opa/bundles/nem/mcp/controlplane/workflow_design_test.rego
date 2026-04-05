package nem.mcp.controlplane.workflow_design_test

import rego.v1

import data.nem.mcp.controlplane.workflow_design

# ─── Allowed cases ───────────────────────────────────────────────

test_designer_allowed if {
	workflow_design.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
	}
}

test_admin_can_design if {
	workflow_design.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
	}
}

test_federation_admin_bypass if {
	workflow_design.allow with input as {
		"subject_roles": ["FederationAdmin"],
	}
}

test_multiple_roles_with_designer if {
	workflow_design.allow with input as {
		"subject_roles": ["WorkflowViewer", "WorkflowDesigner"],
	}
}

# ─── Denied cases ────────────────────────────────────────────────

test_executor_denied if {
	not workflow_design.allow with input as {
		"subject_roles": ["WorkflowExecutor"],
	}
}

test_viewer_denied if {
	not workflow_design.allow with input as {
		"subject_roles": ["WorkflowViewer"],
	}
}

test_approver_denied if {
	not workflow_design.allow with input as {
		"subject_roles": ["WorkflowApprover"],
	}
}

test_empty_roles_denied if {
	not workflow_design.allow with input as {
		"subject_roles": [],
	}
}

test_unknown_role_denied if {
	not workflow_design.allow with input as {
		"subject_roles": ["RandomRole"],
	}
}

# ─── Deny reasons ────────────────────────────────────────────────

test_deny_reasons_populated if {
	reasons := workflow_design.deny_reasons with input as {
		"subject_roles": ["WorkflowExecutor"],
	}
	count(reasons) > 0
}

test_deny_reasons_empty_when_allowed if {
	reasons := workflow_design.deny_reasons with input as {
		"subject_roles": ["WorkflowDesigner"],
	}
	count(reasons) == 0
}
