package nem.mcp.controlplane.workflow_node_access_test

import rego.v1

import data.nem.mcp.controlplane.workflow_node_access

# ─── Standard nodes: Designer allowed ────────────────────────────

test_designer_delay_allowed if {
	workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
		"node_type": "delay",
	}
}

test_designer_condition_allowed if {
	workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
		"node_type": "condition",
	}
}

test_designer_log_allowed if {
	workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
		"node_type": "log",
	}
}

test_designer_branch_allowed if {
	workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
		"node_type": "branch",
	}
}

# ─── Standard nodes: Admin allowed ───────────────────────────────

test_admin_standard_allowed if {
	workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
		"node_type": "transform",
	}
}

# ─── Elevated nodes: Admin allowed ──────────────────────────────

test_admin_llm_allowed if {
	workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
		"node_type": "llm",
	}
}

test_admin_external_api_allowed if {
	workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
		"node_type": "external_api",
	}
}

test_admin_shell_command_allowed if {
	workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
		"node_type": "shell_command",
	}
}

test_admin_database_query_allowed if {
	workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
		"node_type": "database_query",
	}
}

# ─── Elevated nodes: Designer DENIED ────────────────────────────

test_designer_llm_denied if {
	not workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
		"node_type": "llm",
	}
}

test_designer_shell_denied if {
	not workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
		"node_type": "shell_command",
	}
}

test_designer_external_api_denied if {
	not workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowDesigner"],
		"node_type": "external_api",
	}
}

# ─── Non-design roles denied for all node types ─────────────────

test_executor_standard_denied if {
	not workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowExecutor"],
		"node_type": "delay",
	}
}

test_viewer_elevated_denied if {
	not workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowViewer"],
		"node_type": "llm",
	}
}

test_empty_roles_denied if {
	not workflow_node_access.allow with input as {
		"subject_roles": [],
		"node_type": "condition",
	}
}

# ─── FederationAdmin bypass ──────────────────────────────────────

test_federation_admin_standard if {
	workflow_node_access.allow with input as {
		"subject_roles": ["FederationAdmin"],
		"node_type": "delay",
	}
}

test_federation_admin_elevated if {
	workflow_node_access.allow with input as {
		"subject_roles": ["FederationAdmin"],
		"node_type": "llm",
	}
}

# ─── Unknown node type ───────────────────────────────────────────

test_unknown_node_type_denied if {
	not workflow_node_access.allow with input as {
		"subject_roles": ["WorkflowAdmin"],
		"node_type": "teleport",
	}
}

# ─── Deny reasons ────────────────────────────────────────────────

test_deny_reasons_elevated_node if {
	reasons := workflow_node_access.deny_reasons with input as {
		"subject_roles": ["WorkflowDesigner"],
		"node_type": "llm",
	}
	count(reasons) > 0
}

test_deny_reasons_standard_node if {
	reasons := workflow_node_access.deny_reasons with input as {
		"subject_roles": ["WorkflowExecutor"],
		"node_type": "delay",
	}
	count(reasons) > 0
}

test_deny_reasons_unknown_node if {
	reasons := workflow_node_access.deny_reasons with input as {
		"subject_roles": ["WorkflowAdmin"],
		"node_type": "teleport",
	}
	count(reasons) > 0
}

test_deny_reasons_empty_when_allowed if {
	reasons := workflow_node_access.deny_reasons with input as {
		"subject_roles": ["WorkflowAdmin"],
		"node_type": "llm",
	}
	count(reasons) == 0
}
