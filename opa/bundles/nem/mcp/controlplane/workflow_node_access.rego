# Workflow Node Access Policy for nem.Workflow
# Package: nem.mcp.controlplane.workflow_node_access
#
# Controls access to specific workflow node types.
# Some node types (e.g., LLM, external API, shell) require elevated roles.
# Standard nodes (delay, condition, log) are available to all designers.

package nem.mcp.controlplane.workflow_node_access

import rego.v1

default allow := false

# ─── Node type classification ────────────────────────────────────
# Standard nodes: available to any designer/admin
standard_node_types := {
	"delay", "condition", "log", "transform",
	"branch", "merge", "loop", "variable",
	"suspend", "terminate",
}

# Elevated nodes: require WorkflowAdmin or explicit elevated access
elevated_node_types := {
	"llm", "external_api", "shell_command",
	"database_query", "file_system", "webhook_call",
}

# ─── Standard nodes: any design-capable role ────────────────────
allow if {
	input.node_type in standard_node_types
	some role in input.subject_roles
	role in {"WorkflowDesigner", "WorkflowAdmin"}
}

# ─── Elevated nodes: WorkflowAdmin only ─────────────────────────
allow if {
	input.node_type in elevated_node_types
	some role in input.subject_roles
	role == "WorkflowAdmin"
}

# ─── FederationAdmin bypasses all checks ─────────────────────────
allow if {
	some role in input.subject_roles
	role == "FederationAdmin"
}

# ─── Deny reasons for audit trail ────────────────────────────────
deny_reasons contains reason if {
	input.node_type in elevated_node_types
	not allow
	reason := sprintf("Node type '%s' requires WorkflowAdmin role. Subject roles: %v", [input.node_type, input.subject_roles])
}

deny_reasons contains reason if {
	input.node_type in standard_node_types
	not allow
	reason := sprintf("Node type '%s' requires WorkflowDesigner or WorkflowAdmin role. Subject roles: %v", [input.node_type, input.subject_roles])
}

deny_reasons contains reason if {
	not input.node_type in standard_node_types
	not input.node_type in elevated_node_types
	reason := sprintf("Unknown node type '%s'", [input.node_type])
}
