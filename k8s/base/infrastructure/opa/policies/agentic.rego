# AgenticGateway dispatch policy.
# The API authenticates callers and reconstructs trusted permissions from JWT claims.
# This policy limits agent dispatches to explicitly approved actions and permissions.
package nem.agentic

import rego.v1

default allow := false

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
