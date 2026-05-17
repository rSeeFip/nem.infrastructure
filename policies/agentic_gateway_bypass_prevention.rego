package nem.federation.agentic_gateway_bypass_prevention

default allow := false

allow if {
	is_human_request
}

allow if {
	is_agent_request
	gateway_dispatch_header_present
}

is_agent_request if {
	lower(input.auth.caller_type) == "agent"
}

is_human_request if {
	input.auth.authenticated == true
	lower(input.auth.caller_type) == "human"
}

gateway_dispatch_header_present if {
	value := input.request.headers["x-gateway-dispatch-id"]
	value != ""
}
