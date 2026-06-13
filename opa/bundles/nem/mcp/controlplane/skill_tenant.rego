package nem.mcp.controlplane.skill_tenant

default allow := false

# ─── Tenant helper ────────────────────────────────────────────────
same_tenant if {
	input.user.tenant_id == input.resource_attributes.tenant_id
}

# ─── Visibility helpers ───────────────────────────────────────────
is_internal if {
	input.resource_attributes.visibility == "internal"
}

is_shared if {
	input.resource_attributes.visibility == "shared"
}

is_marketplace if {
	input.resource_attributes.visibility == "marketplace"
}

# ─── Catalog visibility policy ────────────────────────────────────
# Internal skills are visible only within the owning tenant.
allow if {
	input.operation_class == "skills.browse"
	is_internal
	same_tenant
}

# Shared skills are visible to all tenants.
allow if {
	input.operation_class == "skills.browse"
	is_shared
}

# Marketplace skills are visible to all tenants.
allow if {
	input.operation_class == "skills.browse"
	is_marketplace
}

# Tenant-isolated operations must stay within tenant boundary.
allow if {
	input.operation_class == "skills.read"
	same_tenant
}

allow if {
	input.operation_class == "skills.execute"
	same_tenant
}

allow if {
	input.operation_class == "skills.update"
	same_tenant
}

allow if {
	input.operation_class == "skills.submit"
	same_tenant
}
