package nem.mcp.controlplane.skill_publisher

default allow := false

# ─── Ownership helper ─────────────────────────────────────────────
# Publishers may only act on their own skills.
is_owner if {
	input.user.publisher_id == input.resource_attributes.publisher_id
}

# ─── Submission rate limit helper ─────────────────────────────────
submission_within_rate_limit if {
	input.resource_attributes.submissions_today < input.resource_attributes.max_submissions_per_day
}

# ─── Suspension helper ────────────────────────────────────────────
publisher_active if {
	input.user.publisher_status != "Suspended"
}

# ─── Owner-only operations ────────────────────────────────────────
# Publisher can update their own skills.
allow if {
	input.operation_class == "skills.update"
	is_owner
}

# Publisher can deprecate their own skills.
allow if {
	input.operation_class == "skills.deprecate"
	is_owner
}

# Publisher can withdraw their own skills.
allow if {
	input.operation_class == "skills.withdraw"
	is_owner
}

# Publisher can submit own skills if active and within quota.
allow if {
	input.operation_class == "skills.submit"
	is_owner
	publisher_active
	submission_within_rate_limit
}
