package nem.mcp.controlplane.workflow_view_test

import rego.v1

import data.nem.mcp.controlplane.workflow_view

# ─── Allowed cases (all workflow roles can view) ─────────────────

test_viewer_allowed if {
	workflow_view.allow with input as {
		"subject_roles": ["WorkflowViewer"],
	}
}

test_executor_can_view if {
	workflow_view.allow with input as {
		"subject_roles": ["WorkflowExecutor"],
	}
}

test_designer_can_view if {
	workflow_view.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
	}
}

test_approver_can_view if {
	workflow_view.allow with input as {
		"subject_roles": ["WorkflowApprover"],
	}
}

test_admin_can_view if {
	workflow_view.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
	}
}

test_federation_admin_bypass if {
	workflow_view.allow with input as {
		"subject_roles": ["FederationAdmin"],
	}
}

test_multiple_roles_allowed if {
	workflow_view.allow with input as {
		"subject_roles": ["WorkflowViewer", "WorkflowExecutor"],
	}
}

# ─── Denied cases ────────────────────────────────────────────────

test_empty_roles_denied if {
	not workflow_view.allow with input as {
		"subject_roles": [],
	}
}

test_unknown_role_denied if {
	not workflow_view.allow with input as {
		"subject_roles": ["SomeOtherRole"],
	}
}

test_non_workflow_roles_denied if {
	not workflow_view.allow with input as {
		"subject_roles": ["PluginAdmin", "KnowHubReader"],
	}
}

# ─── Deny reasons ────────────────────────────────────────────────

test_deny_reasons_populated if {
	reasons := workflow_view.deny_reasons with input as {
		"subject_roles": ["SomeOtherRole"],
	}
	count(reasons) > 0
}

test_deny_reasons_empty_when_allowed if {
	reasons := workflow_view.deny_reasons with input as {
		"subject_roles": ["WorkflowViewer"],
	}
	count(reasons) == 0
}
