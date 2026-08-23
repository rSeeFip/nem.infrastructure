# Classification Policy for nem.* Ecosystem
# Package: nem.mcp.controlplane.classification
#
# Enforces data classification levels for external data flows.
# Default-deny for external destinations at Confidential+ level.
# Internal trust boundary (Wolverine bus) is NOT gated.

package nem.mcp.controlplane.classification

import rego.v1

# Final decisions must always be explicit for OPA API consumers.
default allow := false

# Default: deny external data flow.
default allow_external := false

# Default: allow internal data flow (bus = internal trust boundary).
default allow_internal := true

# Classification levels (numeric).
classification_levels := {
    "Public": 0,
    "Internal": 1,
    "Confidential": 2,
    "Restricted": 3,
    "Secret": 4,
}

# Public and Internal data can flow externally.
allow_external if {
    level := classification_levels[input.classification_level]
    level < classification_levels["Confidential"]
}

# A tenant maximum is optional; missing configuration preserves the base policy.
tenant_max_present if {
    object.keys(input)[_] == "tenant_max_external_level"
}

tenant_max_valid if {
    tenant_max_present
    classification_levels[input.tenant_max_external_level]
}

tenant_max_within_system_limit if {
    tenant_max_valid
    tenant_max := classification_levels[input.tenant_max_external_level]
    tenant_max <= classification_levels["Internal"]
}

# An external flow meets the tenant policy when no tenant maximum was supplied,
# or when the value is known, no looser than the system limit, and permits data.
tenant_allows_external if {
    not tenant_max_present
}

tenant_allows_external if {
    tenant_max_within_system_limit
    data_level := classification_levels[input.classification_level]
    tenant_max := classification_levels[input.tenant_max_external_level]
    data_level <= tenant_max
}

# PII strict gating: block external even for Internal when pii_gating_strict is true.
deny_external_pii if {
    input.has_pii == true
    input.pii_gating_strict == true
    input.destination_type == "external"
}

# Final decision combining all rules.
allow if {
    input.destination_type == "internal"
    allow_internal
}

allow if {
    input.destination_type == "external"
    allow_external
    tenant_allows_external
    not deny_external_pii
}

# Reason for denial (for audit trail).
deny_reasons contains reason if {
    input.destination_type == "external"
    not allow_external
    reason := sprintf("Classification level %s is too high for external flow", [input.classification_level])
}

deny_reasons contains reason if {
    input.destination_type == "external"
    tenant_max_present
    tenant_max_valid
    data_level := classification_levels[input.classification_level]
    tenant_max := classification_levels[input.tenant_max_external_level]
    data_level > tenant_max
    reason := sprintf("Classification level %s exceeds tenant maximum external level %s", [input.classification_level, input.tenant_max_external_level])
}

deny_reasons contains reason if {
    input.destination_type == "external"
    tenant_max_present
    not tenant_max_valid
    reason := sprintf("Invalid tenant maximum external level: %v", [input.tenant_max_external_level])
}

deny_reasons contains reason if {
    input.destination_type == "external"
    tenant_max_valid
    not tenant_max_within_system_limit
    reason := sprintf("Tenant maximum external level %s exceeds system maximum Internal", [input.tenant_max_external_level])
}

deny_reasons contains reason if {
    deny_external_pii
    reason := "PII detected with strict gating enabled"
}
