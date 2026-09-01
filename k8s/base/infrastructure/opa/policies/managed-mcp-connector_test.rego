package nem.mcp.controlplane.managed_mcp_connector_test

import rego.v1
import data.nem.mcp.controlplane.managed_mcp_connector

actor_id := "11111111-1111-1111-1111-111111111111"
tenant_id := "22222222-2222-2222-2222-222222222222"
workspace_id := "33333333-3333-3333-3333-333333333333"
connector_id := "44444444-4444-4444-4444-444444444444"

valid_input(action, revision_number) := {
    "actorId": actor_id,
    "tenantId": tenant_id,
    "workspaceId": workspace_id,
    "isFederationAdmin": true,
    "action": action,
    "connectorId": connector_id,
    "revisionNumber": revision_number,
}

test_allows_connector_actions_with_null_revision if {
    managed_mcp_connector.allow with input as valid_input("managed-mcp:create", null)
    managed_mcp_connector.allow with input as valid_input("managed-mcp:revise", null)
}

test_allows_runtime_and_revision_reads if {
    managed_mcp_connector.allow with input as valid_input("managed-mcp:read", null)
    managed_mcp_connector.allow with input as valid_input("managed-mcp:read", 1)
}

test_allows_all_lifecycle_actions_with_positive_revision if {
    managed_mcp_connector.allow with input as valid_input("managed-mcp:approve", 1)
    managed_mcp_connector.allow with input as valid_input("managed-mcp:publish", 1)
    managed_mcp_connector.allow with input as valid_input("managed-mcp:suspend", 1)
    managed_mcp_connector.allow with input as valid_input("managed-mcp:revoke", 1)
}

test_denies_missing_or_false_federation_admin if {
    not managed_mcp_connector.allow with input as object.remove(valid_input("managed-mcp:create", null), ["isFederationAdmin"])
    not managed_mcp_connector.allow with input as object.union(valid_input("managed-mcp:create", null), {"isFederationAdmin": false})
}

test_denies_unknown_action if {
    not managed_mcp_connector.allow with input as valid_input("managed-mcp:delete", null)
}

test_denies_malformed_and_noncanonical_ids if {
    not managed_mcp_connector.allow with input as object.union(valid_input("managed-mcp:create", null), {"actorId": "not-a-uuid"})
    not managed_mcp_connector.allow with input as object.union(valid_input("managed-mcp:create", null), {"tenantId": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"})
    not managed_mcp_connector.allow with input as object.union(valid_input("managed-mcp:create", null), {"workspaceId": "not-a-uuid"})
    not managed_mcp_connector.allow with input as object.union(valid_input("managed-mcp:create", null), {"connectorId": "44444444-4444-4444-4444-44444444444Z"})
}

test_denies_all_zero_ids if {
    not managed_mcp_connector.allow with input as object.union(valid_input("managed-mcp:create", null), {"actorId": "00000000-0000-0000-0000-000000000000"})
    not managed_mcp_connector.allow with input as object.union(valid_input("managed-mcp:create", null), {"tenantId": "00000000-0000-0000-0000-000000000000"})
    not managed_mcp_connector.allow with input as object.union(valid_input("managed-mcp:create", null), {"workspaceId": "00000000-0000-0000-0000-000000000000"})
    not managed_mcp_connector.allow with input as object.union(valid_input("managed-mcp:create", null), {"connectorId": "00000000-0000-0000-0000-000000000000"})
}

test_denies_lifecycle_actions_without_positive_revision if {
    not managed_mcp_connector.allow with input as valid_input("managed-mcp:approve", null)
    not managed_mcp_connector.allow with input as valid_input("managed-mcp:publish", 0)
    not managed_mcp_connector.allow with input as valid_input("managed-mcp:suspend", -1)
    not managed_mcp_connector.allow with input as valid_input("managed-mcp:revoke", "1")
}

test_denies_connector_actions_with_revision if {
    not managed_mcp_connector.allow with input as valid_input("managed-mcp:create", 1)
    not managed_mcp_connector.allow with input as valid_input("managed-mcp:revise", 1)
}

test_denies_nonpositive_or_string_revision_reads if {
    not managed_mcp_connector.allow with input as valid_input("managed-mcp:read", "1")
    not managed_mcp_connector.allow with input as valid_input("managed-mcp:read", 0)
    not managed_mcp_connector.allow with input as valid_input("managed-mcp:read", -1)
}
