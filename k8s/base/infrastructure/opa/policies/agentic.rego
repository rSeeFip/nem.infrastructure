# AgenticGateway dispatch policy.
# The API authenticates callers and reconstructs trusted permissions from JWT claims.
# This policy limits agent dispatches to explicitly approved actions and permissions.
package nem.agentic

import rego.v1

default allow := false

sha256_pattern := "^[a-f0-9]{64}$"
uuid_pattern := "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
known_managed_policy_references := {"mcp.default", "mcp.restricted"}

read_only_actions := {
    "platform.get_schema",
    "platform.get_domain_schema",
    "homeassistant.list-entities",
    "sentinel.services.list",
    "sentinel.service.health",
    "sentinel.alerts.recent",
    "sentinel.metrics.query",
    "sentinel.playbooks.list",
}

assetcore_read_actions := {
    "assetcore.assets.list",
    "assetcore.assets.get",
    "assetcore.search",
}

lume_read_actions := {
    "lume.sprints.list",
    "lume.sprints.get",
    "lume.epics.list",
    "lume.epics.get",
    "lume.tasks.list",
    "lume.tasks.get",
    "lume.boards.list",
    "lume.boards.get",
    "lume.projects.list",
    "lume.projects.get",
    "lume.milestones.list",
}

lume_write_actions := {
    "lume.sprints.create",
    "lume.sprints.start",
    "lume.sprints.complete",
    "lume.sprints.add_task",
    "lume.sprints.remove_task",
    "lume.epics.create",
    "lume.epics.update_status",
    "lume.epics.link_task",
    "lume.tasks.create",
    "lume.tasks.update_status",
    "lume.tasks.assign",
    "lume.tasks.add_comment",
    "lume.tasks.log_time",
    "lume.projects.create",
    "lume.milestones.create",
}

profitcenter_actions := {
    "profitcenter.list-cost-centers",
    "profitcenter.get-cost-center",
    "profitcenter.list-budgets",
    "profitcenter.get-budget",
    "profitcenter.list-allocations",
    "profitcenter.get-allocation",
    "profitcenter.list-chargebacks",
    "profitcenter.get-chargeback",
    "profitcenter.query-costs",
    "profitcenter.get-finance-view",
}

skills_read_actions := {
    "skills.list",
    "skills.search",
    "skills.get",
}

skills_execute_actions := {
    "skills.invoke",
}

skills_improve_actions := {
    "skills.improve",
    "skills.improvement.get",
}

allow if {
    object.get(input, "agent_id", "") != ""
    input.action_type in read_only_actions
}

# Trusted workflow facts are minted only after signature validation and durable receipt claim.
# The gateway resolves the managed descriptor from its active V2 registry before sending them.
allow if {
    workflow := object.get(input, "trusted_workflow", null)
    workflow != null
    workflow.authenticated == true
    workflow.receipt_claimed == true
    workflow.signed_dispatch_capability_verified == true
    workflow.hitl_required == true
    workflow.risk_level == "medium"
    input.action_type == workflow.action_alias
    input.payload_hash == workflow.canonical_parameter_digest
    input.tenant_id == workflow.tenant_id
    workflow.managed_scope_instance_id == workflow.instance_id
    workflow.managed_scope_tenant_id == workflow.tenant_id
    valid_workflow_provenance(workflow)
    valid_managed_descriptor(workflow)
    expires_at := time.parse_rfc3339_ns(workflow.expires_at_utc)
    time.now_ns() < expires_at
}

valid_workflow_provenance(workflow) if {
    valid_uuid(workflow.dispatch_id)
    valid_uuid(workflow.tenant_id)
    valid_uuid(workflow.instance_id)
    valid_uuid(workflow.actor_id)
    valid_uuid(workflow.workflow_id)
    valid_uuid(workflow.workflow_run_id)
    valid_uuid(workflow.workflow_version_id)
    valid_uuid(workflow.workflow_step_id)
    nonempty(workflow.workflow_version_snapshot_reference)
    nonempty(workflow.action_alias)
    regex.match(sha256_pattern, workflow.workflow_version_content_hash)
    regex.match(sha256_pattern, workflow.workflow_step_definition_digest)
    regex.match(sha256_pattern, workflow.canonical_parameter_digest)
}

valid_managed_descriptor(workflow) if {
    valid_uuid(workflow.managed_scope_instance_id)
    valid_uuid(workflow.managed_scope_tenant_id)
    valid_uuid(workflow.connector_id)
    nonempty(workflow.upstream_tool_name)
    workflow.revision_number > 0
    workflow.publication_version > 0
    workflow.revocation_epoch >= 0
    workflow.policy_reference in known_managed_policy_references
    regex.match(sha256_pattern, workflow.input_schema_digest)
    regex.match(sha256_pattern, workflow.output_schema_digest)
    regex.match(sha256_pattern, workflow.tool_catalog_digest)
    regex.match(sha256_pattern, workflow.revision_digest)
    regex.match(sha256_pattern, workflow.effect_digest)
}

valid_uuid(value) if {
    is_string(value)
    regex.match(uuid_pattern, value)
    value != "00000000-0000-0000-0000-000000000000"
}

nonempty(value) if {
    is_string(value)
    trim_space(value) != ""
}

allow if {
    object.get(input, "agent_id", "") != ""
    input.action_type in assetcore_read_actions
    "assetcore.read" in object.get(input, "permissions", [])
}

allow if {
    object.get(input, "agent_id", "") != ""
    input.action_type in lume_read_actions
    "lume.read" in object.get(input, "permissions", [])
}

allow if {
    object.get(input, "agent_id", "") != ""
    input.action_type in lume_write_actions
    "lume.write" in object.get(input, "permissions", [])
}

allow if {
    object.get(input, "agent_id", "") != ""
    input.action_type in profitcenter_actions
    "finance.read" in object.get(input, "permissions", [])
}

allow if {
    object.get(input, "agent_id", "") != ""
    input.action_type in skills_read_actions
    "skills.read" in object.get(input, "permissions", [])
}

allow if {
    object.get(input, "agent_id", "") != ""
    input.action_type in skills_execute_actions
    "skills.execute" in object.get(input, "permissions", [])
}

allow if {
    object.get(input, "agent_id", "") != ""
    input.action_type in skills_improve_actions
    "skills.improve" in object.get(input, "permissions", [])
}
