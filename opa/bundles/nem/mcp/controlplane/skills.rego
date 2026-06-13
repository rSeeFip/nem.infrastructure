package nem.mcp.controlplane.skills

default allow := false

# ─── Skill browsing ───────────────────────────────────────────────
# Marketplace browsing is available to all users.
allow if {
	input.operation_class == "skills.browse"
}

# ─── Skill execution ──────────────────────────────────────────────
# Execution requires SkillExecutor role and published status.
allow if {
	input.operation_class == "skills.execute"
	input.resource_attributes.status == "Published"
	"SkillExecutor" in input.user.roles
}

# ─── Skill submission ─────────────────────────────────────────────
# Submission requires SkillPublisher role and verified publisher.
allow if {
	input.operation_class == "skills.submit"
	input.resource_attributes.publisher_verification == "Verified"
	"SkillPublisher" in input.user.roles
}

# ─── Skill review ─────────────────────────────────────────────────
# Review workflow access is restricted to SkillReviewer role.
allow if {
	input.operation_class == "skills.review"
	"SkillReviewer" in input.user.roles
}

# ─── Skill administration ─────────────────────────────────────────
# Administrative actions are restricted to SkillAdmin role.
allow if {
	input.operation_class == "skills.admin"
	"SkillAdmin" in input.user.roles
}
