# AgenticGateway dispatch policy.
# The API authenticates callers; this policy limits agent dispatches to explicitly
# approved read-only actions. Mutating actions remain denied by default.
package nem.agentic

import rego.v1

default allow := false

read_only_actions := {
    "platform.get_schema",
    "platform.get_domain_schema",
    "homeassistant.list-entities",
    "skills.list",
    "skills.search",
}

allow if {
    object.get(input, "agent_id", "") != ""
    input.action_type in read_only_actions
}
