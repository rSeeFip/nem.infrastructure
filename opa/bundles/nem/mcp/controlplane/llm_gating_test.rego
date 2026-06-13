package nem.mcp.controlplane.llm_gating_test

import rego.v1

import data.nem.mcp.controlplane.llm_gating

# Test: Public data to external LLM allowed
test_public_to_openai if {
    llm_gating.allow with input as {
        "classification_level": "Public",
        "has_pii": false,
        "llm_provider": "openai",
    }
}

# Test: Internal data to external LLM allowed
test_internal_to_openai if {
    llm_gating.allow with input as {
        "classification_level": "Internal",
        "has_pii": false,
        "llm_provider": "openai",
    }
}

# Test: Confidential data to external LLM DENIED
test_confidential_to_openai_denied if {
    not llm_gating.allow with input as {
        "classification_level": "Confidential",
        "has_pii": false,
        "llm_provider": "openai",
    }
}

# Test: Confidential data to Ollama (internal) ALLOWED
test_confidential_to_ollama_allowed if {
    llm_gating.allow with input as {
        "classification_level": "Confidential",
        "has_pii": false,
        "llm_provider": "ollama",
    }
}

# Test: Secret data to Ollama (internal) ALLOWED
test_secret_to_ollama_allowed if {
    llm_gating.allow with input as {
        "classification_level": "Secret",
        "has_pii": true,
        "llm_provider": "ollama",
    }
}

# Test: Secret data to external LLM DENIED
test_secret_to_openai_denied if {
    not llm_gating.allow with input as {
        "classification_level": "Secret",
        "has_pii": false,
        "llm_provider": "openai",
    }
}

# Test: PII strict blocks Internal from external LLM
test_pii_strict_blocks_internal_external if {
    not llm_gating.allow with input as {
        "classification_level": "Internal",
        "has_pii": true,
        "pii_gating_strict": true,
        "llm_provider": "openai",
    }
}

# Test: PII non-strict allows Internal to external LLM
test_pii_non_strict_allows_internal_external if {
    llm_gating.allow with input as {
        "classification_level": "Internal",
        "has_pii": true,
        "pii_gating_strict": false,
        "llm_provider": "anthropic",
    }
}

# Test: Deny reasons for Confidential to external
test_deny_reasons_confidential_external if {
    reasons := llm_gating.deny_reasons with input as {
        "classification_level": "Confidential",
        "has_pii": false,
        "llm_provider": "openai",
    }
    count(reasons) > 0
}

# Test: Allowed levels for internal provider includes all
test_internal_provider_all_levels if {
    levels := llm_gating.allowed_levels with input as {
        "llm_provider": "ollama",
    }
    count(levels) == 5
}
