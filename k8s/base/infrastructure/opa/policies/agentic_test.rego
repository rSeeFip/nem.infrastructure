package nem.agentic_test

import rego.v1
import data.nem.agentic

test_allows_homeassistant_list_entities if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "homeassistant.list-entities",
    }
}

test_allows_skills_search_with_skills_read_permission if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.search",
        "permissions": ["skills.read"],
    }
}

test_denies_skills_search_without_skills_read_permission if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.search",
        "permissions": [],
    }
}

test_denies_skills_search_with_generic_read_permission if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.search",
        "permissions": ["read"],
    }
}

test_allows_skills_get_with_skills_read_permission if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.get",
        "permissions": ["skills.read"],
    }
}

test_allows_skills_invoke_with_skills_execute_permission if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.invoke",
        "permissions": ["skills.execute"],
    }
}

test_allows_skills_improve_with_skills_improve_permission if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.improve",
        "permissions": ["skills.improve"],
    }
}

test_allows_skills_improvement_get_with_skills_improve_permission if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.improvement.get",
        "permissions": ["skills.improve"],
    }
}

test_denies_skills_get_without_skills_read_permission if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.get",
        "permissions": [],
    }
}

test_denies_skills_invoke_with_only_skills_read_permission if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.invoke",
        "permissions": ["skills.read"],
    }
}

test_denies_skills_invoke_missing_agent_id if {
    not agentic.allow with input as {
        "action_type": "skills.invoke",
        "permissions": ["skills.execute"],
    }
}

test_denies_skills_improve_with_only_skills_read_permission if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.improve",
        "permissions": ["skills.read"],
    }
}

test_denies_skills_improve_with_only_skills_execute_permission if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.improve",
        "permissions": ["skills.execute"],
    }
}

test_denies_skills_improvement_get_with_only_skills_read_permission if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.improvement.get",
        "permissions": ["skills.read"],
    }
}

test_denies_skills_improve_missing_agent_id if {
    not agentic.allow with input as {
        "action_type": "skills.improve",
        "permissions": ["skills.improve"],
    }
}

test_denies_deprecated_skills_execute if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.execute",
        "permissions": ["skills.execute"],
    }
}

test_allows_platform_schema_reads if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "platform.get_schema",
    }

    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "platform.get_domain_schema",
    }
}

test_allows_sentinel_reads if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "sentinel.services.list",
    }

    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "sentinel.service.health",
    }

    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "sentinel.alerts.recent",
    }

    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "sentinel.metrics.query",
    }

    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "sentinel.playbooks.list",
    }
}

test_denies_mutating_sentinel_action if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "sentinel.chaos.run",
    }
}

test_denies_mutating_homeassistant_action if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "homeassistant.call-service",
    }
}

test_denies_missing_agent_id if {
    not agentic.allow with input as {
        "action_type": "homeassistant.list-entities",
    }
}

test_denies_unknown_action if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "unknown.action",
    }
}

test_lume_action_sets_cover_all_provider_actions if {
    agentic.lume_read_actions == {
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

    agentic.lume_write_actions == {
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
}

test_profitcenter_action_set_covers_all_provider_actions if {
    agentic.profitcenter_actions == {
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
}

test_skills_action_sets_cover_provider_actions if {
    agentic.skills_read_actions == {
        "skills.list",
        "skills.search",
        "skills.get",
    }

    agentic.skills_execute_actions == {
        "skills.invoke",
    }

    agentic.skills_improve_actions == {
        "skills.improve",
        "skills.improvement.get",
    }

    count(agentic.skills_read_actions) + count(agentic.skills_execute_actions) + count(agentic.skills_improve_actions) == 6
}

test_allows_lume_read_with_read_permission if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "lume.projects.list",
        "permissions": ["lume.read"],
    }
}

test_allows_lume_write_with_write_permission if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "lume.tasks.create",
        "permissions": ["lume.write"],
    }
}

test_denies_lume_action_without_permission if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "lume.projects.list",
        "permissions": [],
    }
}

test_denies_lume_write_with_only_read_permission if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "lume.tasks.create",
        "permissions": ["lume.read"],
    }
}

test_allows_profitcenter_action_with_finance_read_permission if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "profitcenter.list-cost-centers",
        "permissions": ["finance.read"],
    }
}

test_denies_profitcenter_action_without_permission if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "profitcenter.list-cost-centers",
        "permissions": [],
    }
}

test_denies_profitcenter_action_with_unrelated_permission if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "profitcenter.list-cost-centers",
        "permissions": ["lume.read"],
    }
}

test_denies_profitcenter_action_missing_agent_id if {
    not agentic.allow with input as {
        "action_type": "profitcenter.list-cost-centers",
        "permissions": ["finance.read"],
    }
}
