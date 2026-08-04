package nem.assetcore.rbac

import rego.v1

default allow := false

allow if {
    has_role("assetcore:admin")
}

allow if {
    is_platform_admin
    is_equipment_path
    is_write_method
}

is_platform_admin if {
    has_role("admin")
}

is_platform_admin if {
    has_role("FederationAdmin")
}

is_equipment_path if {
    path := object.get(input, "path", "")
    startswith(path, "/api/v1/equipment")
}

is_write_method if {
    method := upper(object.get(input, "method", ""))
    method in {"POST", "PUT", "DELETE"}
}

has_role(role) if {
    roles := object.get(input, "roles", [])
    role in roles
}
