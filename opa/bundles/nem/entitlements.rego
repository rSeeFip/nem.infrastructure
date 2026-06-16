# Module Entitlements Policy for nem.* Ecosystem
# Package: nem.entitlements
#
# Consumed by nem.Web's server-side entitlements BFF
# (apps/web/app/api/entitlements/route.ts -> packages/auth/src/opa/client.ts),
# which POSTs to OPA at /v1/data/nem/entitlements and reads `result.allow`
# and `result.modules`.
#
# INPUT CONTRACT (exactly what the BFF sends):
#   {
#     "input": {
#       "module": "<string>",                # e.g. "mimir", "knowhub"
#       "user": {
#         "sub": "<string>",
#         "roles": ["..."],                  # realm + nem-web client roles
#         "permissions": ["module:<name>:<action>", ...]
#       }
#     }
#   }
#
# OUTPUT CONTRACT (what the client reads):
#   result.allow   : boolean   -> data.nem.entitlements.allow
#   result.modules : string[]  -> data.nem.entitlements.modules
#
# Authentication (valid JWT) is already enforced by the BFF before OPA is
# called; this policy performs authorization only.

package nem.entitlements

import rego.v1

# Deny by default.
default allow := false

# Roles that grant unrestricted access to every module.
admin_roles := {"admin", "FederationAdmin"}

# Canonical set of modules in the nem.* ecosystem. Mirrors nem.Web
# SERVICES_CONFIG / apps so an admin's `modules` list reflects the full shell.
all_modules := {
	"assetcore",
	"cognition",
	"decisions",
	"holisticworld",
	"homeassistant",
	"knowhub",
	"lume",
	"mcp",
	"mediahub",
	"mimir",
	"profit-center",
	"scheduler",
	"workflow",
}

user_roles := object.get(input, ["user", "roles"], [])

user_permissions := object.get(input, ["user", "permissions"], [])

# True when the caller holds any administrative role.
is_admin if {
	some role in user_roles
	role in admin_roles
}

# A user is entitled to a specific module when they hold a matching
# `module:<name>:<action>` permission (any action, including "*").
module_permitted(module) if {
	some perm in user_permissions
	parts := split(perm, ":")
	parts[0] == "module"
	parts[1] == module
}

# ----------------------------------------------------------------------------
# allow
# ----------------------------------------------------------------------------

# Admins may access any requested module.
allow if {
	is_admin
}

# Non-admins may access a module they have an explicit permission for.
allow if {
	not is_admin
	module_permitted(input.module)
}

# ----------------------------------------------------------------------------
# modules — the set of modules the caller may see in the shell navigation.
# Returned as a JSON array (string[]) to satisfy the BFF `modules` contract.
# ----------------------------------------------------------------------------

# Admins see every module.
modules := sort([m | some m in all_modules]) if {
	is_admin
}

# Non-admins see exactly the modules they have a permission for.
modules := sort([m | some m in all_modules; module_permitted(m)]) if {
	not is_admin
}
