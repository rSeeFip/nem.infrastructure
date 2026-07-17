package nem.agentic_test

import rego.v1
import data.nem.agentic

test_allows_homeassistant_list_entities if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "homeassistant.list-entities",
    }
}

test_allows_skills_search if {
    agentic.allow with input as {
        "agent_id": "11111111-1111-1111-1111-111111111111",
        "action_type": "skills.search",
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
