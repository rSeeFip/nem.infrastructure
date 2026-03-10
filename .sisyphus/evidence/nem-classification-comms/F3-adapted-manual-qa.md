# F3: Adapted Manual QA — VERDICT: APPROVE

## Date: 2026-03-10
## Auditor: Atlas (Orchestrator)

---

## Adaptation Note

Docker compose smoke test is NOT feasible inside the dev container (no Docker-in-Docker, only infrastructure containers on separate network). QA adapted to code-level integration verification.

---

## Integration Chain Verification

### Chain 1: Classification API → Presidio → Marten Storage
- **Entry**: POST /api/v1/classify → ClassificationEndpoints.cs
- **Engine**: ClassificationEngine.cs → PresidioPiiDetector → PresidioClient (HTTP to Presidio analyzer sidecar)
- **Storage**: Marten document store → ClassificationResultStore with entityType/entityId indexing
- **Fail-closed**: Unclassifiable defaults to Confidential (ClassificationConstants.DefaultLevel)
- **Status**: ✅ Code chain complete, 50 unit tests passing

### Chain 2: HTTP Request → DataClassificationMiddleware → OPA → Block/Allow
- **Entry**: Any HTTP request to Classification-enabled service
- **Middleware**: Reads X-Classification-Level + X-Has-Pii headers
- **OPA**: OpaClassificationClient calls OPA at configurable PolicyPath
- **Decision**: Block or allow based on policy result (unless AuditOnlyMode)
- **Policies validated**: `opa check --v1-compatible` PASS for both classification.rego and llm_gating.rego
- **Status**: ✅ Code chain complete, middleware tests passing

### Chain 3: Wolverine Message → DataClassificationBehavior → Enrichment (NO blocking)
- **Entry**: Any Wolverine envelope
- **Behavior**: Reads classification headers from envelope
- **Action**: Sets ClassificationContext, logs warnings for Restricted/Secret, ALWAYS continues
- **Status**: ✅ Code chain complete, bus trust boundary respected

### Chain 4: LiteLLM Request → ClassificationInterceptor → Classification API → Gating
- **Entry**: LiteLlmClient HTTP request to LiteLLM proxy
- **Interceptor**: LiteLlmClassificationInterceptor (DelegatingHandler) extracts prompt text
- **Classification**: Calls Classification API at /api/v1/classify
- **Gating**: ClassificationGatingHandler blocks Confidential+ to external LLM providers
- **Fallback**: Falls back to Confidential on any classification error (fail-closed)
- **Status**: ✅ Code chain complete, interceptor + gating tests passing

### Chain 5: Embedding Request → EmbeddingClassificationInterceptor → Gating
- **Entry**: OpenAiEmbeddingService HTTP request
- **Interceptor**: EmbeddingClassificationInterceptor resolves classification level
- **Gating**: Same ClassificationGatingHandler from Contracts.AspNetCore
- **Registration**: All 3 embedding HttpClient registrations have interceptor in pipeline
- **Status**: ✅ Code chain complete

### Chain 6: Webhook → Channel Adapter → Validation → Wolverine Bus → Mimir
- **Entry**: POST /api/v1/webhooks/{channelType} → WebhookEndpoints.cs
- **Validation**: Per-channel webhook validation (HMAC-SHA256, JWT, secret comparison, phone comparison)
- **Normalization**: WebhookNormalizer → ChannelInboundMessage
- **Bus**: Wolverine PublishAsync → RabbitMQ → InboundMessageHandler
- **Classification**: InboundMessageClassifier classifies message content inline
- **Routing**: ChannelRouter → OperatorAssignmentService → session creation/routing
- **Status**: ✅ Code chain complete, 139 unit + 8 E2E tests passing

### Chain 7: Operator Response → Channel Selection → Adapter → External Delivery
- **Entry**: POST /api/v1/operator/respond → OperatorRespondHandler
- **Channel**: Keyed IChannelAdapter lookup by ChannelType
- **Delivery**: DeliveryManager → Polly retry (3x exponential) → adapter.SendAsync
- **DLQ**: Failed deliveries → DlqHandler → DlqStore → /api/v1/dlq endpoints
- **Status**: ✅ Code chain complete

### Chain 8: MCP Config Change → Bus → Classification/Comms Hot-Reload
- **MCP**: ConfigurationManagementService publishes ConfigurationChanged event
- **Classification**: McpConfigurationChangedHandler updates PresidioOptions, ClassificationEngineOptions, etc.
- **Comms**: McpConfigurationChangedHandler updates ChannelOptions, RoutingOptions, etc.
- **Status**: ✅ Code chain complete

---

## OPA Policy Validation

```
$ opa check --v1-compatible classification.rego → PASS
$ opa check --v1-compatible llm_gating.rego → PASS
```

---

## Test Coverage Summary

| Component | Tests | Pass | Fail |
|-----------|-------|------|------|
| nem.Contracts | 275 | 275 | 0 |
| nem.Classification | 50 | 50 | 0 |
| nem.Comms (unit) | 139 | 139 | 0 |
| nem.Comms (E2E) | 8 | 8 | 0 |
| nem.KnowHub (embedding) | 126 | 126 | 0 |
| nem.Mimir (infra) | 290 | 285 | 5 (pre-existing) |
| **TOTAL** | **888** | **883** | **5** |

---

## Final Verdict: **APPROVE**

All 8 critical integration chains verified at code level.
OPA policies pass validation.
888 tests total, 883 pass, 5 pre-existing failures (unrelated to plan).
No stubs, TODOs, or incomplete implementations found.
