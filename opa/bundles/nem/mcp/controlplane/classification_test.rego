package nem.mcp.controlplane.classification_test

import rego.v1

import data.nem.mcp.controlplane.classification

# Test: Public data allowed externally
test_public_allowed_external if {
    classification.allow with input as {
        "classification_level": "Public",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: Internal data allowed externally (no PII)
test_internal_allowed_external if {
    classification.allow with input as {
        "classification_level": "Internal",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: Confidential data DENIED externally
test_confidential_denied_external if {
    not classification.allow with input as {
        "classification_level": "Confidential",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: Restricted data DENIED externally
test_restricted_denied_external if {
    not classification.allow with input as {
        "classification_level": "Restricted",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: Secret data DENIED externally
test_secret_denied_external if {
    not classification.allow with input as {
        "classification_level": "Secret",
        "has_pii": false,
        "destination_type": "external",
    }
}

# Test: Internal data always allowed internally
test_internal_allowed_internally if {
    classification.allow with input as {
        "classification_level": "Confidential",
        "has_pii": true,
        "destination_type": "internal",
    }
}

# Test: Secret data allowed internally (bus = trust boundary)
test_secret_allowed_internally if {
    classification.allow with input as {
        "classification_level": "Secret",
        "has_pii": true,
        "destination_type": "internal",
    }
}

# Test: PII strict gating blocks Internal externally
test_pii_strict_blocks_external if {
    not classification.allow with input as {
        "classification_level": "Internal",
        "has_pii": true,
        "pii_gating_strict": true,
        "destination_type": "external",
    }
}

# Test: PII without strict mode allows Internal externally
test_pii_non_strict_allows_external if {
    classification.allow with input as {
        "classification_level": "Internal",
        "has_pii": true,
        "pii_gating_strict": false,
        "destination_type": "external",
    }
}

# Test: Deny reasons populated for Confidential external
test_deny_reasons_confidential_external if {
    reasons := classification.deny_reasons with input as {
        "classification_level": "Confidential",
        "has_pii": false,
        "destination_type": "external",
    }
    count(reasons) > 0
}
