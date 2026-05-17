package nem.federation.tests.bypass_prevention

import data.nem.federation.agentic_gateway_bypass_prevention as bypass

test_agent_direct_call_denied if {
	not bypass.allow with input as data.bypass_prevention["agent-direct-call"]
}

test_agent_via_gateway_allowed if {
	bypass.allow with input as data.bypass_prevention["agent-via-gateway"]
}

test_human_direct_allowed if {
	bypass.allow with input as data.bypass_prevention["human-direct"]
}
