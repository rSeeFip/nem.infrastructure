package nem.agentic_test

import rego.v1
import data.nem.agentic

workflow_input := {
    "agent_id": "11111111-1111-1111-1111-111111111111",
    "tenant_id": "22222222-2222-2222-2222-222222222222",
    "action_type": "managed.44444444-4444-4444-4444-444444444444.get_scene_info",
    "payload_hash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "permissions": [],
    "trusted_workflow": {
        "dispatch_id": "11111111-1111-1111-1111-111111111111",
        "expires_at_utc": "2099-01-01T00:00:00+00:00",
        "tenant_id": "22222222-2222-2222-2222-222222222222",
        "instance_id": "33333333-3333-3333-3333-333333333333",
        "actor_id": "55555555-5555-5555-5555-555555555555",
        "workflow_id": "66666666-6666-6666-6666-666666666666",
        "workflow_run_id": "77777777-7777-7777-7777-777777777777",
        "workflow_version_id": "88888888-8888-8888-8888-888888888888",
        "workflow_step_id": "99999999-9999-9999-9999-999999999999",
        "workflow_version_content_hash": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        "workflow_version_snapshot_reference": "workflow-snapshot:66666666",
        "workflow_step_definition_digest": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
        "action_alias": "managed.44444444-4444-4444-4444-444444444444.get_scene_info",
        "canonical_parameter_digest": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "authenticated": true,
        "receipt_claimed": true,
        "signed_dispatch_capability_verified": true,
        "managed_scope_instance_id": "33333333-3333-3333-3333-333333333333",
        "managed_scope_tenant_id": "22222222-2222-2222-2222-222222222222",
        "connector_id": "44444444-4444-4444-4444-444444444444",
        "upstream_tool_name": "get_scene_info",
        "input_schema_digest": "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
        "output_schema_digest": "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
        "tool_catalog_digest": "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
        "revision_digest": "1111111111111111111111111111111111111111111111111111111111111111",
        "effect_digest": "2222222222222222222222222222222222222222222222222222222222222222",
        "policy_reference": "mcp.default",
        "revision_number": 1,
        "publication_version": 1,
        "revocation_epoch": 0,
        "risk_level": "medium",
        "hitl_required": true,
    },
}

test_allows_verified_claimed_active_managed_workflow if {
    agentic.allow with input as workflow_input
}

test_denies_workflow_mismatches if {
    not agentic.allow with input as object.union(workflow_input, {"action_type": "managed.44444444-4444-4444-4444-444444444444.other"})
    not agentic.allow with input as object.union(workflow_input, {"payload_hash": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"})
    not agentic.allow with input as object.union(workflow_input, {"tenant_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"})
    not agentic.allow with input as object.union(workflow_input, {"trusted_workflow": object.union(workflow_input.trusted_workflow, {"signed_dispatch_capability_verified": false})})
    not agentic.allow with input as object.union(workflow_input, {"trusted_workflow": object.union(workflow_input.trusted_workflow, {"receipt_claimed": false})})
    not agentic.allow with input as object.union(workflow_input, {"trusted_workflow": object.union(workflow_input.trusted_workflow, {"workflow_step_definition_digest": "BAD"})})
    not agentic.allow with input as object.union(workflow_input, {"trusted_workflow": object.union(workflow_input.trusted_workflow, {"effect_digest": "BAD"})})
    not agentic.allow with input as object.union(workflow_input, {"trusted_workflow": object.union(workflow_input.trusted_workflow, {"policy_reference": "mcp.unknown"})})
    not agentic.allow with input as object.union(workflow_input, {"trusted_workflow": object.union(workflow_input.trusted_workflow, {"risk_level": "low"})})
    not agentic.allow with input as object.union(workflow_input, {"trusted_workflow": object.union(workflow_input.trusted_workflow, {"hitl_required": false})})
    not agentic.allow with input as object.union(workflow_input, {"trusted_workflow": object.union(workflow_input.trusted_workflow, {"expires_at_utc": "2020-01-01T00:00:00+00:00"})})
}

test_allows_homeassistant_list_entities if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "homeassistant.list-entities",
    }
}

test_allows_assetcore_search_with_assetcore_read_permission if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "assetcore.search",
        "permissions": ["assetcore.read"],
    }
}

test_denies_assetcore_search_without_assetcore_read_permission if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "assetcore.search",
        "permissions": [],
    }
}

test_denies_assetcore_search_with_generic_read_permission if {
    not agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "assetcore.search",
        "permissions": ["read"],
    }
}

test_assetcore_read_action_set_covers_provider_actions if {
    agentic.assetcore_read_actions == {
        "assetcore.assets.list",
        "assetcore.assets.get",
        "assetcore.search",
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
