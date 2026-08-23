package nem.mcp.controlplane.classification_test

import rego.v1

import data.nem.mcp.controlplane.classification

# Test: Public data allowed externally.
test_public_allowed_external if {
    classification.allow with input as {
        "classification_level": "Public",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: Internal data allowed externally without a tenant maximum (legacy behavior).
test_internal_allowed_external_without_tenant_max if {
    classification.allow with input as {
        "classification_level": "Internal",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: Public tenant maximum denies Internal data externally.
test_public_tenant_max_denies_internal_external if {
    not classification.allow with input as {
        "classification_level": "Internal",
        "tenant_max_external_level": "Public",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: Internal tenant maximum allows Internal data externally.
test_internal_tenant_max_allows_internal_external if {
    classification.allow with input as {
        "classification_level": "Internal",
        "tenant_max_external_level": "Internal",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: A Confidential tenant maximum cannot loosen the system policy.
test_confidential_tenant_max_still_denies_confidential_external if {
    not classification.allow with input as {
        "classification_level": "Confidential",
        "tenant_max_external_level": "Confidential",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: A valid but overly permissive tenant maximum fails closed for otherwise allowed data.
test_confidential_tenant_max_denies_public_external if {
    not classification.allow with input as {
        "classification_level": "Public",
        "tenant_max_external_level": "Confidential",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: Invalid tenant maximum values fail closed.
test_invalid_tenant_max_denies_external if {
    not classification.allow with input as {
        "classification_level": "Public",
        "tenant_max_external_level": "Unknown",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: Strict PII gating remains stronger than a tenant maximum.
test_pii_strict_denies_despite_tenant_max if {
    not classification.allow with input as {
        "classification_level": "Public",
        "tenant_max_external_level": "Internal",
        "has_pii": true,
        "pii_gating_strict": true,
        "destination_type": "external",
    }
}

# Test: Confidential data is denied externally.
test_confidential_denied_external if {
    not classification.allow with input as {
        "classification_level": "Confidential",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: Final denial is explicit false in the package-root OPA response.
test_confidential_denial_is_explicit_false if {
    decision := classification.allow with input as {
        "classification_level": "Confidential",
        "has_pii": false,
        "destination_type": "external",
    }
    decision == false
}

# Test: Restricted data is denied externally.
test_restricted_denied_external if {
    not classification.allow with input as {
        "classification_level": "Restricted",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: Secret data is denied externally.
test_secret_denied_external if {
    not classification.allow with input as {
        "classification_level": "Secret",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: Internal data is always allowed internally.
test_internal_allowed_internally if {
    classification.allow with input as {
        "classification_level": "Confidential",
        "has_pii": true,
        "destination_type": "internal",
    }
}

# Test: Secret data is allowed internally (bus = trust boundary).
test_secret_allowed_internally if {
    classification.allow with input as {
        "classification_level": "Secret",
        "has_pii": true,
        "destination_type": "internal",
    }
}

# Test: PII without strict mode allows Internal externally.
test_pii_non_strict_allows_external if {
    classification.allow with input as {
        "classification_level": "Internal",
        "has_pii": true,
        "pii_gating_strict": false,
        "destination_type": "external",
    }
}

# Test: Tenant maximum denial records a deterministic reason.
test_tenant_max_denial_reason if {
    reasons := classification.deny_reasons with input as {
        "classification_level": "Internal",
        "tenant_max_external_level": "Public",
        "has_pii": false,
        "destination_type": "external",
    }
    reasons == {"Classification level Internal exceeds tenant maximum external level Public"}
}

# Test: Invalid tenant maximum records a deterministic reason.
test_invalid_tenant_max_reason if {
    reasons := classification.deny_reasons with input as {
        "classification_level": "Public",
        "tenant_max_external_level": "Unknown",
        "has_pii": false,
        "destination_type": "external",
    }
    reasons == {"Invalid tenant maximum external level: Unknown"}
}

# Test: A valid tenant maximum above the system limit records a deterministic reason.
test_tenant_max_above_system_limit_reason if {
    reasons := classification.deny_reasons with input as {
        "classification_level": "Public",
        "tenant_max_external_level": "Confidential",
        "has_pii": false,
        "destination_type": "external",
    }
    reasons == {"Tenant maximum external level Confidential exceeds system maximum Internal"}
}

# Test: Strict PII denial records its reason despite a permissive tenant maximum.
test_pii_strict_denial_reason if {
    reasons := classification.deny_reasons with input as {
        "classification_level": "Public",
        "tenant_max_external_level": "Internal",
        "has_pii": true,
        "pii_gating_strict": true,
        "destination_type": "external",
    }
    reasons == {"PII detected with strict gating enabled"}
}
