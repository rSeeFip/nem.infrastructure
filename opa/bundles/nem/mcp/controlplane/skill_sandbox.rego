package nem.mcp.controlplane.skill_sandbox

default allow := false

# ─── Isolation policy helper ──────────────────────────────────────
# Untrusted skills must run in Firecracker isolation.
isolation_policy_satisfied if {
	input.resource_attributes.trust_level == "Untrusted"
	input.resource_attributes.isolation_level == "Firecracker"
}

# ─── Untrusted skill isolation gate ───────────────────────────────
# External publisher skills must run in gVisor or Firecracker.
isolation_policy_satisfied if {
	input.resource_attributes.trust_level != "Untrusted"
	input.resource_attributes.publisher_type == "External"
	input.resource_attributes.isolation_level == "gVisor"
}

isolation_policy_satisfied if {
	input.resource_attributes.trust_level != "Untrusted"
	input.resource_attributes.publisher_type == "External"
	input.resource_attributes.isolation_level == "Firecracker"
}

# ─── Internal skill isolation gate ────────────────────────────────
# Internal skills may run with no isolation.
isolation_policy_satisfied if {
	input.resource_attributes.trust_level == "Internal"
	input.resource_attributes.isolation_level == "None"
}

# ─── Allow rule ────────────────────────────────────────────────────
allow if {
	input.operation_class == "skills.execute"
	isolation_policy_satisfied
}
