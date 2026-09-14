package nem.federation.services.channel_assistant_routing

import rego.v1

# Comms validates expiry, a unique approved ownership snapshot, native-group
# mention activation, and ISenderTrustGate before this decision. OPA only
# validates the tenant-owned active-agent tuple in the emitted input; it does
# not enforce fields Comms does not send. Mimir revalidates its local owner and
# enabled state before execution.
default allow := false

allow if {
    nonblank_string(input.tenant_id)
    nonblank_string(input.binding.tenant_id)
    nonblank_string(input.ownership.tenant_id)
    input.tenant_id == input.binding.tenant_id
    input.binding.tenant_id == input.ownership.tenant_id

    nonblank_string(input.binding.agent_id)
    nonblank_string(input.ownership.agent_id)
    input.binding.agent_id == input.ownership.agent_id

    input.ownership.active == true
    input.ownership.authority == "mcp-configuration"
    nonblank_string(input.ownership.revision)
    nonblank_string(input.session_key)
}

nonblank_string(value) if {
    is_string(value)
    trim(value) != ""
}
