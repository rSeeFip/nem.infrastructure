# LLM Gating Policy for nem.* Ecosystem
# Package: nem.mcp.controlplane.llm_gating
#
# Controls which data can be sent to which LLM providers.
# Confidential+ data NEVER reaches external LLMs.
# PII gating: optional strict mode blocks even Internal data with PII from external LLMs.

package nem.mcp.controlplane.llm_gating

import rego.v1

# Default: deny sending to external LLM
default allow_external_llm := false

# Default: allow sending to internal LLM (e.g., Ollama)
default allow_internal_llm := true

# Classification levels
classification_levels := {
    "Public": 0,
    "Internal": 1,
    "Confidential": 2,
    "Restricted": 3,
    "Secret": 4,
}

# LLM provider types
internal_providers := {"ollama", "local", "self-hosted"}
external_providers := {"openai", "anthropic", "azure-openai", "google", "litellm-external"}

# Public and Internal data can go to external LLMs
allow_external_llm if {
    level := classification_levels[input.classification_level]
    level < 2  # Below Confidential
    not deny_pii_external
}

# PII strict mode: block PII from external LLMs even if Internal
deny_pii_external if {
    input.has_pii == true
    input.pii_gating_strict == true
}

# Internal LLMs can process any classification level
allow_internal_llm if {
    input.llm_provider in internal_providers
}

# Final gating decision
allow if {
    input.llm_provider in internal_providers
    allow_internal_llm
}

allow if {
    input.llm_provider in external_providers
    allow_external_llm
}

# Allowed levels for the given provider
allowed_levels contains level if {
    input.llm_provider in internal_providers
    some level, _ in classification_levels
}

allowed_levels contains level if {
    input.llm_provider in external_providers
    some level, num in classification_levels
    num < 2
}

# Deny reasons for audit
deny_reasons contains reason if {
    input.llm_provider in external_providers
    not allow_external_llm
    level := input.classification_level
    reason := sprintf("Cannot send %s data to external LLM provider %s", [level, input.llm_provider])
}

deny_reasons contains reason if {
    deny_pii_external
    reason := sprintf("PII data blocked from external LLM provider %s (strict mode)", [input.llm_provider])
}
