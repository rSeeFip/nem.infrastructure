# Classification Policy for nem.* Ecosystem
# Package: nem.mcp.controlplane.classification
#
# Enforces data classification levels for external data flows.
# Default-deny for external destinations at Confidential+ level.
# Internal trust boundary (Wolverine bus) is NOT gated.

package nem.mcp.controlplane.classification

import rego.v1

# Default: deny external data flow
default allow_external := false

# Default: allow internal data flow (bus = internal trust boundary)
default allow_internal := true

# Classification levels (numeric)
classification_levels := {
    "Public": 0,
    "Internal": 1,
    "Confidential": 2,
    "Restricted": 3,
    "Secret": 4,
}

# Public and Internal data can flow externally
allow_external if {
    level := classification_levels[input.classification_level]
    level < 2  # Below Confidential
}

# PII strict gating: block external even for Internal when pii_gating_strict is true
deny_external_pii if {
    input.has_pii == true
    input.pii_gating_strict == true
    input.destination_type == "external"
}

# Override: tenant can set stricter policy (lower threshold)
# But can never set LOOSER policy than system default
allow_external_with_tenant_override if {
    tenant_max := classification_levels[input.tenant_max_external_level]
    data_level := classification_levels[input.classification_level]
    data_level <= tenant_max
    tenant_max <= 1  # Tenant can only allow up to Internal
}

# Final decision combining all rules
allow if {
    input.destination_type == "internal"
    allow_internal
}

allow if {
    input.destination_type == "external"
    allow_external
    not deny_external_pii
}

# Reason for denial (for audit trail)
deny_reasons contains reason if {
    input.destination_type == "external"
    not allow_external
    reason := sprintf("Classification level %s is too high for external flow", [input.classification_level])
}

deny_reasons contains reason if {
    deny_external_pii
    reason := "PII detected with strict gating enabled"
}
