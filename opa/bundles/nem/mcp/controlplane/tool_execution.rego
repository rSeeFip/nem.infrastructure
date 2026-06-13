package nem.mcp.controlplane.tool_execution

default allow := false

# ─── Rate limit bounds ──────────────────────────────────────────
# Each tool may define its own maximum calls per minute.
# The engine supplies current_calls_in_window in the input.

default max_calls_per_minute := 60

max_calls_per_minute := input.policy.max_calls_per_minute {
	input.policy.max_calls_per_minute > 0
}

# ─── Concurrency bounds ────────────────────────────────────────
# Maximum simultaneous in-flight tool executions.

default max_concurrent := 10

max_concurrent := input.policy.max_concurrent {
	input.policy.max_concurrent > 0
}

# ─── Payload size bounds ───────────────────────────────────────
# Maximum input payload size in bytes (0 = unlimited).

default max_payload_bytes := 0

max_payload_bytes := input.policy.max_payload_bytes {
	input.policy.max_payload_bytes > 0
}

# ─── Allow rule ─────────────────────────────────────────────────
# Grant execution when all resource bounds are satisfied.
allow if {
	# Rate limit check
	input.current_calls_in_window < max_calls_per_minute

	# Concurrency check
	input.current_concurrent < max_concurrent

	# Payload size check (0 = unlimited, skip check)
	payload_within_bounds
}

# ─── Payload bounds helper ──────────────────────────────────────
payload_within_bounds if {
	max_payload_bytes == 0
}

payload_within_bounds if {
	max_payload_bytes > 0
	input.payload_size_bytes <= max_payload_bytes
}

# ─── FederationAdmin bypass ─────────────────────────────────────
# FederationAdmin role bypasses all tool execution limits.
allow if {
	input.user.roles[_] == "FederationAdmin"
}

# ─── Violations ─────────────────────────────────────────────────
# Collect human-readable violation reasons for diagnostics.
violations[msg] {
	input.current_calls_in_window >= max_calls_per_minute
	msg := sprintf("Rate limit exceeded: %d/%d calls per minute", [input.current_calls_in_window, max_calls_per_minute])
}

violations[msg] {
	input.current_concurrent >= max_concurrent
	msg := sprintf("Concurrency limit exceeded: %d/%d concurrent executions", [input.current_concurrent, max_concurrent])
}

violations[msg] {
	max_payload_bytes > 0
	input.payload_size_bytes > max_payload_bytes
	msg := sprintf("Payload size exceeded: %d/%d bytes", [input.payload_size_bytes, max_payload_bytes])
}
