package nem.mcp.controlplane.plugin_control

default allow := false

# ─── Clearance hierarchy ────────────────────────────────────────
# Higher numeric clearance implies access to lower operation classes.
# Map clearance names to numeric levels for comparison.
clearance_level["Public"] := 0
clearance_level["Internal"] := 1
clearance_level["Confidential"] := 2
clearance_level["Restricted"] := 3
clearance_level["Secret"] := 4

# ─── Operation class → minimum clearance required ──────────────
min_clearance["plugin.read"] := 0        # Public
min_clearance["plugin.create"] := 1      # Internal
min_clearance["plugin.update"] := 1      # Internal
min_clearance["plugin.delete"] := 2      # Confidential
min_clearance["plugin.activate"] := 1    # Internal
min_clearance["plugin.deactivate"] := 2  # Confidential
min_clearance["config.read"] := 0        # Public
min_clearance["config.create"] := 1      # Internal
min_clearance["config.update"] := 1      # Internal
min_clearance["config.delete"] := 2      # Confidential

# ─── Allow rule ─────────────────────────────────────────────────
# Grant access when the subject's clearance level meets or exceeds
# the minimum required for the requested operation class.
allow if {
	op := input.operation_class
	sc := input.subject_clearance

	min_clearance[op] != null
	clearance_level[sc] != null

	clearance_level[sc] >= min_clearance[op]
}

# ─── Fallback: FederationAdmin role bypasses clearance checks ───
allow if {
	input.user.roles[_] == "FederationAdmin"
}
