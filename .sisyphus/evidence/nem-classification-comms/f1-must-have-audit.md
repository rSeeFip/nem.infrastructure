# F1 Must Have Audit

## Result
Passed: 11/13

## Checklist

### MH1 — PASS
`nem.Contracts/src/nem.Contracts/Classification/ClassificationLevel.cs:9-15` defines exactly 5 enum values: `Public`, `Internal`, `Confidential`, `Restricted`, `Secret`.

### MH2 — PASS
`nem.Contracts/src/nem.Contracts/Classification/ClassificationResult.cs:6-9` includes `bool HasPii` alongside `ClassificationLevel Level`.

### MH3 — PASS
`nem.Contracts/src/nem.Contracts/Classification/ClassificationConstants.cs:11` sets `DefaultLevel = ClassificationLevel.Confidential`.

### MH4 — PASS
Strict external LLM blocking is functionally present via classification interceptors and outbound gating:
- `nem.Mimir-typed-ids/src/Mimir.Infrastructure/LiteLlm/LiteLlmClassificationInterceptor.cs:28-33,35-69`
- `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/ClassificationGatingHandler.cs:53-84`
- `nem.Mimir-typed-ids/src/Mimir.Api/Program.cs:199-210` wires LiteLLM through interceptor + gating handler
- `nem.KnowHub/services/KnowHub.Embedding/ServiceCollectionExtensions.cs:51-77,96-115` wires OpenAI-compatible embedding egress through classification interceptor + gating handler
These paths confirm Confidential+ external LLM traffic is blocked by the shared gating threshold.

### MH5 — PASS
Audit-only deployment mode exists and is respected:
- `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/DataClassificationOptions.cs:9-17` exposes `AuditOnlyMode`
- `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/DataClassificationMiddleware.cs:61-69` logs and allows when audit-only is enabled.

### MH6 — PASS
Per-entity classification is supported generically:
- `nem.Classification/src/Classification.Application/Dtos/ClassifyRequest.cs:3` carries `EntityType` + `EntityId`
- `nem.Classification/src/Classification.Application/ClassificationService.cs:25-33,53-63` stores and retrieves by `EntityType`/`EntityId`
- `nem.Classification/src/Classification.Api/Endpoints/ClassificationEndpoints.cs:13-15` exposes classify/get/batch endpoints.
Note: explicit tests found only for `Document`, but handlers are entity-type agnostic.

### MH7 — PASS
`nem.Classification/src/Classification.Infrastructure/Presidio/PresidioClient.cs:8-20` hardcodes exactly the 5 required Presidio entities: `PERSON`, `EMAIL_ADDRESS`, `PHONE_NUMBER`, `CREDIT_CARD`, `IBAN_CODE`.

### MH8 — FAIL
No human override endpoint/handler or raise-only validation was found under `nem.Classification/src`. Grep for `override|manual override|raise only|lower|approval|workflow` returned no relevant implementation.

### MH9 — PASS
OPA-backed classification policy evaluation exists:
- `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/OpaClassificationClient.cs:25-86` calls OPA
- `nem.MCP/policies/classification.rego` and `nem.MCP/policies/llm_gating.rego` define classification/LLM gating policies.
Note: the actual policy directory is `nem.MCP/policies/`, not the checklist’s `server/nem.MCP/Policies/` path.

### MH10 — FAIL
Both egress points are functionally gated, but the specified client files do not themselves contain the gating logic:
- `nem.Mimir-typed-ids/src/Mimir.Infrastructure/LiteLlm/LiteLlmClient.cs` contains no direct classification check
- `OpenAiEmbeddingService.cs` is not present in `nem.Mimir-typed-ids`; the relevant file is `nem.KnowHub/services/KnowHub.Embedding/Services/OpenAiEmbeddingService.cs`, and its gating is applied externally in `ServiceCollectionExtensions.cs`.
This means the checklist’s file-local verification requirement is not satisfied as written.

### MH11 — PASS
`nem.Comms/src` contains the required channel edge adapters and routing core:
- adapters: `WebWidgetAdapter.cs`, `TelegramAdapter.cs`, `WhatsAppAdapter.cs`, `TeamsAdapter.cs`, `SignalAdapter.cs`
- routing core: `nem.Comms/src/Comms.Application/Routing/ChannelRouter.cs`.

### MH12 — PASS
Both Phase 1 adapters implement `IChannelAdapter`:
- `nem.Comms/src/Comms.Infrastructure/Channels/WebWidget/WebWidgetAdapter.cs:11-13`
- `nem.Comms/src/Comms.Infrastructure/Channels/Teams/TeamsAdapter.cs:7-10`
- interface: `nem.Comms/src/Comms.Domain/IChannelAdapter.cs:5-12`.

### MH13 — PASS
Substantial test suites exist:
- `nem.Classification/tests` → 13 `*Tests.cs` files
- `nem.Comms/tests` → 43 `*Tests.cs` files
- `nem.Contracts/tests` → 16 `*Tests.cs` files.
