package nem.mcp.controlplane.persona_access

default allow := false

default persona_level := 0

persona_level := 4 if {
	input.user.roles[_] == "nem:developer"
}

persona_level := 3 if {
	input.user.roles[_] == "nem:admin"
}

persona_level := 2 if {
	input.user.roles[_] == "nem:knowledge-worker"
}

persona_level := 1 if {
	input.user.roles[_] == "nem:power-user"
}

persona_level := 0 if {
	input.user.roles[_] == "nem:end-user"
}

required_level := 0 if {
	not input.required_persona
}

required_level := 4 if {
	input.required_persona == "Developer"
}

required_level := 3 if {
	input.required_persona == "AdminOps"
}

required_level := 2 if {
	input.required_persona == "KnowledgeWorker"
}

required_level := 1 if {
	input.required_persona == "PowerUser"
}

required_level := 0 if {
	input.required_persona == "EndUser"
}

allow if {
	input.user.roles[_] == "FederationAdmin"
}

allow if {
	persona_level >= required_level
}
