package nem.federation.tests.channel_assistant_routing

import rego.v1

import data.nem.federation.services.channel_assistant_routing

# This is the exact shape currently emitted by
# OpaChannelAssistantRoutingPolicy in nem.Comms. Comms validates approval,
# expiry, sender trust, consent, and activation before OPA; those are not OPA
# input fields and are deliberately not asserted by these tests.
client_input(tenant_id, binding_tenant_id, binding_agent_id, ownership_tenant_id, ownership_agent_id, active, authority, revision, session_key) := {
    "tenant_id": tenant_id,
    "binding": {
        "tenant_id": binding_tenant_id,
        "agent_id": binding_agent_id,
        "session_scope": "peer",
    },
    "ownership": {
        "tenant_id": ownership_tenant_id,
        "agent_id": ownership_agent_id,
        "active": active,
        "revision": revision,
        "authority": authority,
    },
    "session_key": session_key,
}

valid_input := client_input(
    "tenant-a", "tenant-a", "agent-a", "tenant-a", "agent-a", true,
    "mcp-configuration", "revision-1", "tenant-a:agent-a:peer",
)

test_valid_active_owned_route_allows if {
    channel_assistant_routing.allow with input as valid_input
}

test_empty_input_denies if {
    not channel_assistant_routing.allow with input as {}
}

test_request_tenant_mismatch_denies if {
    not channel_assistant_routing.allow with input as client_input(
        "tenant-b", "tenant-a", "agent-a", "tenant-a", "agent-a", true,
        "mcp-configuration", "revision-1", "tenant-a:agent-a:peer",
    )
}

test_binding_ownership_tenant_mismatch_denies if {
    not channel_assistant_routing.allow with input as client_input(
        "tenant-a", "tenant-a", "agent-a", "tenant-b", "agent-a", true,
        "mcp-configuration", "revision-1", "tenant-a:agent-a:peer",
    )
}

test_agent_mismatch_denies if {
    not channel_assistant_routing.allow with input as client_input(
        "tenant-a", "tenant-a", "agent-a", "tenant-a", "agent-b", true,
        "mcp-configuration", "revision-1", "tenant-a:agent-a:peer",
    )
}

test_inactive_ownership_denies if {
    not channel_assistant_routing.allow with input as client_input(
        "tenant-a", "tenant-a", "agent-a", "tenant-a", "agent-a", false,
        "mcp-configuration", "revision-1", "tenant-a:agent-a:peer",
    )
}

test_wrong_authority_denies if {
    not channel_assistant_routing.allow with input as client_input(
        "tenant-a", "tenant-a", "agent-a", "tenant-a", "agent-a", true,
        "other-configuration", "revision-1", "tenant-a:agent-a:peer",
    )
}

test_missing_required_field_denies if {
    not channel_assistant_routing.allow with input as {
        "tenant_id": "tenant-a",
        "binding": {"tenant_id": "tenant-a", "agent_id": "agent-a", "session_scope": "peer"},
        "session_key": "tenant-a:agent-a:peer",
    }
}

test_blank_revision_denies if {
    not channel_assistant_routing.allow with input as client_input(
        "tenant-a", "tenant-a", "agent-a", "tenant-a", "agent-a", true,
        "mcp-configuration", " ", "tenant-a:agent-a:peer",
    )
}

test_blank_session_key_denies if {
    not channel_assistant_routing.allow with input as client_input(
        "tenant-a", "tenant-a", "agent-a", "tenant-a", "agent-a", true,
        "mcp-configuration", "revision-1", " ",
    )
}
