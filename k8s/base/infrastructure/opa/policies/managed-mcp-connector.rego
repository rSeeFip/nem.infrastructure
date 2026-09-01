package nem.mcp.controlplane.managed_mcp_connector

import rego.v1

default allow := false

uuid_pattern := "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
zero_uuid := "00000000-0000-0000-0000-000000000000"

connector_actions := {
    "managed-mcp:create",
    "managed-mcp:revise",
}

lifecycle_actions := {
    "managed-mcp:approve",
    "managed-mcp:publish",
    "managed-mcp:suspend",
    "managed-mcp:revoke",
}

allow if {
    object.get(input, "isFederationAdmin", false) == true
    valid_uuid(object.get(input, "actorId", ""))
    valid_uuid(object.get(input, "tenantId", ""))
    valid_uuid(object.get(input, "workspaceId", ""))
    valid_uuid(object.get(input, "connectorId", ""))
    action := object.get(input, "action", "")
    valid_action(action)
    revision_number := object.get(input, "revisionNumber", "__missing__")
    valid_revision(action, revision_number)
}

valid_uuid(value) if {
    is_string(value)
    value != zero_uuid
    regex.match(uuid_pattern, value)
}

valid_action(action) if {
    action in connector_actions
}

valid_action(action) if {
    action == "managed-mcp:read"
}

valid_action(action) if {
    action in lifecycle_actions
}

valid_revision(action, revision_number) if {
    action in connector_actions
    revision_number == null
}

valid_revision(action, revision_number) if {
    action == "managed-mcp:read"
    revision_number == null
}

valid_revision(action, revision_number) if {
    action == "managed-mcp:read"
    positive_integer(revision_number)
}

valid_revision(action, revision_number) if {
    action in lifecycle_actions
    positive_integer(revision_number)
}

positive_integer(value) if {
    is_number(value)
    value > 0
    floor(value) == value
}
