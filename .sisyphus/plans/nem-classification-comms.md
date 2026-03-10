# nem.Classification + nem.Comms — Data Classification & Federated Communication Manager

> **STATUS: ✅ COMPLETED — 2026-03-10**
> 
> All 32 implementation tasks (T1–T32) across 7 waves completed.
> Final Verification Wave (F1–F4): ALL APPROVE.
> 888 tests total (883 pass, 5 pre-existing).
> 7 repositories modified, all pushed.
> Evidence: `.sisyphus/evidence/nem-classification-comms/`

## TL;DR

> **Quick Summary**: Build a cross-cutting data classification framework (Public/Internal/Confidential/Restricted/Secret + PII detection) that gates all external data flows, then layer a federated communication manager on top that unifies Telegram, Teams, WhatsApp, Signal, and WebWidget into a single operator-facing service.
> 
> **Deliverables**:
> - Classification types/attributes in `nem.Contracts` (new `Classification/` namespace)
> - `nem.Classification` service: Presidio PII detection + OPA policy evaluation + classification API + audit trail
> - Classification enforcement middleware: HTTP, Wolverine, HttpClientFactory DelegatingHandler
> - LLM gating on both egress points (LiteLlmClient + OpenAiEmbeddingService)
> - `nem.Comms` service: Channel Edge, Federation Core, Identity & Policy, Operator Read/API
> - 5 channel adapters: WebWidget, Teams, WhatsApp, Telegram, Signal
> - Migration tooling for existing unclassified data + audit-only deployment mode
> 
> **Estimated Effort**: XL
> **Parallel Execution**: YES — 6 waves
> **Critical Path**: T1 → T3 → T7 → T10 → T14 → T20 → T24 → T28 → FINAL

---

## Context

### Original Request
User requested two workstreams merged into one comprehensive plan:
1. **Federated Communication Manager**: Unify Telegram, Teams, WhatsApp, Signal, WebWidget into one federated human communication manager service, built evolutionarily on existing `nem.Mimir-typed-ids` channel abstractions.
2. **Data Classification & Policy Engineering**: Add a cross-cutting data classification framework to the entire `nem.*` ecosystem with classification levels (Public, Internal, Confidential, Restricted, Secret) plus a regulated PII category. Must gate what data flows to external services like LLM providers.

### Interview Summary
**Key Discussions**:
- **Architecture split**: Types in `nem.Contracts` (compile-time), engine as standalone `nem.Classification` service (runtime)
- **Default classification**: Confidential (fail-closed) — unclassified data blocked from external flows
- **LLM gating**: Strict block — Confidential+ NEVER reaches external LLMs (OpenAI, Anthropic). Only Public/Internal allowed.
- **Granularity**: Per-entity (document, conversation, knowledge article)
- **Assignment**: Automated primary (Presidio + rules), human override (raise only, never lower)
- **Comms hosting**: Standalone `nem.Comms` from day one (own DB, deployment, CI)
- **Phasing**: Classification FIRST, then comms on top
- **Test strategy**: TDD with xunit
- **License**: Corporate freeware only (no paid services)

**Research Findings**:
- **ALL external data flows currently UNPROTECTED**: LiteLlmClient.cs, OpenAiEmbeddingService.cs, all 5 channel adapters, Jira/Confluence plugins
- **Canonical cross-cutting pattern**: `OpaAuthorizationHandler` (fail-closed, extension method registration) is the blueprint
- **Microsoft Presidio** (MIT): PII detection sidecar, LiteLLM already has Presidio callback built in
- **OPA** (Apache-2.0): Already in stack for auth, extensible for classification policies
- **No existing classification/sensitivity patterns** — greenfield for classification

### Metis Review
**Identified Gaps** (all addressed):
- **Domain model ownership**: nem.Comms owns routing state (ChannelSession, ChannelIdentityLink). Mimir retains Conversation/Message lifecycle.
- **PII as level vs flag**: PII is a detection boolean alongside classification level, NOT a 6th level.
- **Retroactivity**: Deploy with "audit-only" mode first (log violations, don't block). Flip to enforcement after backfill.
- **"External" definition**: Ollama (local Docker) = internal = allowed. OpenAI/Anthropic = external = blocked for Confidential+.
- **Both LLM egress points**: Must gate `LiteLlmClient` AND `OpenAiEmbeddingService`.
- **Channel adapters**: Build NEW in nem.Comms, don't extract from Mimir. Gradual migration later.
- **Streaming responses**: Classify full prompt BEFORE streaming starts.
- **Bus messages**: Internal trust boundary — no classification gating on Wolverine bus.
- **Non-text payloads**: Classified at entity level (whole unit by entity's level).
- **Classification propagation**: max(source classifications) for derivatives.
- **Scope locks**: No Classification UI, no conversation management in nem.Comms, no PII beyond 5 core types.

---

## Work Objectives

### Core Objective
Build a classification-first security foundation for the nem.* ecosystem, then layer a federated communication manager on top that routes messages across channels with classification-aware policy enforcement.

### Concrete Deliverables
- `nem.Contracts/src/nem.Contracts/Classification/` — ClassificationLevel enum, HasPii flag, DataClassificationAttribute, IClassificationContext
- `nem.Classification/` — new .NET service with Presidio integration, OPA policy evaluation, classification REST API, audit trail
- `nem.Classification/sidecar/presidio/` — Presidio Docker sidecar (FastAPI wrapper, like PaddleOCR pattern)
- Classification enforcement middleware in `nem.Contracts.AspNetCore/` — DataClassificationMiddleware, DataClassificationBehavior (Wolverine), ClassificationGatingHandler (DelegatingHandler)
- LLM gating applied to `LiteLlmClient` and `OpenAiEmbeddingService`
- OPA Rego policies for classification: `policies/classification.rego`, `policies/llm_gating.rego`
- `nem.Comms/` — new .NET service with 4 modules
- 5 channel adapters in nem.Comms (WebWidget, Teams, WhatsApp, Telegram, Signal)
- Migration CLI tool for backfilling classification on existing data
- docker-compose additions for Presidio + nem.Classification + nem.Comms

### Definition of Done
- [x] `dotnet build nem.Classification.sln` → 0 warnings, 0 errors
- [x] `dotnet build nem.Comms.sln` → 0 warnings, 0 errors
- [x] `dotnet test` → all tests pass (classification + comms)
- [x] Classification gating verified: Confidential document → LLM request → 403 ClassificationGatingDenied
- [x] Classification gating verified: Public document → LLM request → 200 OK
- [x] PII detection verified: text with email → hasPii=true, level≥Confidential
- [x] Channel message routing verified: inbound Telegram webhook → nem.Comms → Wolverine event → Mimir
- [x] Audit trail verified: all classification decisions logged with entity, level, source, timestamp
- [x] `docker compose up` starts Presidio, nem.Classification, nem.Comms successfully
- [x] All services expose /health endpoint

### Must Have
- ClassificationLevel enum: Public, Internal, Confidential, Restricted, Secret
- PII detection flag (boolean) alongside classification level
- Fail-closed default: unclassified = Confidential
- Strict LLM block: Confidential+ never reaches external LLM providers
- Audit-only deployment mode (log violations, don't block) for migration period
- Per-entity classification (document, conversation, knowledge article)
- Automated classification via Presidio (5 core PII types: PERSON, EMAIL_ADDRESS, PHONE_NUMBER, CREDIT_CARD, IBAN_CODE)
- Human override (raise only, never lower)
- OPA-based classification policy evaluation
- Both LLM egress points gated (LiteLlmClient + OpenAiEmbeddingService)
- nem.Comms with Channel Edge + Federation Core
- At least WebWidget + Teams adapters functional in Phase 1
- TDD — tests first for all components

### Must NOT Have (Guardrails)
- ❌ Classification UI/dashboards (API + middleware only)
- ❌ Conversation management in nem.Comms (routing/federation ONLY — Mimir owns conversations)
- ❌ PII entity types beyond 5 core types in Phase 1
- ❌ Channel capability runtime negotiation (static declaration only)
- ❌ Message transformation/enrichment pipeline (pass-through only)
- ❌ Modification of existing nem.Contracts interfaces (additive only, new Classification/ namespace)
- ❌ Extraction of existing Mimir channel adapters (build new, don't extract)
- ❌ Classification **blocking/gating** on Wolverine bus messages (bus = internal trust boundary; metadata enrichment/propagation IS allowed — attaching classification headers to message context for downstream visibility)
- ❌ Paid/commercial services (corporate freeware only)
- ❌ Over-engineered PII detection (confidence >= 0.7, 5 entity types, expand later)
- ❌ Human override approval workflow (immediate effect, audit logged, no workflow engine)

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (xunit, .NET test projects across nem.*)
- **Automated tests**: TDD (RED → GREEN → REFACTOR)
- **Framework**: xunit.v3 + FluentAssertions + NSubstitute + Testcontainers (integration)
- **If TDD**: Each task writes failing tests first, then implements to pass

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/nem-classification-comms/task-{N}-{scenario-slug}.{ext}`.

- **API/Backend**: Use Bash (curl) — Send requests, assert status + response fields
- **Middleware**: Use Bash (dotnet test) — Integration tests with WebApplicationFactory
- **Docker services**: Use Bash (docker compose) — Health checks, logs, connectivity
- **Policy (OPA)**: Use Bash (opa eval) — Evaluate Rego policies against test inputs

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation — types, contracts, scaffolding — NO dependencies):
├── T1: Classification types in nem.Contracts [quick]
├── T2: nem.Classification service scaffolding [quick]
├── T3: Presidio sidecar Docker setup [quick]
├── T4: nem.Comms service scaffolding [quick]
├── T5: OPA classification policy definitions [quick]
└── T29: MCP backend — extend config for Classification & Comms [quick]

Wave 2 (Classification Core + Comms Domain — depend on Wave 1 only):
├── T6: nem.Comms domain model + persistence (depends: T4) [unspecified-high]
├── T7: Classification engine + Presidio integration (depends: T2, T3) [deep]
├── T9: DataClassificationMiddleware — HTTP (depends: T1, T5) [unspecified-high]
├── T10: DataClassificationBehavior — Wolverine (depends: T1, T5) [unspecified-high]
├── T11: ClassificationGatingHandler — DelegatingHandler (depends: T1, T5) [deep]
├── T12: Classification audit trail service (depends: T2, T1) [unspecified-high]
└── T30: MCP Angular UI — Service Configuration page (depends: T29) [visual-engineering]

Wave 3 (REST API + Gating + Channel Foundation — depend on Wave 2):
├── T8: Classification REST API (depends: T2, T7) [unspecified-high]
├── T13: LLM gating — LiteLlmClient (depends: T11) [deep]
├── T14: LLM gating — OpenAiEmbeddingService (depends: T11) [deep]
├── T16: Channel Edge — webhook ingestion + validation (depends: T1, T4, T6) [deep]
└── T24: Identity & Policy — tenant-scoped identity links (depends: T6, T5) [deep]

Wave 4 (Migration + Channel Adapters + Federation — depend on Wave 3):
├── T15: Migration CLI + audit-only mode (depends: T7, T8) [unspecified-high]
├── T17: Channel Edge — WebWidget adapter (depends: T16) [unspecified-high]
├── T18: Channel Edge — Teams adapter (depends: T16) [unspecified-high]
├── T19: Federation Core — conversation routing + assignment (depends: T1, T6, T16) [deep]
├── T21: Channel Edge — Telegram adapter (depends: T16) [unspecified-high]
├── T22: Channel Edge — WhatsApp adapter (depends: T16) [unspecified-high]
├── T23: Channel Edge — Signal adapter (depends: T16) [unspecified-high]
├── T31: Wire nem.Classification to MCP config (depends: T2, T7, T29) [unspecified-high]
└── T32: Wire nem.Comms to MCP config (depends: T4, T16, T29) [unspecified-high]

Wave 5 (Federation Advanced + Operator + Docker — depend on Wave 4):
├── T20: Federation Core — delivery retries + DLQ (depends: T19) [deep]
├── T25: Operator Read/API — unified inbox (depends: T19, T24) [deep]
└── T27: Docker Compose — full stack (depends: T3, T8, T17, T18) [quick]

Wave 6 (Classification-Comms Integration — depend on Wave 5):
└── T26: Classification integration in nem.Comms (depends: T9, T10, T24, T25) [deep]

Wave 7 (End-to-End Testing — depend on Wave 6):
└── T28: End-to-end integration tests (depends: T7, T8, T16, T17, T18, T19, T21, T26) [deep]

Wave FINAL (After ALL tasks — independent review, 4 parallel):
├── F1: Plan compliance audit (oracle)
├── F2: Code quality review (unspecified-high)
├── F3: Real manual QA (unspecified-high)
└── F4: Scope fidelity check (deep)

Critical Path: T1 → T5 → T11 → T13 → (T28 via T26 chain) → FINAL
Parallel Speedup: ~55% faster than sequential
Max Concurrent: 9 (Wave 4)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| T1 | — | T9, T10, T11, T12, T16, T19, T24 | 1 |
| T2 | — | T7, T8, T12 | 1 |
| T3 | — | T7, T27 | 1 |
| T4 | — | T16 | 1 |
| T5 | — | T9, T10, T11, T24 | 1 |
| T29 | — | T30, T31, T32 | 1 |
| T6 | T4 | T16, T17, T18, T19, T20, T21, T22, T23, T24, T25 | 2 |
| T7 | T2, T3 | T8, T15 | 2 |
| T9 | T1, T5 | T26 | 2 |
| T10 | T1, T5 | T26 | 2 |
| T11 | T1, T5 | T13, T14 | 2 |
| T12 | T2, T1 | — | 2 |
| T30 | T29 | FINAL | 2 |
| T8 | T2, T7 | T15, T27 | 3 |
| T13 | T11 | T28 | 3 |
| T14 | T11 | T28 | 3 |
| T16 | T1, T4, T6 | T17, T18, T19, T21-T23 | 3 |
| T24 | T6, T5 | T25, T26 | 3 |
| T15 | T7, T8 | — | 4 |
| T17 | T16 | T27, T28 | 4 |
| T18 | T16 | T27, T28 | 4 |
| T19 | T1, T6, T16 | T20, T25, T28 | 4 |
| T21 | T16 | — | 4 |
| T22 | T16 | — | 4 |
| T23 | T16 | — | 4 |
| T31 | T2, T7, T29 | FINAL | 4 |
| T32 | T4, T16, T29 | FINAL | 4 |
| T20 | T19 | — | 5 |
| T25 | T19, T24 | — | 5 |
| T27 | T3, T8, T17, T18 | — | 5 |
| T26 | T9, T10, T24, T25 | — | 6 |
| T28 | T7, T8, T16, T17, T18, T19, T21, T26 | FINAL | 7 |

### Port Map (Canonical)

> All services use these ports consistently across Docker Compose and QA scenarios.
> Individual task QA during development may use `dotnet run` on default ports (5050/5100/5200) — these are dev-only.
> Final Verification and Docker Compose MUST use the canonical ports below.

| Service | Docker Port | Dev Port (dotnet run) |
|---------|------------|----------------------|
| Presidio Analyzer | 5001 | 5050 |
| nem.Classification | 5270 | 5100 |
| nem.Comms | 5280 | 5200 |
| PostgreSQL | 5432 | 5432 |
| RabbitMQ | 5672 / 15672 | 5672 / 15672 |
| Keycloak | 8080 | 8080 |
| OPA | 8181 | 8181 |
| OpenBao              | 8200        | 8200     |
| nem.MCP API          | 5000        | 5000     |
| nem.MCP Angular UI   | 4200        | 4200     |
| nem.Mimir (existing) | 5223        | 5223     |
| nem.KnowHub (existing) | 5100      | 5100     |

### Agent Dispatch Summary

- **Wave 1**: 6 tasks — T1-T3,T5 → `quick`, T4 → `quick`, T29 → `quick`
- **Wave 2**: 7 tasks — T6 → `unspecified-high`, T7,T11 → `deep`, T9,T10,T12 → `unspecified-high`, T30 → `visual-engineering`
- **Wave 3**: 5 tasks — T8 → `unspecified-high`, T13,T14,T16 → `deep`, T24 → `deep`
- **Wave 4**: 9 tasks — T15,T17,T18 → `unspecified-high`, T19 → `deep`, T21-T23 → `unspecified-high`, T31,T32 → `unspecified-high`
- **Wave 5**: 3 tasks — T20 → `deep`, T25 → `deep`, T27 → `quick`
- **Wave 6**: 1 task — T26 → `deep`
- **Wave 7**: 1 task — T28 → `deep`
- **FINAL**: 4 tasks — F1 → `oracle`, F2,F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

> Implementation + Test = ONE Task. Never separate.
> EVERY task MUST have: Recommended Agent Profile + Parallelization info + QA Scenarios.
> **A task WITHOUT QA Scenarios is INCOMPLETE. No exceptions.**

### Wave 1 — Foundation (types, contracts, scaffolding)

- [x] 1. Classification Types in nem.Contracts

  **What to do**:
  - **RED**: Write xunit tests in `nem.Contracts/tests/` for:
    - `ClassificationLevel` enum has exactly 5 values: Public(0), Internal(1), Confidential(2), Restricted(3), Secret(4)
    - `ClassificationLevel` supports comparison operators (`Confidential > Internal == true`)
    - `DataClassificationAttribute` can annotate classes and properties with level + hasPii
    - `IClassificationContext` interface exposes `ClassificationLevel Level`, `bool HasPii`, `string EntityType`, `string EntityId`
    - `ClassificationResult` record contains Level, HasPii, PiiEntities (List<string>), Source (Automated/HumanOverride), Timestamp
    - `ChannelEventReceivedIntegrationEvent` record has all required fields (ChannelType, ExternalChannelId, SenderId, SenderDisplayName, Content, Timestamp, RawPayload) and is serializable
  - **GREEN**: Create `nem.Contracts/src/nem.Contracts/Classification/` namespace:
    - `ClassificationLevel.cs` — enum with `[JsonConverter]` for string serialization
    - `DataClassificationAttribute.cs` — attribute for compile-time annotation
    - `IClassificationContext.cs` — runtime classification context interface
    - `ClassificationResult.cs` — immutable record for classification outcomes
    - `ClassificationConstants.cs` — default level = Confidential, policy names
  - **GREEN**: Create `nem.Contracts/src/nem.Contracts/Events/Integration/ChannelEventReceivedIntegrationEvent.cs` — shared bus contract for Comms→Mimir communication. Fields: `string ChannelType`, `string ExternalChannelId`, `string SenderId`, `string SenderDisplayName`, `string Content`, `DateTimeOffset Timestamp`, `string? RawPayload`. This is the Wolverine message type that nem.Comms publishes and nem.Mimir consumes. Follows existing integration event patterns in `Events/Integration/` (alongside `MessageCreatedEvent` from T25)
  - **REFACTOR**: Ensure all types follow existing nem.Contracts patterns (no external dependencies, netstandard2.1 compatible)

  **Must NOT do**:
  - Do NOT modify any existing interfaces in nem.Contracts
  - Do NOT add implementation logic — types/contracts only
  - Do NOT add dependencies beyond System.Text.Json

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple type definitions, enum, attribute, interface — single project, <10 files
  - **Skills**: []
    - No specialized skills needed — pure C# type definitions
  - **Skills Evaluated but Omitted**:
    - `playwright`: No UI involved
    - `git-master`: Standard commit, no complex git ops

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with T2, T3, T4, T5, T29)
  - **Blocks**: T9, T10, T11, T12, T16, T19, T24
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References** (existing code to follow):
  - `nem.Contracts/src/nem.Contracts/Channels/ChannelType.cs` — Enum pattern with JSON serialization used across nem.* ecosystem
  - `nem.Contracts/src/nem.Contracts/Channels/IChannelEventSource.cs` — Interface definition pattern (slim, no implementation)
  - `nem.Contracts/src/nem.Contracts/Channels/ChannelCapabilities.cs` — Record/class pattern for data containers

  **API/Type References** (contracts to implement against):
  - Five classification levels confirmed: Public, Internal, Confidential, Restricted, Secret
  - PII flag is boolean alongside level, NOT a 6th level

  **Test References**:
  - Follow existing xunit conventions in the nem.* repos — `[Fact]`, `[Theory]`, FluentAssertions

  **WHY Each Reference Matters**:
  - `ChannelType.cs`: Follow exact enum serialization pattern so classification enums are consistent across services
  - `IChannelEventSource.cs`: Interface style guide — no default implementations, xmldoc on every member
  - `ChannelCapabilities.cs`: Shows how nem.Contracts structures data objects (immutable, records where possible)

  **Acceptance Criteria**:
  - [x] `dotnet build nem.Contracts/src/nem.Contracts/` → 0 warnings, 0 errors
  - [x] `dotnet test nem.Contracts/tests/` → all classification type tests pass
  - [x] `ClassificationLevel.Confidential > ClassificationLevel.Internal` evaluates to `true`
  - [x] JSON serialization of `ClassificationLevel.Secret` → `"Secret"` (string, not int)
  - [x] `DataClassificationAttribute` compiles as `[DataClassification(ClassificationLevel.Internal)]` on a class

  **QA Scenarios**:

  ```
  Scenario: ClassificationLevel enum serialization roundtrip
    Tool: Bash (dotnet test)
    Preconditions: nem.Contracts solution builds successfully
    Steps:
      1. Run `dotnet test nem.Contracts/tests/ --filter "Classification" --logger "console;verbosity=detailed"`
      2. Verify test output contains "Passed!" for all classification type tests
      3. Check test count >= 5 (enum values, comparison, attribute, interface, result record)
    Expected Result: All tests pass, 0 failures, 0 skipped
    Failure Indicators: Any test shows "Failed", build errors in Classification namespace
    Evidence: .sisyphus/evidence/nem-classification-comms/task-1-classification-types-tests.txt

  Scenario: Classification types are purely additive (no existing breaks)
    Tool: Bash (dotnet build)
    Preconditions: Classification types added to nem.Contracts
    Steps:
      1. Run `dotnet build nem.Contracts/nem.Contracts.slnx` (full solution including AspNetCore)
      2. Verify 0 errors, 0 warnings
      3. Run `dotnet build nem.Mimir-typed-ids/nem.Mimir.sln` to verify downstream consumers still compile
    Expected Result: All solutions build clean — existing code unaffected
    Failure Indicators: Build errors in any existing project referencing nem.Contracts
    Evidence: .sisyphus/evidence/nem-classification-comms/task-1-additive-build-check.txt
  ```

  **Commit**: YES
  - Message: `feat(contracts): add classification types and channel event contract to nem.Contracts`
  - Files: `nem.Contracts/src/nem.Contracts/Classification/*`, `nem.Contracts/src/nem.Contracts/Events/Integration/ChannelEventReceivedIntegrationEvent.cs`, `nem.Contracts/tests/**/Classification*`
  - Pre-commit: `dotnet build nem.Contracts && dotnet test nem.Contracts/tests/`

- [x] 2. nem.Classification Service Scaffolding

  **What to do**:
  - **RED**: Write xunit test that verifies:
    - `Classification.Api` project targets net10.0, builds, and starts as Minimal API
    - `/health` endpoint returns 200 with JSON `{"status":"Healthy"}`
    - DI container resolves `IClassificationEngine` interface
    - Swagger/OpenAPI endpoint available at `/swagger`
  - **GREEN**: Scaffold new `nem.Classification/` solution:
    - `nem.Classification.sln` — solution file
    - `src/Classification.Api/` — ASP.NET Core Minimal API (Program.cs, appsettings.json)
    - `src/Classification.Domain/` — domain interfaces (IClassificationEngine, IClassificationRepository)
    - `src/Classification.Infrastructure/` — infrastructure stubs
    - `src/Classification.Application/` — application services (CQRS command/query stubs)
    - `tests/Classification.Tests/` — xunit test project
    - Standard config: Keycloak auth, Serilog, health checks, OpenAPI
    - In `Program.cs`: register `services.AddNemSecrets(configuration)` for OpenBao/fallback secret resolution
    - `Dockerfile` and `.dockerignore`
  - **REFACTOR**: Ensure solution structure matches nem.Mimir-typed-ids and nem.KnowHub patterns exactly

  **Must NOT do**:
  - Do NOT implement classification logic yet (scaffolding only)
  - Do NOT add Presidio client code (T7)
  - Do NOT add REST endpoints beyond /health and /swagger (T8)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Project scaffolding from established patterns — no complex logic, just file structure + boilerplate
  - **Skills**: []
    - No specialized skills needed
  - **Skills Evaluated but Omitted**:
    - `playwright`: No UI

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with T1, T3, T4, T5, T29)
  - **Blocks**: T7, T8, T12
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `nem.Mimir-typed-ids/src/Mimir.Api/Program.cs` — Minimal API setup with Keycloak, Serilog, health checks, Wolverine, Swagger
  - `nem.Mimir-typed-ids/nem.Mimir.sln` — Solution file structure pattern (src/, tests/ folders)
  - `nem.KnowHub/services/KnowHub.Api/Program.cs` — Alternative Minimal API setup reference
  - `nem.Mimir-typed-ids/docker/api/Dockerfile` — Docker build pattern for .NET services
  - `nem.Contracts/src/nem.Contracts.AspNetCore/Secrets/NemSecretsExtensions.cs` — `AddNemSecrets(configuration)` one-liner DI registration for OpenBao/fallback secrets

  **API/Type References**:
  - `IClassificationEngine` — to be defined in Domain: `Task<ClassificationResult> ClassifyAsync(string text, string entityType, string entityId, CancellationToken ct)`
  - `IClassificationRepository` — to be defined in Domain: CRUD for stored classifications

  **WHY Each Reference Matters**:
  - `Mimir.Api/Program.cs`: THE canonical service setup. Copy auth config, middleware order, health check registration, Serilog setup
  - `nem.Mimir.sln`: Solution layout (src/tests split) must match for consistency
  - `Dockerfile`: Multi-stage .NET build pattern used across all nem.* services

  **Acceptance Criteria**:
  - [x] `dotnet build nem.Classification/nem.Classification.sln` → 0 warnings, 0 errors
  - [x] `dotnet test nem.Classification/tests/` → scaffolding tests pass
  - [x] `docker build -f nem.Classification/src/Classification.Api/Dockerfile .` → image builds
  - [x] Health endpoint test passes

  **QA Scenarios**:

  ```
  Scenario: Service starts and health endpoint responds
    Tool: Bash (dotnet run + curl)
    Preconditions: nem.Classification.sln builds successfully
    Steps:
      1. Run `dotnet run --project nem.Classification/src/Classification.Api/ --urls http://localhost:5100 &`
      2. Wait 5 seconds for startup
      3. Run `curl -s http://localhost:5100/health`
      4. Assert response contains `"status":"Healthy"` or `"Healthy"`
      5. Kill the background process
    Expected Result: HTTP 200 with healthy status
    Failure Indicators: Connection refused, non-200 status, missing health endpoint
    Evidence: .sisyphus/evidence/nem-classification-comms/task-2-health-endpoint.txt

  Scenario: Solution structure matches nem.* conventions
    Tool: Bash (find + ls)
    Preconditions: Scaffolding complete
    Steps:
      1. Verify directory structure: `ls nem.Classification/src/` shows Classification.Api, Classification.Domain, Classification.Infrastructure, Classification.Application
      2. Verify `ls nem.Classification/tests/` shows Classification.Tests
      3. Verify `nem.Classification/nem.Classification.sln` exists
      4. Verify `nem.Classification/src/Classification.Api/Dockerfile` exists
    Expected Result: All directories and files present matching nem.* conventions
    Failure Indicators: Missing directories, wrong naming, no Dockerfile
    Evidence: .sisyphus/evidence/nem-classification-comms/task-2-structure-check.txt
  ```

  **Commit**: YES
  - Message: `feat(classification): scaffold nem.Classification service`
  - Files: `nem.Classification/**`
  - Pre-commit: `dotnet build nem.Classification/nem.Classification.sln`

- [x] 3. Presidio PII Detection Sidecar Docker Setup

  **What to do**:
  - **RED**: Write test that verifies:
    - Presidio container starts and `/health` returns 200
    - POST `/analyze` with `{"text":"My email is john@example.com","language":"en"}` returns EMAIL_ADDRESS entity
    - Response includes entity type, start, end, score fields
  - **GREEN**: Create `nem.Classification/sidecar/presidio/`:
    - `Dockerfile` — based on `mcr.microsoft.com/presidio-analyzer` (MIT licensed)
    - `main.py` — FastAPI wrapper (same pattern as PaddleOCR sidecar in KnowHub):
      - POST `/analyze` — accept text + language, return PII entities
      - GET `/health` — health check
      - GET `/supported-entities` — list configured entity types
    - `requirements.txt` — fastapi, uvicorn, presidio-analyzer, presidio-anonymizer
    - `docker-compose.presidio.yml` — presidio service definition with health check
    - Configure for 5 core PII types only: PERSON, EMAIL_ADDRESS, PHONE_NUMBER, CREDIT_CARD, IBAN_CODE
    - Confidence threshold: 0.7
  - **REFACTOR**: Ensure sidecar matches PaddleOCR sidecar pattern exactly (Dockerfile structure, health check, error handling)

  **Must NOT do**:
  - Do NOT add PII types beyond the 5 core types
  - Do NOT add anonymization/masking endpoints (detection only)
  - Do NOT integrate with nem.Classification service code (T7 does that)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Docker + small Python FastAPI wrapper — follows established PaddleOCR sidecar pattern closely
  - **Skills**: []
    - No specialized skills needed — Python/Docker boilerplate
  - **Skills Evaluated but Omitted**:
    - `playwright`: No UI

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with T1, T2, T4, T5, T29)
  - **Blocks**: T7, T27
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `nem.KnowHub-enhancement-ocr/infrastructure/paddleocr-server/main.py` — FastAPI sidecar pattern (health, analyze endpoint, error handling, Dockerfile)
  - `nem.KnowHub-enhancement-ocr/infrastructure/paddleocr-server/Dockerfile` — Python sidecar Docker build pattern
  - `nem.KnowHub-enhancement-ocr/docker-compose.yml` — Sidecar compose integration pattern (how OCR sidecar is wired into docker-compose with healthcheck and depends_on)

  **External References**:
  - Microsoft Presidio Analyzer docs: https://microsoft.github.io/presidio/analyzer/ — API reference for entity recognition
  - Presidio Docker image: `mcr.microsoft.com/presidio-analyzer` — official Microsoft container (MIT license)

  **WHY Each Reference Matters**:
  - PaddleOCR sidecar: EXACT pattern to follow — same health check structure, same error response format, same Dockerfile multi-stage approach
  - Presidio docs: Needed for correct `AnalyzerEngine` configuration (language, entity types, threshold)

  **Acceptance Criteria**:
  - [x] `docker compose -f nem.Classification/sidecar/presidio/docker-compose.presidio.yml build` → builds successfully
  - [x] `docker compose -f ... up -d && curl http://localhost:5050/health` → 200 OK
  - [x] POST `/analyze` with email text → returns EMAIL_ADDRESS entity with score >= 0.7
  - [x] POST `/analyze` with clean text (no PII) → returns empty array
  - [x] GET `/supported-entities` returns exactly 5 types

  **QA Scenarios**:

  ```
  Scenario: Presidio detects email PII
    Tool: Bash (docker compose + curl)
    Preconditions: Docker available, presidio image built
    Steps:
      1. Run `docker compose -f nem.Classification/sidecar/presidio/docker-compose.presidio.yml up -d`
      2. Wait for health: `until curl -sf http://localhost:5050/health; do sleep 2; done` (timeout 60s)
      3. Run `curl -s -X POST http://localhost:5050/analyze -H "Content-Type: application/json" -d '{"text":"Contact me at john.doe@example.com or call 555-123-4567","language":"en"}'`
      4. Assert response JSON array contains entity with `"entity_type":"EMAIL_ADDRESS"` and `"score">=0.7`
      5. Assert response JSON array contains entity with `"entity_type":"PHONE_NUMBER"` and `"score">=0.7`
    Expected Result: Both EMAIL_ADDRESS and PHONE_NUMBER detected with high confidence
    Failure Indicators: Empty response, entity types missing, scores below 0.7
    Evidence: .sisyphus/evidence/nem-classification-comms/task-3-presidio-pii-detection.txt

  Scenario: Presidio returns empty for clean text
    Tool: Bash (curl)
    Preconditions: Presidio container running from previous scenario
    Steps:
      1. Run `curl -s -X POST http://localhost:5050/analyze -H "Content-Type: application/json" -d '{"text":"The weather is nice today","language":"en"}'`
      2. Assert response is empty array `[]` or array with 0 items
    Expected Result: No PII entities detected in clean text
    Failure Indicators: Non-empty response, false positives
    Evidence: .sisyphus/evidence/nem-classification-comms/task-3-presidio-clean-text.txt
  ```

  **Commit**: YES
  - Message: `feat(classification): add Presidio PII detection sidecar`
  - Files: `nem.Classification/sidecar/presidio/**`
  - Pre-commit: `docker compose -f nem.Classification/sidecar/presidio/docker-compose.presidio.yml build`

- [x] 4. nem.Comms Service Scaffolding

  **What to do**:
  - **RED**: Write xunit test that verifies:
    - `Comms.Api` project targets net10.0, builds, starts as Minimal API
    - `/health` returns 200 with `{"status":"Healthy"}`
    - DI container resolves `IChannelRouter` interface
    - Swagger/OpenAPI at `/swagger`
    - PostgreSQL connection configured (can use Testcontainers)
    - Wolverine + RabbitMQ configured (handler discovery)
  - **GREEN**: Scaffold new `nem.Comms/` solution:
    - `nem.Comms.sln` — solution file
    - `src/Comms.Api/` — ASP.NET Core Minimal API (Program.cs with Keycloak, Serilog, Wolverine, health checks, `services.AddNemSecrets(configuration)` for OpenBao secret resolution)
    - `src/Comms.Domain/` — domain interfaces (IChannelRouter, IChannelAdapter, IDeliveryManager)
    - `src/Comms.Infrastructure/` — infrastructure stubs (Marten persistence, RabbitMQ)
    - `src/Comms.Application/` — application services (CQRS stubs)
    - `tests/Comms.Tests/` — xunit test project
    - `Dockerfile` and `.dockerignore`
    - Marten configuration for PostgreSQL (own database `nem_comms`)
    - Wolverine configuration for RabbitMQ with dedicated exchanges/queues
  - **REFACTOR**: Match nem.Mimir-typed-ids solution structure and Wolverine configuration patterns

  **Must NOT do**:
  - Do NOT implement channel adapters (T17-T23)
  - Do NOT implement routing logic (T19)
  - Do NOT add Conversation or Message domain models (Mimir owns those)
  - Do NOT implement federation logic (routing/delivery are later tasks)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: More complex scaffolding than Classification — includes Wolverine, Marten, RabbitMQ config
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No UI

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with T1, T2, T3, T5, T29)
  - **Blocks**: T6, T16, T17, T18, T19, T20, T21, T22, T23, T24, T25
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `nem.Mimir-typed-ids/src/Mimir.Api/Program.cs` — Full Minimal API setup (Keycloak, Serilog, Wolverine, Marten, health checks)
  - `nem.Mimir-typed-ids/src/Mimir.Sync/Configuration/WolverineConfiguration.cs` — RabbitMQ + Wolverine bus topology
  - `nem.Mimir-typed-ids/src/Mimir.Infrastructure/DependencyInjection.cs` — EF Core / PostgreSQL setup pattern (AddDbContext, UseNpgsql, connection string config)
  - `nem.Mimir-typed-ids/nem.Mimir.sln` — Solution structure pattern
  - `nem.Contracts/src/nem.Contracts.AspNetCore/Secrets/NemSecretsExtensions.cs` — `AddNemSecrets(configuration)` one-liner DI registration for OpenBao/fallback secrets
  - `nem.Contracts/src/nem.Contracts.AspNetCore/Secrets/ISecretProvider.cs` — Interface for resolving secrets: `GetSecretAsync(path, key)` — use for DB connection strings

  **API/Type References**:
  - `IChannelRouter` — to be defined: routes inbound messages to correct handler/conversation
  - `IChannelAdapter` — base adapter interface (aligns with existing IChannelEventSource/IChannelMessageSender in nem.Contracts)
  - `IDeliveryManager` — retry + DLQ management interface

  **WHY Each Reference Matters**:
  - `Mimir.Api/Program.cs`: The gold standard for nem.* service setup — auth, logging, bus, persistence must all be configured identically
  - `WolverineConfiguration.cs`: Bus topology (exchanges, queues, durability) must match the established pattern
  - `DependencyInjection.cs`: EF Core / PostgreSQL setup pattern — AddDbContext, UseNpgsql, connection string injection — adapt for Marten's `AddMarten(opts => ...)` if choosing Marten, or follow EF Core pattern directly

  **Acceptance Criteria**:
  - [x] `dotnet build nem.Comms/nem.Comms.sln` → 0 warnings, 0 errors
  - [x] `dotnet test nem.Comms/tests/` → scaffolding tests pass
  - [x] `docker build -f nem.Comms/src/Comms.Api/Dockerfile .` → image builds
  - [x] Health endpoint test passes
  - [x] Wolverine handler discovery configured (even with 0 handlers)

  **QA Scenarios**:

  ```
  Scenario: Comms service starts and responds healthy
    Tool: Bash (dotnet run + curl)
    Preconditions: nem.Comms.sln builds successfully
    Steps:
      1. Run `dotnet run --project nem.Comms/src/Comms.Api/ --urls http://localhost:5200 &`
      2. Wait 5 seconds for startup
      3. Run `curl -s http://localhost:5200/health`
      4. Assert response contains "Healthy"
      5. Kill background process
    Expected Result: HTTP 200, healthy status
    Failure Indicators: Connection refused, startup crash, unhealthy status
    Evidence: .sisyphus/evidence/nem-classification-comms/task-4-comms-health.txt

  Scenario: Comms Docker image builds
    Tool: Bash (docker build)
    Preconditions: Dockerfile exists at nem.Comms/src/Comms.Api/Dockerfile
    Steps:
      1. Run `docker build -f nem.Comms/src/Comms.Api/Dockerfile -t nem-comms:test .`
      2. Assert exit code 0
      3. Run `docker images nem-comms:test` and verify image exists
    Expected Result: Docker image builds successfully
    Failure Indicators: Build errors, missing dependencies, wrong base image
    Evidence: .sisyphus/evidence/nem-classification-comms/task-4-comms-docker-build.txt
  ```

  **Commit**: YES
  - Message: `feat(comms): scaffold nem.Comms federated communication service`
  - Files: `nem.Comms/**`
  - Pre-commit: `dotnet build nem.Comms/nem.Comms.sln`

- [x] 5. OPA Classification Policy Definitions

  **What to do**:
  - **RED**: Write OPA policy unit tests (Rego test files) that verify:
    - `classification.rego` (package `nem.mcp.controlplane.classification`): `allow` is false when level >= Confidential and destination is external
    - `classification.rego`: `allow` is true when level is Public or Internal for any destination
    - `classification.rego`: `allow` is true when level >= Confidential and destination is internal (e.g., Ollama)
    - `llm_gating.rego` (package `nem.mcp.controlplane.llm_gating`): blocks external LLM requests for Confidential+ data
    - `llm_gating.rego`: allows external LLM requests for Public/Internal data
    - PII-flagged data: blocks external even if level is Internal (when pii_gating_strict=true)
    - Tenant-scoped overrides work (tenant can set stricter but not looser policies)
  - **GREEN**: Create OPA policy files following existing `nem.mcp.controlplane.*` package convention:
    - `nem.MCP/policies/classification.rego` — `package nem.mcp.controlplane.classification` — main classification gating policy
    - `nem.MCP/policies/llm_gating.rego` — `package nem.mcp.controlplane.llm_gating` — LLM-specific gating (imports classification)
    - `nem.MCP/policies/classification_test.rego` — Rego unit tests for classification
    - `nem.MCP/policies/llm_gating_test.rego` — Rego unit tests for llm_gating
    - Define input schema matching PolicyEvaluationService format: `input.classification_level`, `input.has_pii`, `input.destination_type` (internal/external), `input.tenant_id`
    - Structure: `default allow := false` then `allow if { conditions }` blocks (same as `data_access.rego`, `audit_log.rego`)
    - Default policy: deny external access for Confidential and above
    - Tenant override mechanism via `data.tenants[tenant_id].classification_policy`
    - OPA evaluation path: `PolicyEvaluationService` queries `/v1/data/nem.mcp.controlplane.classification/allow` and `/v1/data/nem.mcp.controlplane.llm_gating/allow`
  - **REFACTOR**: Ensure policy naming and structure matches existing `data_access.rego` (`package nem.mcp.controlplane.data_access`) and `audit_log.rego` (`package nem.mcp.controlplane.audit_log`)

  **Must NOT do**:
  - Do NOT modify existing OPA policies (data_access.rego, audit_log.rego)
  - Do NOT add OPA server/deployment changes (that's infrastructure)
  - Do NOT implement dynamic policy loading (use static Rego for now)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: OPA Rego policy requires careful logic — classification hierarchies, tenant scoping, test coverage
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No UI

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with T1, T2, T3, T4, T29)
  - **Blocks**: T9, T10, T11, T13, T14
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `nem.MCP/policies/data_access.rego` — Existing OPA policy structure, naming conventions, input schema
  - `nem.MCP/policies/audit_log.rego` — Secondary policy example, shows how policies compose
  - `nem.MCP/services/nem.MCP.Infrastructure/Policies/PolicyEvaluationService.cs` — How .NET evaluates OPA policies (input format must match)

  **External References**:
  - OPA Rego language reference: https://www.openpolicyagent.org/docs/latest/policy-language/
  - OPA testing: https://www.openpolicyagent.org/docs/latest/policy-testing/

  **WHY Each Reference Matters**:
  - `data_access.rego`: Must follow same input structure convention so PolicyEvaluationService can evaluate classification policies without code changes
  - `PolicyEvaluationService.cs`: Shows the exact JSON input format that .NET sends to OPA — classification policies must accept this shape

  **Acceptance Criteria**:
  - [x] `opa test nem.MCP/policies/ -v` → all classification and llm_gating tests pass
  - [x] Confidential + external → deny
  - [x] Public + external → allow
  - [x] Confidential + internal (Ollama) → allow
  - [x] Tenant override (stricter) works
  - [x] Tenant override (looser than default) is rejected

  **QA Scenarios**:

  ```
  Scenario: OPA classification policies pass all tests
    Tool: Bash (opa test)
    Preconditions: opa CLI available (install if needed via `curl -L -o /usr/local/bin/opa https://...`)
    Steps:
      1. Run `opa test nem.MCP/policies/ -v --format pretty`
      2. Verify all tests in classification_test.rego pass
      3. Verify all tests in llm_gating_test.rego pass
      4. Count total tests >= 7 (matching the RED test list)
    Expected Result: All OPA policy tests pass, 0 failures
    Failure Indicators: Any FAIL line in output, undefined references
    Evidence: .sisyphus/evidence/nem-classification-comms/task-5-opa-policy-tests.txt

  Scenario: LLM gating blocks Confidential data to external
    Tool: Bash (opa eval)
    Preconditions: Policy files exist at nem.MCP/policies/
    Steps:
      1. Run `opa eval -d nem.MCP/policies/ -i <(echo '{"classification_level":"Confidential","has_pii":false,"destination_type":"external","tenant_id":"t1"}') "data.nem.mcp.controlplane.llm_gating.allow"`
      2. Assert result is `false`
      3. Run `opa eval -d nem.MCP/policies/ -i <(echo '{"classification_level":"Public","has_pii":false,"destination_type":"external","tenant_id":"t1"}') "data.nem.mcp.controlplane.llm_gating.allow"`
      4. Assert result is `true`
    Expected Result: Confidential blocked, Public allowed for external LLM
    Failure Indicators: Confidential allowed externally, Public blocked
    Evidence: .sisyphus/evidence/nem-classification-comms/task-5-opa-llm-gating-eval.txt
  ```

  **Commit**: YES
  - Message: `feat(policies): add OPA classification and LLM gating policies`
  - Files: `nem.MCP/policies/classification.rego`, `nem.MCP/policies/llm_gating.rego`, `nem.MCP/policies/*_test.rego`
  - Pre-commit: `opa test nem.MCP/policies/ -v`

- [x] 6. nem.Comms Domain Model + Persistence

  **What to do**:
  - **RED**: Write xunit tests that verify:
    - `ChannelSession` entity: create, add participants, track channel type + state
    - `ChannelIdentityLink` entity: link platform user ID → federated identity
    - `Participant` value object: name, role (Operator/Customer/Bot), channel identity
    - `RoutingState` value object: current assignment, queue position, priority
    - Marten document storage: save/retrieve ChannelSession, query by channel type
    - `IChannelSessionRepository` interface with basic CRUD + query methods
  - **GREEN**: Create in `nem.Comms/src/Comms.Domain/`:
    - `Entities/ChannelSession.cs` — aggregate root: Id, ChannelType, ExternalChannelId, Participants, RoutingState, TenantId, CreatedAt, Status
    - `Entities/ChannelIdentityLink.cs` — links platform user (e.g., Telegram userId) to federated participant
    - `ValueObjects/Participant.cs` — immutable record: Name, Role, ChannelIdentity, FederatedId
    - `ValueObjects/RoutingState.cs` — immutable record: AssignedOperatorId, QueueName, Priority, AssignedAt
    - `Repositories/IChannelSessionRepository.cs` — async CRUD + queries
    - Create in `nem.Comms/src/Comms.Infrastructure/Persistence/`:
    - `MartenChannelSessionRepository.cs` — Marten implementation of IChannelSessionRepository
    - `CommsMartenConfiguration.cs` — Marten document store config for Comms entities

  **Must NOT do**:
  - Do NOT add Conversation or Message models (Mimir owns those)
  - Do NOT implement routing logic (T19)
  - Do NOT add federation signaling or cross-channel linking logic yet
  - Do NOT add event sourcing events yet (pure document store for now)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Domain modeling + Marten persistence — moderate complexity, multiple entities + repository
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No UI

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with T7, T9, T10, T11, T12, T30)
  - **Blocks**: T16, T17, T18, T19, T20, T21, T22, T23, T24, T25
  - **Blocked By**: T4 (needs Comms solution scaffolding)

  **References**:

  **Pattern References**:
  - `nem.Mimir-typed-ids/src/Mimir.Domain/Entities/Conversation.cs` — Aggregate root pattern in nem.* (Id, TenantId, timestamps, status)
  - `nem.Mimir-typed-ids/src/Mimir.Domain/Entities/Message.cs` — Entity pattern with value objects
  - `nem.Mimir-typed-ids/src/Mimir.Infrastructure/DependencyInjection.cs` — EF Core / PostgreSQL persistence setup pattern (AddDbContext, UseNpgsql, connection strings)
  - `nem.Contracts/src/nem.Contracts/Channels/ChannelType.cs` — Reuse existing ChannelType enum
  - `nem.Contracts/src/nem.Contracts.AspNetCore/Secrets/ISecretProvider.cs` — Use `ISecretProvider.GetSecretAsync("services/comms", "db-connection-string")` for PostgreSQL connection strings instead of raw `IConfiguration`
  - `nem.Contracts/src/nem.Contracts.AspNetCore/Secrets/FallbackSecretProvider.cs` — Pattern: tries OpenBao first, falls back to appsettings.json

  **API/Type References**:
  - ChannelSession owns: routing, participants, channel binding. Does NOT own: conversation content, message history
  - Boundary: nem.Comms sends `ChannelEventReceivedIntegrationEvent` (shared contract from nem.Contracts) on bus → Mimir creates/updates Conversation

  **WHY Each Reference Matters**:
  - `Conversation.cs`: Domain entity pattern — how aggregates are structured (Id generation, invariants, state transitions)
  - `DependencyInjection.cs`: Persistence registration pattern — adapt AddDbContext/UseNpgsql for Marten's `AddMarten(opts => ...)` with connection strings, serialization, and identity strategy

  **Acceptance Criteria**:
  - [x] `dotnet test nem.Comms/tests/ --filter "Domain"` → all domain model tests pass
  - [x] `ChannelSession` has TenantId, ChannelType, Participants, RoutingState properties
  - [x] `ChannelIdentityLink` can map Telegram userId → federated participant
  - [x] Marten persistence test: save + retrieve ChannelSession (via Testcontainers PostgreSQL)

  **QA Scenarios**:

  ```
  Scenario: Domain model unit tests pass
    Tool: Bash (dotnet test)
    Preconditions: nem.Comms solution builds
    Steps:
      1. Run `dotnet test nem.Comms/tests/ --filter "Domain" --logger "console;verbosity=detailed"`
      2. Verify all tests pass for ChannelSession, ChannelIdentityLink, Participant, RoutingState
      3. Count at least 6 passing tests
    Expected Result: All domain model tests pass, entities correctly constructed
    Failure Indicators: Test failures, missing properties, null reference exceptions
    Evidence: .sisyphus/evidence/nem-classification-comms/task-6-domain-model-tests.txt

  Scenario: Marten persistence roundtrip
    Tool: Bash (dotnet test with Testcontainers)
    Preconditions: Docker available for Testcontainers PostgreSQL
    Steps:
      1. Run `dotnet test nem.Comms/tests/ --filter "Persistence" --logger "console;verbosity=detailed"`
      2. Verify ChannelSession save/retrieve test passes
      3. Verify query by ChannelType test passes
    Expected Result: Marten correctly stores and retrieves Comms domain entities
    Failure Indicators: Connection errors, serialization failures, missing Marten config
    Evidence: .sisyphus/evidence/nem-classification-comms/task-6-marten-persistence.txt
  ```

  **Commit**: YES (groups with T4)
  - Message: `feat(comms): add domain model and Marten persistence`
  - Files: `nem.Comms/src/Comms.Domain/**`, `nem.Comms/src/Comms.Infrastructure/Persistence/**`, `nem.Comms/tests/**`
  - Pre-commit: `dotnet build nem.Comms/nem.Comms.sln && dotnet test nem.Comms/tests/`

### Wave 2 — Classification Core (engine, API, middleware, audit)

- [x] 7. Classification Engine + Presidio Integration

  **What to do**:
  - **RED**: Write xunit tests:
    - `ClassificationEngine.ClassifyAsync()` with text containing PII → returns ClassificationResult with HasPii=true, PiiEntities=["EMAIL_ADDRESS"]
    - `ClassificationEngine.ClassifyAsync()` with annotated entity → returns level from DataClassificationAttribute
    - `ClassificationEngine.ClassifyAsync()` with no annotation and no PII → returns default Confidential (fail-closed)
    - Presidio HTTP client: mock Presidio response, verify entity extraction
    - Confidence threshold: entities below 0.7 score filtered out
    - Multiple PII types detected simultaneously
  - **GREEN**: Implement in `nem.Classification/`:
    - `src/Classification.Infrastructure/Presidio/PresidioClient.cs` — typed HttpClient to Presidio sidecar
    - `src/Classification.Infrastructure/Presidio/PresidioPiiDetector.cs` — implements `IPiiDetector`, calls PresidioClient, filters by threshold
    - `src/Classification.Application/ClassificationEngine.cs` — implements `IClassificationEngine`:
      1. Check DataClassificationAttribute on entity type → explicit level
      2. Call IPiiDetector for PII scan → set HasPii flag
      3. Apply rules: if PII detected and level < Restricted, escalate to Restricted
      4. Default = Confidential if no explicit annotation
      5. Return ClassificationResult with level, hasPii, piiEntities, source, timestamp
    - `src/Classification.Domain/IPiiDetector.cs` — interface for PII detection
    - DI registration in `Classification.Api/Program.cs`
  - **REFACTOR**: Ensure HttpClient uses `IHttpClientFactory` pattern, retry with Polly

  **Must NOT do**:
  - Do NOT expose REST endpoints (T8 does that)
  - Do NOT add human-override logic (later task)
  - Do NOT implement caching (optimize later)
  - Do NOT add classification storage/persistence (T12)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Core business logic — classification algorithm, Presidio integration, rule engine
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No UI

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with T6, T9, T10, T11, T12, T30)
  - **Blocks**: T8, T13, T14, T15
  - **Blocked By**: T1 (classification types), T2 (service scaffolding), T3 (Presidio sidecar)

  **References**:

  **Pattern References**:
  - `nem.KnowHub/services/KnowHub.Embedding/Services/OpenAiEmbeddingService.cs` — Typed HttpClient + IHttpClientFactory pattern for external service calls
  - `nem.KnowHub-enhancement-ocr/plugins/nem.KnowHub.Plugins.Ocr/Engines/PaddleOcrEngine.cs` — HTTP sidecar client pattern (exact match for Presidio integration: HttpClient → sidecar endpoint, health check, error handling)
  - `nem.KnowHub/services/KnowHub.Infrastructure/Services/AuditLogService.cs` — Service implementation pattern with DI

  **API/Type References**:
  - Presidio analyze endpoint: POST /analyze → `[{"entity_type":"EMAIL_ADDRESS","start":0,"end":20,"score":0.95}]`
  - `ClassificationResult` from T1: Level, HasPii, PiiEntities, Source, Timestamp

  **WHY Each Reference Matters**:
  - `PaddleOcrEngine.cs`: Exact pattern for HTTP sidecar integration — health check, retry, error handling
  - `OpenAiEmbeddingService.cs`: Shows typed HttpClient with DI registration + Polly resilience

  **Acceptance Criteria**:
  - [x] `dotnet test nem.Classification/tests/ --filter "Engine"` → all classification engine tests pass
  - [x] PII text → HasPii=true with correct entity types
  - [x] Non-PII text → HasPii=false, empty PiiEntities
  - [x] Unannotated entity → default Confidential
  - [x] Below-threshold PII scores filtered out

  **QA Scenarios**:

  ```
  Scenario: Classification engine detects PII and returns correct result
    Tool: Bash (dotnet test)
    Preconditions: nem.Classification builds, Presidio sidecar mockable
    Steps:
      1. Run `dotnet test nem.Classification/tests/ --filter "ClassificationEngine" --logger "console;verbosity=detailed"`
      2. Verify test "ClassifyAsync_WithPiiText_ReturnsHasPiiTrue" passes
      3. Verify test "ClassifyAsync_WithCleanText_ReturnsDefaultConfidential" passes
      4. Verify test "ClassifyAsync_BelowThreshold_FiltersOut" passes
    Expected Result: All engine tests pass, classification logic correct
    Failure Indicators: Wrong classification level, PII not detected, threshold not applied
    Evidence: .sisyphus/evidence/nem-classification-comms/task-7-engine-tests.txt

  Scenario: Engine handles Presidio unavailability gracefully
    Tool: Bash (dotnet test)
    Preconditions: Presidio client mock returns HTTP 503
    Steps:
      1. Run test "ClassifyAsync_PresidioUnavailable_ReturnsDefaultWithWarning"
      2. Verify result has default Confidential level
      3. Verify HasPii is null or false (not crash)
    Expected Result: Fail-closed — returns Confidential when Presidio is down, does not throw
    Failure Indicators: Unhandled exception, returns Public, crash
    Evidence: .sisyphus/evidence/nem-classification-comms/task-7-engine-presidio-unavailable.txt
  ```

  **Commit**: YES
  - Message: `feat(classification): implement classification engine with Presidio PII detection`
  - Files: `nem.Classification/src/Classification.Application/ClassificationEngine.cs`, `nem.Classification/src/Classification.Infrastructure/Presidio/*`, `nem.Classification/src/Classification.Domain/IPiiDetector.cs`, `nem.Classification/tests/**`
  - Pre-commit: `dotnet test nem.Classification/tests/`

- [x] 8. Classification REST API

  **What to do**:
  - **RED**: Write integration tests:
    - POST `/api/v1/classify` with `{"text":"email is test@test.com","entityType":"Document","entityId":"doc-1"}` → 200 with ClassificationResult
    - POST `/api/v1/classify` with empty text → 400 validation error
    - GET `/api/v1/classification/{entityType}/{entityId}` → returns stored classification
    - GET `/api/v1/classification/{entityType}/{entityId}` for non-existent → 404
    - Authentication required (no Bearer token → 401)
    - Tenant isolation (TenantA cannot query TenantB's classifications)
  - **GREEN**: Implement in `Classification.Api`:
    - `Endpoints/ClassificationEndpoints.cs` — Minimal API endpoint mapping:
      - POST `/api/v1/classify` — classify text, store result, return ClassificationResult
      - GET `/api/v1/classification/{entityType}/{entityId}` — retrieve stored classification
      - POST `/api/v1/classify/batch` — batch classification for multiple entities
    - `Contracts/ClassifyRequest.cs` — request DTO with FluentValidation
    - `Contracts/ClassifyResponse.cs` — response DTO
    - `Services/IClassificationService.cs` — public interface with `ClassifyAsync(ClassifyRequest)`, `GetClassificationAsync(entityType, entityId)`, and `ClassifyBatchAsync(...)` methods. This is the contract that downstream consumers (e.g., T26 nem.Comms) will use via HTTP client to call the Classification API
    - `Services/ClassificationService.cs` — implementation wiring T7's engine + Presidio + persistence
    - Register endpoints and `IClassificationService` in Program.cs DI container
    - Add OpenAPI annotations for Swagger docs
  - **REFACTOR**: Ensure endpoint pattern matches nem.Mimir API endpoint style

  **Must NOT do**:
  - Do NOT implement human override endpoints (future task)
  - Do NOT add WebSocket/streaming endpoints
  - Do NOT implement classification caching

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: REST API with auth, validation, tenant isolation — standard but needs correctness
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with T13, T14, T16, T24)
  - **Blocks**: T15, T27
  - **Blocked By**: T2 (service scaffolding), T7 (classification engine)

  **References**:

  **Pattern References**:
  - `nem.MCP/services/nem.MCP.Api/Endpoints/Configuration/ConfigurationEndpoints.cs` — Minimal API endpoint group pattern: static `MapXxxEndpoints(this IEndpointRouteBuilder)` extension method, auth, validation, OpenAPI annotations
  - `nem.MCP/services/nem.MCP.Api/Endpoints/ServiceRegistry/ServiceRegistryEndpoints.cs` — Alternative endpoint group pattern with CRUD operations
  - `nem.Mimir-typed-ids/src/Mimir.Api/Program.cs` — Auth middleware + endpoint registration order
  - `nem.Contracts/src/nem.Contracts.AspNetCore/Secrets/ISecretProvider.cs` — Use `ISecretProvider.GetSecretAsync("services/classification", "db-connection-string")` for DB connection strings instead of raw `IConfiguration`

  **WHY Each Reference Matters**:
  - `ConfigurationEndpoints.cs`: Shows how to structure Minimal API endpoint groups with auth requirements, parameter binding, validation, and Swagger annotations — copy this pattern exactly for ClassificationEndpoints
  - `Program.cs`: Middleware order (auth before endpoints) must match

  **Acceptance Criteria**:
  - [x] POST `/api/v1/classify` with PII text → 200 with correct ClassificationResult
  - [x] POST `/api/v1/classify` with empty text → 400
  - [x] No auth token → 401
  - [x] Cross-tenant query → 403 or empty result
  - [x] Swagger UI shows all endpoints at `/swagger`

  **QA Scenarios**:

  ```
  Scenario: Classify endpoint returns correct result
    Tool: Bash (dotnet run + curl)
    Preconditions: Classification service running with mock Presidio, NO Keycloak required
    Steps:
      1. Start service in Development mode: `ASPNETCORE_ENVIRONMENT=Development dotnet run --project nem.Classification/src/Classification.Api/ &`
         NOTE: In Development mode, configure JWT validation to accept a self-signed test token.
         Add to `appsettings.Development.json`: `"Authentication": {"ValidateIssuer": false, "ValidateAudience": false}`
         OR use TestServer/WebApplicationFactory in-process (preferred for unit-level QA).
      2. Generate a self-signed test JWT: `TOKEN=$(dotnet run --project nem.Classification/tests/Classification.Tests/ -- generate-test-token)` — test project includes a `JwtTestHelper` that creates valid tokens with test signing key matching Development config.
         Alternatively, if using WebApplicationFactory: skip external curl, call via `HttpClient` from test host.
      3. Run `curl -s -X POST http://localhost:5100/api/v1/classify -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"text":"My email is test@test.com","entityType":"Document","entityId":"doc-1"}'`
      4. Assert response has `"level":"Confidential"` or higher, `"hasPii":true`
      5. Assert response has `"piiEntities"` array containing "EMAIL_ADDRESS"
    Expected Result: 200 OK with correct classification result
    Failure Indicators: 500 error, wrong level, PII not detected
    Evidence: .sisyphus/evidence/nem-classification-comms/task-8-classify-endpoint.txt
    NOTE: Full Keycloak integration auth testing deferred to T27 (Docker Compose) and F3 (Final QA).

  Scenario: Unauthenticated request rejected
    Tool: Bash (curl)
    Preconditions: Service running (any environment — auth middleware always active)
    Steps:
      1. Run `curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:5100/api/v1/classify -H "Content-Type: application/json" -d '{"text":"test","entityType":"Doc","entityId":"1"}'`
      2. Assert HTTP status is 401
    Expected Result: 401 Unauthorized
    Failure Indicators: 200 OK (auth bypass), 500 error
    Evidence: .sisyphus/evidence/nem-classification-comms/task-8-auth-check.txt
  ```

  **Commit**: YES (groups with T7)
  - Message: `feat(classification): add classification REST API endpoints`
  - Files: `nem.Classification/src/Classification.Api/Endpoints/*`, `nem.Classification/src/Classification.Api/Contracts/*`, `nem.Classification/tests/**`
  - Pre-commit: `dotnet test nem.Classification/tests/`

- [x] 9. DataClassificationMiddleware for HTTP

  **What to do**:
  - **RED**: Write xunit tests:
    - Middleware extracts classification context from request headers (`X-Classification-Level`, `X-Has-Pii`)
    - Middleware calls IClassificationContext to populate context for downstream
    - Middleware blocks request (403) when classification level exceeds endpoint policy
    - Middleware allows request when classification level is within policy
    - Missing classification header → defaults to Confidential (fail-closed)
    - Audit-only mode: logs violation but allows request through
  - **GREEN**: Implement in `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/`:
    - `DataClassificationMiddleware.cs` — follows `OpaAuthorizationHandler.cs` pattern EXACTLY:
      - Extract classification context from headers or request body
      - Evaluate against OPA classification policy via local `OpaClassificationClient.cs` (lightweight HTTP client calling OPA at `/v1/data/nem/mcp/controlplane/classification/allow` — matches T5's `package nem.mcp.controlplane.classification` exactly; do NOT reuse MCP-internal `PolicyEvaluationService` which is not a shared contract)
      - Block or allow based on policy result
      - Support audit-only mode (configurable toggle)
    - `OpaClassificationClient.cs` — lightweight OPA HTTP client in `nem.Contracts.AspNetCore/Classification/` that POSTs `{ input: { level, hasPii, destination, ... } }` to OPA at `/v1/data/nem/mcp/controlplane/classification/allow` (matching T5's package `nem.mcp.controlplane.classification`) and parses `{ result: { allow: bool, reasons: [] } }`. Follows the same HTTP pattern as `PolicyEvaluationService.cs` but lives in the shared contracts package so all services can use it
    - `DataClassificationExtensions.cs` — `services.AddDataClassification()` + `app.UseDataClassification()`
    - `ClassificationContext.cs` — implements `IClassificationContext`, scoped per request
    - `DataClassificationOptions.cs` — config: AuditOnlyMode, DefaultLevel, PolicyName
  - **REFACTOR**: Ensure registration extension methods match OpaAuthorizationExtensions.cs exactly

  **Must NOT do**:
  - Do NOT modify OpaAuthorizationHandler.cs
  - Do NOT add classification logic (reuse engine via HTTP call or shared lib)
  - Do NOT add WebSocket classification support

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Cross-cutting middleware with OPA integration — must follow OpaAuthorizationHandler pattern precisely
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with T6, T7, T10, T11, T12, T30)
  - **Blocks**: T26
  - **Blocked By**: T1 (classification types), T5 (OPA policies)

  **References**:

  **Pattern References**:
  - `nem.Contracts/src/nem.Contracts.AspNetCore/Authorization/OpaAuthorizationHandler.cs` — **THE** canonical pattern. Follow line-by-line: constructor injection, HandleRequirementAsync, policy evaluation, fail-closed default
  - `nem.Contracts/src/nem.Contracts.AspNetCore/Authorization/OpaAuthorizationExtensions.cs` — Extension method pattern: `AddOpaAuthorization()` → mirror with `AddDataClassification()`
  - `nem.Contracts/src/nem.Contracts.AspNetCore/RateLimiting/TokenBucketRateLimiter.cs` — Alternative cross-cutting concern middleware pattern

  **API/Type References**:
  - `nem.MCP/services/nem.MCP.Infrastructure/Policies/PolicyEvaluationService.cs`: **READ-ONLY reference** — study the OPA HTTP call pattern (`EvaluateAsync` → POST to `/v1/data/{package}/allow`, parse `result`). Do NOT import or depend on this class; instead, replicate the HTTP pattern in a new `OpaClassificationClient.cs` within `nem.Contracts.AspNetCore/Classification/`
  - `IClassificationContext` from T1: expose Level, HasPii in scoped context

  **WHY Each Reference Matters**:
  - `OpaAuthorizationHandler.cs`: This is NOT just a reference — it's the EXACT template. Same constructor pattern, same fail-closed logic, same extension method shape
  - `OpaAuthorizationExtensions.cs`: Registration pattern must be identical for developer familiarity
  - `PolicyEvaluationService.cs`: READ-ONLY pattern reference — the OPA HTTP call shape is identical but must be reimplemented locally since this class lives in MCP infrastructure and is not shared

  **Acceptance Criteria**:
  - [x] `dotnet build nem.Contracts/` → 0 errors including new Classification middleware
  - [x] Middleware test: request with `X-Classification-Level: Public` + endpoint policy Public → 200
  - [x] Middleware test: request with `X-Classification-Level: Confidential` + endpoint policy Public-only → 403
  - [x] Missing header → defaults to Confidential, blocks external endpoints
  - [x] Audit-only mode: would-be-blocked request → 200 + warning log

  **QA Scenarios**:

  ```
  Scenario: Middleware blocks over-classified request
    Tool: Bash (dotnet test)
    Preconditions: nem.Contracts solution builds with new middleware
    Steps:
      1. Run `dotnet test nem.Contracts/tests/ --filter "DataClassificationMiddleware" --logger "console;verbosity=detailed"`
      2. Verify test "BlocksRequestWhenClassificationExceedsPolicy" passes
      3. Verify test "AllowsRequestWhenClassificationWithinPolicy" passes
      4. Verify test "DefaultsToConfidentialWhenNoHeader" passes
    Expected Result: All middleware tests pass
    Failure Indicators: Blocked request allowed through, allowed request blocked
    Evidence: .sisyphus/evidence/nem-classification-comms/task-9-middleware-tests.txt

  Scenario: Audit-only mode logs but does not block
    Tool: Bash (dotnet test)
    Preconditions: DataClassificationOptions.AuditOnlyMode = true in test
    Steps:
      1. Run test "AuditOnlyMode_WouldBlockRequest_LogsWarningAndAllows"
      2. Verify request proceeds (200) despite classification violation
      3. Verify ILogger received Warning with classification violation details
    Expected Result: Request allowed, warning logged with violation details
    Failure Indicators: Request blocked in audit-only mode, no log emitted
    Evidence: .sisyphus/evidence/nem-classification-comms/task-9-audit-only-mode.txt
  ```

  **Commit**: YES
  - Message: `feat(contracts): add DataClassificationMiddleware for HTTP classification gating`
  - Files: `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/*`, `nem.Contracts/tests/**`
  - Pre-commit: `dotnet build nem.Contracts && dotnet test nem.Contracts/tests/`

- [x] 10. DataClassificationBehavior for Wolverine Messages

  **What to do**:
  - **RED**: Write xunit tests:
    - Wolverine behavior reads classification metadata from `Envelope.Headers` and propagates to `IMessageContext`
    - Missing classification metadata on messages → attach default Confidential level
    - Behavior NEVER blocks/rejects messages — always forwards to handler
    - Downstream handlers can read `IMessageContext.GetClassification()` for visibility/logging
    - Classification metadata round-trips correctly through publish → consume cycle
    - Audit log emitted when message has Restricted/Secret classification (observability)
  - **GREEN**: Implement in `nem.Contracts/src/nem.Contracts.Wolverine/Classification/`:
    - `DataClassificationBehavior.cs` — Wolverine `IMessageMiddleware`:
      - Read `Envelope.Headers["X-Classification-Level"]` and `["X-Has-Pii"]`
      - If missing, attach default (Confidential, HasPii=false) to envelope headers
      - Propagate classification metadata to `IMessageContext` for handler visibility
      - Log audit entry for Restricted/Secret messages (structured logging)
      - **ALWAYS forward message to next handler — NO blocking/gating/rejection**
    - `ClassificationWolverineExtensions.cs` — `opts.Policies.Add<DataClassificationBehavior>()`
    - Create new project `nem.Contracts/src/nem.Contracts.Wolverine/` if it doesn't exist (or add to existing)
  - **REFACTOR**: Align with existing Wolverine middleware patterns in nem.Messaging

  **Must NOT do**:
  - Do NOT block, reject, or gate any bus messages based on classification level (bus = internal trust boundary)
  - Do NOT modify existing Wolverine configuration in other services
  - Do NOT add serialization/deserialization changes to message types
  - Do NOT add `ClassificationPolicyAttribute` — no per-handler blocking policy (enrichment only)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Wolverine middleware pipeline — requires understanding of message envelope, middleware ordering, and bus semantics
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with T6, T7, T9, T11, T12, T30)
  - **Blocks**: T26
  - **Blocked By**: T1 (classification types), T5 (OPA policies)

  **References**:

  **Pattern References**:
  - `nem/src/nem.Messaging/Infrastructure/WolverineConfiguration.cs` — Wolverine middleware registration pattern (Policies.Add)
  - `nem.Mimir-typed-ids/src/Mimir.Sync/Configuration/WolverineConfiguration.cs` — Bus configuration with middleware policies
  - `nem/src/nem.Messaging/Infrastructure/Security/ITenantContext.cs` — Context propagation through message pipeline

  **External References**:
  - Wolverine middleware docs: https://wolverine.netlify.app/guide/handlers/middleware.html

  **WHY Each Reference Matters**:
  - `WolverineConfiguration.cs`: Shows exactly how to register middleware in the Wolverine pipeline — must follow same pattern
  - `ITenantContext.cs`: Shows how context (like tenant) propagates through messages — classification context follows same model

  **Acceptance Criteria**:
  - [x] `dotnet test` → all Wolverine classification behavior tests pass
  - [x] Behavior reads `X-Classification-Level` and `X-Has-Pii` from envelope headers
  - [x] Missing headers → default Confidential + HasPii=false attached to envelope
  - [x] Classification metadata propagated to `IMessageContext` for handler visibility
  - [x] Behavior NEVER blocks/rejects any message — all messages always forwarded
  - [x] Audit log emitted for Restricted/Secret classification messages (structured logging)

  **QA Scenarios**:

  ```
  Scenario: Wolverine behavior enriches message with classification metadata
    Tool: Bash (dotnet test)
    Preconditions: Tests with in-memory Wolverine host configured
    Steps:
      1. Run `dotnet test --filter "DataClassificationBehavior" --logger "console;verbosity=detailed"`
      2. Verify "EnrichesMessageWithClassificationHeaders" passes — message with X-Classification-Level=Internal → handler receives classification via IMessageContext
      3. Verify "AlwaysForwardsMessage_NeverBlocks" passes — messages at ALL classification levels (Public through Secret) are forwarded to handler
      4. Verify "PropagatesClassificationToMessageContext" passes — downstream handler can read GetClassification()
    Expected Result: All 3+ behavior tests pass, zero messages blocked
    Failure Indicators: Any message rejected/blocked, IMessageContext missing classification data
    Evidence: .sisyphus/evidence/nem-classification-comms/task-10-wolverine-behavior.txt

  Scenario: Missing classification defaults to Confidential (fail-closed enrichment)
    Tool: Bash (dotnet test)
    Preconditions: Message envelope has no classification headers
    Steps:
      1. Run test "MissingClassificationHeader_DefaultsToConfidential"
      2. Verify behavior attaches Confidential + HasPii=false to envelope headers
      3. Verify message is STILL forwarded to handler (NOT blocked)
      4. Verify handler can read default Confidential from IMessageContext
    Expected Result: Fail-closed default enriches unclassified messages, message is forwarded
    Failure Indicators: Message blocked instead of enriched, default not applied
    Evidence: .sisyphus/evidence/nem-classification-comms/task-10-wolverine-default.txt
  ```

  **Commit**: YES
  - Message: `feat(contracts): add DataClassificationBehavior for Wolverine message metadata enrichment`
  - Files: `nem.Contracts/src/nem.Contracts.Wolverine/Classification/*`, `nem.Contracts/tests/**`
  - Pre-commit: `dotnet test nem.Contracts/tests/`

- [x] 11. ClassificationGatingHandler — HttpClientFactory DelegatingHandler

  **What to do**:
  - **RED**: Write xunit tests:
    - DelegatingHandler intercepts outbound HTTP request to external service
    - If request carries Confidential+ data → blocks with `ClassificationGatingDeniedException` (HTTP 403 from handler)
    - If request carries Public/Internal data → forwards to inner handler
    - Classification extracted from `HttpRequestMessage.Options` or header
    - Audit-only mode: logs but forwards
    - Works with `IHttpClientFactory` typed clients
  - **GREEN**: Implement in `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/`:
    - `ClassificationGatingHandler.cs` — `DelegatingHandler`:
      - Override `SendAsync` to inspect classification context
      - Check if destination is external (configurable list of internal hosts/patterns)
      - Block if classification >= Confidential and destination is external
      - Return 403 response with `X-Classification-Gating-Denied` header and reason
    - `ClassificationGatingOptions.cs` — config: InternalHosts (list of patterns), AuditOnlyMode
    - `ClassificationGatingExtensions.cs` — `services.AddClassificationGating()` to register DelegatingHandler
    - Registration: `builder.AddHttpMessageHandler<ClassificationGatingHandler>()`
  - **REFACTOR**: Ensure DelegatingHandler can be added to any typed HttpClient via extension method

  **Must NOT do**:
  - Do NOT apply gating handler to ALL HttpClients automatically — only to explicitly configured ones
  - Do NOT modify existing HttpClient registrations in other services (T13, T14 do that)
  - Do NOT implement response classification (only outbound request gating)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: DelegatingHandler pipeline, HTTP interception, fail-closed gating logic
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with T6, T7, T9, T10, T12, T30)
  - **Blocks**: T13, T14
  - **Blocked By**: T1 (classification types), T5 (OPA policies)

  **References**:

  **Pattern References**:
  - `nem.KnowHub/services/KnowHub.Embedding/Services/OpenAiEmbeddingService.cs` — Typed HttpClient that will receive this handler (understand the client pattern)
  - `nem.Mimir/src/Mimir.Infrastructure/LiteLlm/LiteLlmClient.cs` — Second typed HttpClient target

  **External References**:
  - Microsoft DelegatingHandler docs: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/http-requests#outgoing-request-middleware

  **WHY Each Reference Matters**:
  - `OpenAiEmbeddingService.cs`: Shows how typed HttpClient is registered and used — DelegatingHandler must integrate without changing this code
  - `LiteLlmClient.cs`: Second integration point — same DelegatingHandler must work for both

  **Acceptance Criteria**:
  - [x] Handler test: Confidential data + external host → blocked (403), inner handler NOT called
  - [x] Handler test: Public data + external host → forwarded, inner handler called
  - [x] Handler test: Confidential data + internal host (Ollama) → forwarded
  - [x] Audit-only mode: would-block → forwards + logs warning
  - [x] `X-Classification-Gating-Denied` header present on blocked responses

  **QA Scenarios**:

  ```
  Scenario: Gating handler blocks Confidential to external LLM
    Tool: Bash (dotnet test)
    Preconditions: Tests with mock inner handler
    Steps:
      1. Run `dotnet test --filter "ClassificationGatingHandler" --logger "console;verbosity=detailed"`
      2. Verify "BlocksConfidentialToExternal" passes — inner handler NOT invoked
      3. Verify "AllowsPublicToExternal" passes — inner handler invoked
      4. Verify "AllowsConfidentialToInternal" passes — Ollama localhost allowed
    Expected Result: Gating correctly blocks/allows based on classification + destination
    Failure Indicators: Confidential data leaked to external, Public data blocked
    Evidence: .sisyphus/evidence/nem-classification-comms/task-11-gating-handler.txt

  Scenario: Gating handler returns proper denial response
    Tool: Bash (dotnet test)
    Preconditions: Handler configured to block
    Steps:
      1. Run test "BlockedResponse_Has403StatusAndDenialHeader"
      2. Assert HttpResponseMessage.StatusCode == 403
      3. Assert response contains header "X-Classification-Gating-Denied"
      4. Assert response body contains reason text mentioning classification level
    Expected Result: Clear denial response with diagnostic information
    Failure Indicators: Wrong status code, missing headers, empty body
    Evidence: .sisyphus/evidence/nem-classification-comms/task-11-gating-denial-response.txt
  ```

  **Commit**: YES
  - Message: `feat(contracts): add ClassificationGatingHandler for outbound HTTP classification gating`
  - Files: `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/ClassificationGatingHandler.cs`, `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/ClassificationGatingOptions.cs`, `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/ClassificationGatingExtensions.cs`, `nem.Contracts/tests/**`
  - Pre-commit: `dotnet test nem.Contracts/tests/`

- [x] 12. Classification Audit Trail Service

  **What to do**:
  - **RED**: Write xunit tests:
    - `ClassificationAuditService.LogClassificationAsync()` writes audit record with: entityType, entityId, level, hasPii, source, actor, timestamp
    - `ClassificationAuditService.LogGatingDecisionAsync()` writes gating audit: allowed/denied, destination, reason
    - Audit records stored via Marten document store
    - Query audit trail by entityId → returns chronological list
    - Query audit trail by time range → returns filtered results
    - Audit records are immutable (append-only)
  - **GREEN**: Implement in `nem.Classification/`:
    - `src/Classification.Domain/AuditTrail/ClassificationAuditRecord.cs` — immutable record: Id, EntityType, EntityId, Level, HasPii, Source, Actor, Timestamp, Decision, Destination, Reason
    - `src/Classification.Domain/AuditTrail/IClassificationAuditService.cs` — interface
    - `src/Classification.Application/AuditTrail/ClassificationAuditService.cs` — implementation using Marten
    - `src/Classification.Infrastructure/Persistence/AuditMartenConfiguration.cs` — Marten indexes for efficient querying
    - Register in DI container
    - Expose `IClassificationAuditService` so T7 (engine) and T9 (middleware) can inject and call it from their own code
  - **REFACTOR**: Follow AuditLogService pattern from KnowHub exactly. NOTE: T7 and T9 are responsible for calling `IClassificationAuditService` in their own implementations — T12 does NOT modify T7/T9 files

  **Must NOT do**:
  - Do NOT add audit record deletion or modification endpoints
  - Do NOT add real-time audit streaming (future feature)
  - Do NOT modify KnowHub's existing AuditLogService

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Marten persistence + audit patterns — moderate complexity following established pattern
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with T6, T7, T9, T10, T11, T30)
  - **Blocks**: —
  - **Blocked By**: T1 (classification types for IClassificationAuditService interface), T2 (service scaffolding)

  **References**:

  **Pattern References**:
  - `nem.KnowHub/services/KnowHub.Infrastructure/Services/AuditLogService.cs` — **THE** audit pattern: Serilog structured logging + Marten persistence
  - `nem.KnowHub/services/KnowHub.Api/Middleware/AuditLogMiddleware.cs` — How audit logging is wired into HTTP pipeline
  - `nem.Mimir-typed-ids/src/Mimir.Infrastructure/DependencyInjection.cs` — EF Core / PostgreSQL persistence + index configuration pattern

  **WHY Each Reference Matters**:
  - `AuditLogService.cs`: Exact pattern — dual write (Serilog for real-time, Marten for query). Classification audit must follow this
  - `AuditLogMiddleware.cs`: Shows how to wire audit into HTTP pipeline (same approach for classification audit)

  **Acceptance Criteria**:
  - [x] `dotnet test --filter "Audit"` → all audit tests pass
  - [x] Classification event creates audit record with all fields
  - [x] Gating decision creates audit record with allowed/denied status
  - [x] Query by entityId returns correct chronological records
  - [x] Audit records are append-only (no update/delete)

  **QA Scenarios**:

  ```
  Scenario: Classification creates audit record
    Tool: Bash (dotnet test with Testcontainers)
    Preconditions: PostgreSQL via Testcontainers, Marten configured
    Steps:
      1. Run `dotnet test nem.Classification/tests/ --filter "Audit" --logger "console;verbosity=detailed"`
      2. Verify "LogClassificationAsync_CreatesRecord" passes
      3. Verify "QueryByEntityId_ReturnsChronological" passes
      4. Verify record contains all fields: entityType, entityId, level, hasPii, source, actor, timestamp
    Expected Result: All audit tests pass, records correctly stored and queried
    Failure Indicators: Missing fields, wrong ordering, persistence errors
    Evidence: .sisyphus/evidence/nem-classification-comms/task-12-audit-tests.txt

  Scenario: Gating decision audit trail
    Tool: Bash (dotnet test)
    Preconditions: Audit service with Marten
    Steps:
      1. Run test "LogGatingDecisionAsync_Denied_RecordsReason"
      2. Verify record has Decision="Denied", Destination, Reason fields
      3. Run test "LogGatingDecisionAsync_Allowed_RecordsAllow"
    Expected Result: Both allow and deny decisions audited with context
    Failure Indicators: Missing reason on denials, missing destination
    Evidence: .sisyphus/evidence/nem-classification-comms/task-12-gating-audit.txt
  ```

  **Commit**: YES
  - Message: `feat(classification): add classification audit trail service`
  - Files: `nem.Classification/src/Classification.Domain/AuditTrail/*`, `nem.Classification/src/Classification.Application/AuditTrail/*`, `nem.Classification/src/Classification.Infrastructure/Persistence/AuditMartenConfiguration.cs`, `nem.Classification/tests/**`
  - Pre-commit: `dotnet test nem.Classification/tests/`

### Wave 3 — LLM Gating + Channel Edge (gating integration, migration, channel adapters)

- [x] 13. LLM Gating on LiteLlmClient

  **What to do**:
  - **RED**: Write xunit tests in nem.Mimir-typed-ids:
    - LiteLlmClient outbound HTTP has ClassificationGatingHandler in pipeline
    - Sending Confidential prompt to external LLM (OpenAI) → blocked (403), no HTTP call made
    - Sending Public prompt to external LLM → forwarded, response returned
    - Sending Confidential prompt to internal LLM (Ollama at localhost) → forwarded (internal trust)
    - Classification determined by classifying the prompt text BEFORE sending
    - Pre-stream classification: classify BEFORE streaming starts (decision made pre-flight)
  - **GREEN**: Modify nem.Mimir-typed-ids:
    - `src/Mimir.Infrastructure/LiteLlm/LiteLlmClientConfiguration.cs` — add ClassificationGatingHandler to HttpClient pipeline:
      ```csharp
      services.AddHttpClient<LiteLlmClient>()
              .AddHttpMessageHandler<ClassificationGatingHandler>();
      ```
    - `src/Mimir.Infrastructure/LiteLlm/LiteLlmClassificationInterceptor.cs` — pre-flight classification:
      - Before SendAsync: extract prompt text from request body
      - Call Classification service API (POST /api/v1/classify)
      - Attach classification result to HttpRequestMessage.Options
      - ClassificationGatingHandler reads from Options and gates
    - Configure internal hosts: `["localhost", "ollama", "litellm"]` in ClassificationGatingOptions
    - Update DI registration in Mimir.Api/Program.cs
  - **REFACTOR**: Minimal changes to existing LiteLlmClient — all logic in DelegatingHandler chain

  **Must NOT do**:
  - Do NOT modify LiteLlmClient.cs business logic directly
  - Do NOT add classification to response processing (only outbound)
  - Do NOT break existing LiteLLM integration tests
  - Do NOT hardcode external providers — use configurable host list

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: DelegatingHandler integration into existing typed HttpClient — must not break streaming, requires understanding of LiteLLM protocol
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with T8, T14, T16, T24)
  - **Blocks**: T28
  - **Blocked By**: T7 (classification engine), T9 (middleware), T11 (gating handler)

  **References**:

  **Pattern References**:
  - `nem.Mimir/src/Mimir.Infrastructure/LiteLlm/LiteLlmClient.cs` — THE target: typed HttpClient for LLM calls. Understand its request/response flow
  - `nem.Mimir-typed-ids/src/Mimir.Infrastructure/LiteLlm/LiteLlmClient.cs` — Typed-ID variant (primary target)
  - `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/ClassificationGatingHandler.cs` — The handler to wire in (from T11)
  - `nem.Mimir-typed-ids/src/Mimir.Api/Program.cs` — DI registration where HttpClient is configured

  **WHY Each Reference Matters**:
  - `LiteLlmClient.cs`: Must understand request format to extract prompt for pre-flight classification
  - `ClassificationGatingHandler.cs`: Must integrate without modification — only wire into HttpClient pipeline
  - `Program.cs`: DI registration point — where `.AddHttpMessageHandler<>()` goes

  **Acceptance Criteria**:
  - [x] `dotnet build nem.Mimir-typed-ids/` → 0 errors (gating handler integrated)
  - [x] Confidential prompt to OpenAI → 403, no outbound HTTP
  - [x] Public prompt to OpenAI → forwarded, response returned
  - [x] Confidential prompt to Ollama (localhost) → forwarded (internal)
  - [x] Existing Mimir tests still pass (no regression)

  **QA Scenarios**:

  ```
  Scenario: LLM gating blocks Confidential prompt to external provider
    Tool: Bash (dotnet test)
    Preconditions: Mimir builds with classification gating, mock Classification API
    Steps:
      1. Run `dotnet test nem.Mimir-typed-ids/tests/ --filter "LlmGating" --logger "console;verbosity=detailed"`
      2. Verify "ConfidentialPrompt_ExternalLlm_Blocked" passes
      3. Verify "PublicPrompt_ExternalLlm_Allowed" passes
      4. Verify "ConfidentialPrompt_InternalOllama_Allowed" passes
    Expected Result: Gating correctly applied to LiteLlm HttpClient
    Failure Indicators: Confidential data reaches external LLM, Public data blocked, Ollama blocked
    Evidence: .sisyphus/evidence/nem-classification-comms/task-13-llm-gating-litellm.txt

  Scenario: Pre-stream classification happens before first byte
    Tool: Bash (dotnet test)
    Preconditions: Mock streaming response, classification interceptor
    Steps:
      1. Run test "StreamingResponse_ClassifiedBeforeFirstByte"
      2. Verify classification API called BEFORE inner handler SendAsync
      3. Verify stream is not initiated if classification blocks
    Expected Result: Classification decision made pre-flight, no partial stream on block
    Failure Indicators: Stream starts before classification, partial data leaked
    Evidence: .sisyphus/evidence/nem-classification-comms/task-13-prestream-classification.txt
  ```

  **Commit**: YES
  - Message: `feat(mimir): add classification gating to LiteLlm cognitive client`
  - Files: `nem.Mimir-typed-ids/src/Mimir.Infrastructure/LiteLlm/LiteLlmClassificationInterceptor.cs`, `nem.Mimir-typed-ids/src/Mimir.Infrastructure/LiteLlm/LiteLlmClientConfiguration.cs`, `nem.Mimir-typed-ids/src/Mimir.Api/Program.cs`, `nem.Mimir-typed-ids/tests/**`
  - Pre-commit: `dotnet build nem.Mimir-typed-ids/ && dotnet test nem.Mimir-typed-ids/tests/`

- [x] 14. LLM Gating on OpenAiEmbeddingService

  **What to do**:
  - **RED**: Write xunit tests in nem.KnowHub:
    - OpenAiEmbeddingService HttpClient has ClassificationGatingHandler in pipeline
    - Embedding request with Confidential document → blocked (403)
    - Embedding request with Public document → forwarded
    - Classification determined by entity's stored classification (lookup by document ID)
    - Graceful error handling when classification service unavailable (fail-closed: block)
  - **GREEN**: Modify nem.KnowHub:
    - `services/KnowHub.Embedding/ServiceCollectionExtensions.cs` — add ClassificationGatingHandler:
      ```csharp
      services.AddHttpClient<OpenAiEmbeddingService>()
              .AddHttpMessageHandler<ClassificationGatingHandler>();
      ```
    - `services/KnowHub.Embedding/Services/EmbeddingClassificationInterceptor.cs` — pre-flight:
      - Before embedding call: look up document classification from Classification API
      - Attach to HttpRequestMessage.Options
      - If classification service unavailable → default Confidential → block external
    - Update DI in KnowHub.Api/Program.cs
  - **REFACTOR**: Minimal changes — all logic in handler chain, don't touch OpenAiEmbeddingService itself

  **Must NOT do**:
  - Do NOT modify OpenAiEmbeddingService.cs directly
  - Do NOT add classification to internal embedding operations
  - Do NOT break existing embedding tests

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Similar pattern to T13 but simpler (no streaming). HttpClient handler integration
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with T8, T13, T16, T24)
  - **Blocks**: T28
  - **Blocked By**: T7 (classification engine), T9 (middleware), T11 (gating handler)

  **References**:

  **Pattern References**:
  - `nem.KnowHub/services/KnowHub.Embedding/Services/OpenAiEmbeddingService.cs` — THE target: typed HttpClient for embedding calls
  - `nem.KnowHub/services/KnowHub.Embedding/ServiceCollectionExtensions.cs` — DI registration pattern (provider-switch)
  - `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/ClassificationGatingHandler.cs` — Handler to wire in

  **WHY Each Reference Matters**:
  - `OpenAiEmbeddingService.cs`: Must understand how it sends embedding requests to extract entity context for classification
  - `ServiceCollectionExtensions.cs`: DI registration point where HttpMessageHandler chain is configured

  **Acceptance Criteria**:
  - [x] `dotnet build nem.KnowHub/` → 0 errors with gating
  - [x] Confidential document embedding → blocked
  - [x] Public document embedding → forwarded
  - [x] Classification service unavailable → fail-closed (blocked)
  - [x] Existing KnowHub embedding tests still pass

  **QA Scenarios**:

  ```
  Scenario: Embedding gating blocks Confidential document
    Tool: Bash (dotnet test)
    Preconditions: KnowHub builds with gating, mock Classification API
    Steps:
      1. Run `dotnet test nem.KnowHub/tests/ --filter "EmbeddingGating" --logger "console;verbosity=detailed"`
      2. Verify "ConfidentialDocument_ExternalEmbedding_Blocked" passes
      3. Verify "PublicDocument_ExternalEmbedding_Allowed" passes
    Expected Result: Gating correctly applied to embedding HttpClient
    Failure Indicators: Confidential document text sent to external embedding API
    Evidence: .sisyphus/evidence/nem-classification-comms/task-14-embedding-gating.txt

  Scenario: Classification service unavailable → fail-closed
    Tool: Bash (dotnet test)
    Preconditions: Classification API mock returns 503
    Steps:
      1. Run test "ClassificationUnavailable_FailsClosed_BlocksEmbedding"
      2. Verify embedding request blocked (not forwarded)
      3. Verify audit log records the failure
    Expected Result: No embedding sent when classification unavailable
    Failure Indicators: Embedding proceeds without classification check
    Evidence: .sisyphus/evidence/nem-classification-comms/task-14-embedding-failclosed.txt
  ```

  **Commit**: YES
  - Message: `feat(knowhub): add classification gating to OpenAI embedding service`
  - Files: `nem.KnowHub/services/KnowHub.Embedding/ServiceCollectionExtensions.cs`, `nem.KnowHub/services/KnowHub.Embedding/Services/EmbeddingClassificationInterceptor.cs`, `nem.KnowHub/tests/**`
  - Pre-commit: `dotnet build nem.KnowHub/ && dotnet test nem.KnowHub/tests/`

- [x] 15. Migration CLI + Audit-Only Mode Toggle

  **What to do**:
  - **RED**: Write xunit tests:
    - CLI command `classify backfill --entity-type Document --dry-run` → lists entities that would be classified
    - CLI command `classify backfill --entity-type Document` → classifies all unclassified documents
    - CLI command `classify toggle --mode audit-only` → sets audit-only mode globally
    - CLI command `classify toggle --mode enforce` → enables enforcement
    - Backfill processes entities in batches (configurable size, default 100)
    - Backfill reports progress: N/total classified
    - Existing classifications not overwritten (only unclassified entities)
  - **GREEN**: Create `nem.Classification/src/Classification.Cli/`:
    - `Program.cs` — CLI with System.CommandLine:
      - `classify backfill` — batch-classify existing entities
      - `classify toggle` — switch audit-only/enforce mode
      - `classify report` — summary stats (classified/unclassified per entity type)
    - `BackfillCommand.cs` — iterate entities, call ClassificationEngine, store results
    - `ToggleCommand.cs` — update mode in config store (Marten document or OPA data)
    - `ReportCommand.cs` — query classification counts
    - Add to nem.Classification.sln
  - **REFACTOR**: Ensure CLI reuses Classification.Application services (no duplicate logic)

  **Must NOT do**:
  - Do NOT auto-run backfill on service startup (manual CLI only)
  - Do NOT modify entity data — only add classification metadata
  - Do NOT implement real-time migration (batch CLI only)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: CLI tool with batch processing, progress reporting, mode toggling — moderate complexity
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with T17, T18, T19, T21, T22, T23, T31, T32)
  - **Blocks**: —
  - **Blocked By**: T7 (engine), T8 (API), T12 (audit)

  **References**:

  **Pattern References**:
  - `nem.Mimir-typed-ids/src/Mimir.Sync/` — Background processing / batch job pattern in nem.*
  - `nem.Classification/src/Classification.Application/ClassificationEngine.cs` — Engine to reuse for batch classification

  **External References**:
  - System.CommandLine docs: https://learn.microsoft.com/en-us/dotnet/standard/commandline/

  **WHY Each Reference Matters**:
  - `Mimir.Sync/`: Shows batch processing patterns (pagination, progress, error handling) in nem.* ecosystem
  - `ClassificationEngine.cs`: Core logic to reuse — CLI just orchestrates batch calls

  **Acceptance Criteria**:
  - [x] `dotnet build nem.Classification/src/Classification.Cli/` → builds
  - [x] `classify backfill --dry-run` → lists entities, no changes
  - [x] `classify backfill` → classifies unclassified entities, reports N/total
  - [x] `classify toggle --mode audit-only` → mode changed, confirmed
  - [x] `classify report` → shows classified/unclassified counts

  **QA Scenarios**:

  ```
  Scenario: Backfill dry run lists entities
    Tool: Bash (dotnet run)
    Preconditions: Classification service + PostgreSQL running, some unclassified entities
    Steps:
      1. Run `dotnet run --project nem.Classification/src/Classification.Cli/ -- backfill --entity-type Document --dry-run`
      2. Assert output lists entities with "Would classify: [N] documents"
      3. Assert no classification records created (query DB)
    Expected Result: Dry run shows count without making changes
    Failure Indicators: Actual classifications created, crash on empty DB
    Evidence: .sisyphus/evidence/nem-classification-comms/task-15-backfill-dryrun.txt

  Scenario: Toggle mode switches enforcement
    Tool: Bash (dotnet run + curl)
    Preconditions: Classification service running in audit-only mode
    Steps:
      1. Run `dotnet run --project nem.Classification/src/Classification.Cli/ -- toggle --mode enforce`
      2. Assert output confirms "Mode changed to: enforce"
      3. Send Confidential request to external endpoint → verify it's now blocked (not just logged)
    Expected Result: Mode toggle takes effect, enforcement active
    Failure Indicators: Mode doesn't change, still audit-only after toggle
    Evidence: .sisyphus/evidence/nem-classification-comms/task-15-toggle-enforce.txt
  ```

  **Commit**: YES
  - Message: `feat(classification): add migration CLI for backfill and mode toggling`
  - Files: `nem.Classification/src/Classification.Cli/**`, `nem.Classification/tests/**`
  - Pre-commit: `dotnet build nem.Classification/nem.Classification.sln`

- [x] 16. Channel Edge — Webhook Ingestion + Validation

  **What to do**:
  - **RED**: Write xunit tests:
    - Webhook endpoint receives POST with provider-specific payload (Telegram, Teams, WhatsApp format)
    - Signature validation: invalid signature → 401
    - Replay defense: duplicate `X-Request-Id` within window → 409 Conflict
    - Valid webhook → normalized to `ChannelEventReceivedIntegrationEvent` (shared contract from nem.Contracts, defined in T1)
    - Normalization: provider-specific fields mapped to common ChannelEvent structure
    - Rate limiting: >100 req/s from same channel → 429
  - **GREEN**: Implement in `nem.Comms/`:
    - `src/Comms.Api/Endpoints/WebhookEndpoints.cs` — POST `/api/v1/webhook/{channelType}`:
      - Route to channel-specific validator
      - Validate signature/JWT per channel type
      - Deduplicate via idempotency key (Redis or in-memory with TTL)
      - Normalize payload to `ChannelEventReceivedIntegrationEvent` (shared contract from `nem.Contracts/Events/Integration/`, defined in T1)
      - Publish to Wolverine bus
    - `src/Comms.Application/Webhooks/WebhookValidator.cs` — base class for signature validation
    - `src/Comms.Application/Webhooks/WebhookNormalizer.cs` — maps provider payload → ChannelEventReceivedIntegrationEvent
    - `src/Comms.Application/Webhooks/IdempotencyGuard.cs` — replay defense with configurable TTL
    - NOTE: `ChannelEventReceivedIntegrationEvent` is defined in `nem.Contracts/Events/Integration/` (T1). Do NOT create a local duplicate in Comms.Domain/Events/
  - **REFACTOR**: Ensure normalization output exactly matches `ChannelEventReceivedIntegrationEvent` fields from nem.Contracts. Align field mapping with IngestChannelEventCommand pattern from Mimir for smooth consumer transition

  **Must NOT do**:
  - Do NOT implement channel-specific adapters (T17-T23 do that)
  - Do NOT process messages beyond ingestion (routing is T19)
  - Do NOT implement WebSocket connections (webhook only)
  - Do NOT implement message transformation or enrichment

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Security-critical — signature validation, replay defense, normalization across multiple formats
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with T8, T13, T14, T24)
  - **Blocks**: T17, T18, T19, T21, T22, T23
  - **Blocked By**: T1 (ChannelEventReceivedIntegrationEvent shared contract), T4 (Comms scaffolding), T6 (domain model)

  **References**:

  **Pattern References**:
  - `nem.Mimir-typed-ids/src/Mimir.Application/ChannelEvents/IngestChannelEventCommand.cs` — Normalized inbound event format (COPY this pattern)
  - `nem.Mimir-typed-ids/src/Mimir.Application/ChannelEvents/ChannelEventRouter.cs` — How Mimir routes channel events (understand for integration)
  - `nem.Mimir-typed-ids/src/Mimir.Telegram/Services/TelegramBotService.cs` — Telegram webhook handling (signature validation pattern)
  - `nem.Mimir-typed-ids/src/Mimir.Teams/Services/TeamsChannelAdapter.cs` — Teams webhook handling

  **API/Type References**:
  - `nem.Contracts/src/nem.Contracts/Channels/IChannelEventSource.cs` — Channel event source interface
  - `nem.Contracts/src/nem.Contracts/Events/Integration/ChannelEventReceivedIntegrationEvent.cs` — Shared bus contract (from T1): ChannelType, ExternalChannelId, SenderId, SenderDisplayName, Content, Timestamp, RawPayload. This is the Wolverine message type published on the bus for Mimir to consume

  **WHY Each Reference Matters**:
  - `IngestChannelEventCommand.cs`: THE normalization target — webhook endpoints must produce this exact format
  - `TelegramBotService.cs`: Reference for Telegram-specific webhook signature validation
  - `TeamsChannelAdapter.cs`: Reference for Teams-specific JWT validation

  **Acceptance Criteria**:
  - [x] Webhook endpoint accepts POST with valid signature → 200
  - [x] Invalid signature → 401
  - [x] Duplicate request ID → 409
  - [x] Normalized event published to Wolverine bus
  - [x] Rate limiting returns 429 above threshold

  **QA Scenarios**:

  ```
  Scenario: Valid Telegram webhook accepted and normalized
    Tool: Bash (dotnet test)
    Preconditions: Comms service with webhook endpoints registered
    Steps:
      1. Run `dotnet test nem.Comms/tests/ --filter "Webhook" --logger "console;verbosity=detailed"`
      2. Verify "ValidTelegramWebhook_AcceptedAndNormalized" passes
      3. Verify ChannelEventReceivedIntegrationEvent published to bus with correct ChannelType=Telegram
      4. Verify "InvalidSignature_Returns401" passes
    Expected Result: Valid webhooks normalized, invalid rejected
    Failure Indicators: Webhook rejected despite valid signature, missing normalization fields
    Evidence: .sisyphus/evidence/nem-classification-comms/task-16-webhook-ingestion.txt

  Scenario: Replay defense blocks duplicate
    Tool: Bash (dotnet test)
    Preconditions: Idempotency guard configured
    Steps:
      1. Run test "DuplicateRequestId_Returns409"
      2. Send same webhook payload twice with identical X-Request-Id
      3. First request → 200, second request → 409
    Expected Result: Duplicate blocked, original processed
    Failure Indicators: Both accepted (duplicate processing), first blocked
    Evidence: .sisyphus/evidence/nem-classification-comms/task-16-replay-defense.txt
  ```

  **Commit**: YES
  - Message: `feat(comms): add webhook ingestion with validation and normalization`
  - Files: `nem.Comms/src/Comms.Api/Endpoints/WebhookEndpoints.cs`, `nem.Comms/src/Comms.Application/Webhooks/*`, `nem.Comms/tests/**`
  - Pre-commit: `dotnet test nem.Comms/tests/`

- [x] 17. WebWidget Channel Adapter

  **What to do**:
  - **RED**: Write xunit tests:
    - `WebWidgetAdapter.SendAsync()` sends message via SignalR hub
    - `WebWidgetAdapter.ValidateWebhook()` validates JWT token from widget
    - `WebWidgetAdapter` normalizes WebWidget payload to ChannelEvent
    - Connection lifecycle: connect, message, disconnect events handled
    - Adapter implements IChannelAdapter with ChannelType.WebWidget
  - **GREEN**: Implement in `nem.Comms/src/Comms.Infrastructure/Channels/WebWidget/`:
    - `WebWidgetAdapter.cs` — implements IChannelAdapter:
      - `SendAsync(ChannelMessage)` → push to SignalR hub
      - `ValidateWebhook(HttpRequest)` → validate JWT
      - `NormalizeEvent(RawPayload)` → ChannelEventReceived
    - `WebWidgetHub.cs` — SignalR hub for bidirectional web widget communication
    - `WebWidgetOptions.cs` — config: allowed origins, JWT settings
    - Register in DI with `services.AddKeyedSingleton<IChannelAdapter, WebWidgetAdapter>(ChannelType.WebWidget)`
  - **REFACTOR**: Align with adapter interface pattern from nem.Contracts

  **Must NOT do**:
  - Do NOT implement chat UI (frontend widget is out of scope)
  - Do NOT implement message persistence (Mimir handles that)
  - Do NOT add WebSocket fallback — SignalR handles transport negotiation

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: SignalR hub + adapter pattern — moderate complexity with real-time concerns
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with T15, T18, T19, T21, T22, T23, T31, T32)
  - **Blocks**: T27, T28
  - **Blocked By**: T4 (Comms scaffolding), T6 (domain model), T16 (webhook ingestion)

  **References**:

  **Pattern References**:
  - `nem.Mimir-typed-ids/src/Mimir.Api/Hubs/WebWidgetChannelAdapter.cs` — Existing WebWidget adapter in Mimir (reference implementation to BUILD NEW, not extract)
  - `nem.Contracts/src/nem.Contracts/Channels/IChannelMessageSender.cs` — Outbound message interface

  **WHY Each Reference Matters**:
  - `WebWidgetChannelAdapter.cs` (in `Mimir.Api/Hubs/`): Reference for WebWidget protocol handling — build a NEW adapter in Comms that follows same patterns but fits federation architecture

  **Acceptance Criteria**:
  - [x] `dotnet test --filter "WebWidget"` → all adapter tests pass
  - [x] SignalR hub accepts connections and delivers messages
  - [x] JWT validation rejects invalid tokens
  - [x] Adapter registered as IChannelAdapter for ChannelType.WebWidget

  **QA Scenarios**:

  ```
  Scenario: WebWidget adapter sends message via SignalR
    Tool: Bash (dotnet test)
    Preconditions: Comms service with SignalR hub
    Steps:
      1. Run `dotnet test nem.Comms/tests/ --filter "WebWidget" --logger "console;verbosity=detailed"`
      2. Verify "SendAsync_PushesToSignalRHub" passes
      3. Verify "ValidateWebhook_ValidJwt_Accepted" passes
      4. Verify "NormalizeEvent_CorrectChannelType" passes
    Expected Result: All WebWidget adapter tests pass
    Failure Indicators: SignalR send fails, JWT not validated, wrong channel type
    Evidence: .sisyphus/evidence/nem-classification-comms/task-17-webwidget-adapter.txt

  Scenario: Invalid JWT rejected
    Tool: Bash (dotnet test)
    Preconditions: WebWidget adapter with JWT validation
    Steps:
      1. Run test "ValidateWebhook_InvalidJwt_Returns401"
      2. Verify adapter rejects connection with invalid/expired JWT
    Expected Result: 401 Unauthorized for invalid tokens
    Failure Indicators: Invalid JWT accepted, no validation
    Evidence: .sisyphus/evidence/nem-classification-comms/task-17-webwidget-jwt.txt
  ```

  **Commit**: YES
  - Message: `feat(comms): add WebWidget channel adapter with SignalR hub`
  - Files: `nem.Comms/src/Comms.Infrastructure/Channels/WebWidget/*`, `nem.Comms/tests/**`
  - Pre-commit: `dotnet test nem.Comms/tests/`

- [x] 18. Teams Channel Adapter

  **What to do**:
  - **RED**: Write xunit tests:
    - `TeamsAdapter.SendAsync()` calls Microsoft Bot Framework API
    - `TeamsAdapter.ValidateWebhook()` validates Teams JWT (Microsoft-specific)
    - `TeamsAdapter` normalizes Teams Activity payload → ChannelEvent
    - Adapter handles Teams-specific message types (text, card, adaptive card)
    - Adapter implements IChannelAdapter with ChannelType.Teams
    - Error handling: Teams API errors → logged, retried, eventually DLQ'd
  - **GREEN**: Implement in `nem.Comms/src/Comms.Infrastructure/Channels/Teams/`:
    - `TeamsAdapter.cs` — implements IChannelAdapter:
      - `SendAsync(ChannelMessage)` → Bot Framework REST API
      - `ValidateWebhook(HttpRequest)` → Microsoft JWT validation
      - `NormalizeEvent(RawPayload)` → map Teams Activity to ChannelEventReceived
    - `TeamsAuthValidator.cs` — Microsoft-specific JWT validation (OpenID Connect discovery)
    - `TeamsOptions.cs` — config: BotId, BotSecret, TenantId
    - Register in DI with `services.AddKeyedSingleton<IChannelAdapter, TeamsAdapter>(ChannelType.Teams)`
  - **REFACTOR**: Follow same adapter structure as WebWidgetAdapter (T17)

  **Must NOT do**:
  - Do NOT implement Adaptive Card rendering (out of scope)
  - Do NOT implement Teams-specific features (tabs, task modules)
  - Do NOT modify Mimir's existing TeamsChannelAdapter
  - Do NOT add Microsoft Graph API integration

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Teams-specific integration — JWT validation, Bot Framework API, Activity normalization
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with T15, T17, T19, T21, T22, T23, T31, T32)
  - **Blocks**: T27, T28
  - **Blocked By**: T4 (Comms scaffolding), T6 (domain model), T16 (webhook ingestion)

  **References**:

  **Pattern References**:
  - `nem.Mimir-typed-ids/src/Mimir.Teams/Services/TeamsChannelAdapter.cs` — Existing Teams adapter (reference for Bot Framework integration pattern)
  - `nem.Comms/src/Comms.Infrastructure/Channels/WebWidget/WebWidgetAdapter.cs` — T17 adapter (follow same IChannelAdapter structure)

  **External References**:
  - Microsoft Bot Framework REST API: https://learn.microsoft.com/en-us/azure/bot-service/rest-api/bot-framework-rest-connector-api-reference

  **WHY Each Reference Matters**:
  - `TeamsChannelAdapter.cs` in Mimir: Understand Teams-specific JWT validation and Activity payload format
  - T17 WebWidgetAdapter: Consistent adapter structure — all adapters must follow same pattern

  **Acceptance Criteria**:
  - [x] `dotnet test --filter "Teams"` → all adapter tests pass
  - [x] Teams JWT validation works with Microsoft OpenID discovery
  - [x] Activity normalization maps text, sender, conversationId correctly
  - [x] Adapter registered for ChannelType.Teams

  **QA Scenarios**:

  ```
  Scenario: Teams adapter normalizes Activity to ChannelEvent
    Tool: Bash (dotnet test)
    Preconditions: Comms service builds with Teams adapter
    Steps:
      1. Run `dotnet test nem.Comms/tests/ --filter "Teams" --logger "console;verbosity=detailed"`
      2. Verify "NormalizeEvent_TeamsActivity_MapsCorrectly" passes
      3. Verify "SendAsync_CallsBotFrameworkApi" passes
      4. Verify "ValidateWebhook_MicrosoftJwt_Accepted" passes
    Expected Result: All Teams adapter tests pass
    Failure Indicators: Activity fields lost in normalization, wrong API endpoint
    Evidence: .sisyphus/evidence/nem-classification-comms/task-18-teams-adapter.txt

  Scenario: Teams adapter handles API errors gracefully
    Tool: Bash (dotnet test)
    Preconditions: Mock Bot Framework API returning 503
    Steps:
      1. Run test "SendAsync_BotFramework503_RetriesAndLogs"
      2. Verify retry attempted (Polly)
      3. Verify error logged with Teams-specific context
    Expected Result: Error handled gracefully, not crashed
    Failure Indicators: Unhandled exception, no retry, crash
    Evidence: .sisyphus/evidence/nem-classification-comms/task-18-teams-error-handling.txt
  ```

  **Commit**: YES
  - Message: `feat(comms): add Teams channel adapter with Bot Framework integration`
  - Files: `nem.Comms/src/Comms.Infrastructure/Channels/Teams/*`, `nem.Comms/tests/**`
  - Pre-commit: `dotnet test nem.Comms/tests/`

### Wave 4 — Federation Core + More Adapters (routing, retries, adapters)

- [x] 19. Federation Core — Conversation Routing + Assignment

  **What to do**:
  - **RED**: Write xunit tests:
    - `ChannelRouter.RouteAsync(ChannelEventReceivedIntegrationEvent)` — routes inbound event to correct handler
    - New channel event with no existing session → creates ChannelSession, publishes `ChannelEventReceivedIntegrationEvent` to Mimir bus
    - Existing session → routes to assigned operator or queue
    - Operator assignment: round-robin within tenant, respects capacity limits
    - Cross-channel routing: customer contacts via Telegram, operator responds via Teams → same ChannelSession
    - Priority routing: VIP customers (metadata tag) → priority queue
    - Routing when no operator available → queued with position tracking
  - **GREEN**: Implement in `nem.Comms/`:
    - `src/Comms.Application/Routing/ChannelRouter.cs` — implements IChannelRouter:
      - Match inbound event to existing ChannelSession (by ExternalChannelId + ChannelType)
      - If no session → create one, assign routing state
      - If session exists → forward to current assignment
      - Publish normalized event to Wolverine bus for Mimir consumption (uses `ChannelEventReceivedIntegrationEvent` from nem.Contracts)
    - `src/Comms.Application/Routing/OperatorAssignmentService.cs` — round-robin assignment
    - `src/Comms.Application/Routing/RoutingQueue.cs` — queue management with priority
    - `src/Comms.Domain/Events/OperatorAssigned.cs` — domain event
    - `src/Comms.Domain/Events/SessionQueued.cs` — domain event
    - Wolverine handler: `ChannelEventReceivedHandler.cs` — wires router into message pipeline
    - **Mimir consumer adapter**: `nem.Mimir-typed-ids/src/Mimir.Application/ChannelEvents/ChannelEventReceivedConsumer.cs` — Wolverine message handler that maps `ChannelEventReceivedIntegrationEvent` (shared contract) → `IngestChannelEventCommand` (Mimir-internal CQRS) and dispatches via MediatR. This is the bridge between Comms' bus event and Mimir's existing processing pipeline
  - **REFACTOR**: Ensure routing events published on Wolverine bus for Mimir consumption

  **Must NOT do**:
  - Do NOT implement conversation management (Mimir's domain)
  - Do NOT store message content (routing metadata only)
  - Do NOT implement advanced routing rules (skills-based, AI-driven — future)
  - Do NOT implement operator presence/availability (future)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Core federation logic — routing algorithm, session management, cross-channel correlation, event-driven
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with T15, T17, T18, T21, T22, T23, T31, T32)
  - **Blocks**: T20, T25, T28
  - **Blocked By**: T1 (ChannelEventReceivedIntegrationEvent shared contract), T4 (scaffolding), T6 (domain model), T16 (webhook ingestion) — Routes via IChannelAdapter interface, does NOT need concrete adapters T17/T18

  **References**:

  **Pattern References**:
  - `nem.Mimir-typed-ids/src/Mimir.Application/ChannelEvents/ChannelEventRouter.cs` — Mimir's channel routing (understand to NOT duplicate, but integrate with)
  - `nem.Mimir-typed-ids/src/Mimir.Application/ChannelEvents/IngestChannelEventCommand.cs` — Command that Comms will publish for Mimir
  - `nem.Mimir-typed-ids/src/Mimir.Application/ChannelEvents/SendChannelMessageCommand.cs` — Outbound command pattern

  **API/Type References**:
  - `ChannelSession` from T6: aggregate root for routing state
  - `ChannelEventReceivedIntegrationEvent` from T1 (nem.Contracts): shared bus contract for inbound normalized events
  - Boundary: Comms publishes `ChannelEventReceivedIntegrationEvent` on Wolverine bus → Mimir's `IngestChannelEventHandler` consumes it (Mimir needs a Wolverine consumer adapter that maps the shared event to its internal `IngestChannelEventCommand`)

  **WHY Each Reference Matters**:
  - `ChannelEventRouter.cs`: Understand Mimir's routing to ensure Comms complements rather than duplicates it
  - `IngestChannelEventCommand.cs`: The Mimir-internal command — Mimir needs a Wolverine consumer that maps `ChannelEventReceivedIntegrationEvent` (shared contract from nem.Contracts) → `IngestChannelEventCommand` (Mimir-internal CQRS command). This consumer adapter should be noted as a Mimir modification in T19

  **Acceptance Criteria**:
  - [x] `dotnet test --filter "Routing"` → all routing tests pass
  - [x] New event → ChannelSession created + event published to bus
  - [x] Existing session → event forwarded to assignment
  - [x] Cross-channel correlation works (same customer, different channels, same session)
  - [x] Queue management: customer gets queue position when no operator

  **QA Scenarios**:

  ```
  Scenario: Inbound event creates session and publishes to bus
    Tool: Bash (dotnet test)
    Preconditions: Comms with routing, in-memory Wolverine host
    Steps:
      1. Run `dotnet test nem.Comms/tests/ --filter "ChannelRouter" --logger "console;verbosity=detailed"`
      2. Verify "NewEvent_CreatesSession" passes
      3. Verify "NewEvent_PublishesChannelEventReceivedIntegrationEvent" passes — bus message captured
      4. Verify "ExistingSession_RoutesToAssignment" passes
    Expected Result: Routing creates sessions and publishes events correctly
    Failure Indicators: No session created, event not published, wrong assignment
    Evidence: .sisyphus/evidence/nem-classification-comms/task-19-routing-core.txt

  Scenario: Cross-channel routing correlates same customer
    Tool: Bash (dotnet test)
    Preconditions: ChannelIdentityLink configured for test customer
    Steps:
      1. Run test "CrossChannel_SameCustomer_SameSession"
      2. Customer sends via Telegram → session created
      3. Same customer (linked identity) sends via WebWidget → SAME session used
    Expected Result: Cross-channel messages correlated to single session
    Failure Indicators: Separate sessions created, no identity correlation
    Evidence: .sisyphus/evidence/nem-classification-comms/task-19-cross-channel.txt
  ```

  **Commit**: YES
  - Message: `feat(comms): implement federation core routing and operator assignment`
  - Files: `nem.Comms/src/Comms.Application/Routing/*`, `nem.Comms/src/Comms.Domain/Events/*`, `nem.Comms/tests/**`
  - Pre-commit: `dotnet test nem.Comms/tests/`

- [x] 20. Federation Core — Delivery Retries + DLQ

  **What to do**:
  - **RED**: Write xunit tests:
    - `DeliveryManager.DeliverAsync()` sends message via correct adapter
    - Adapter returns failure → retry with exponential backoff (3 retries, 1s/2s/4s)
    - All retries exhausted → message moved to DLQ (Wolverine dead letter)
    - DLQ message can be inspected via API
    - DLQ message can be replayed (resubmitted for delivery)
    - Delivery success → audit logged with delivery time
    - Circuit breaker: adapter returning 5 consecutive failures → circuit open, fast-fail for 30s
  - **GREEN**: Implement in `nem.Comms/`:
    - `src/Comms.Application/Delivery/DeliveryManager.cs` — implements IDeliveryManager:
      - Resolve IChannelAdapter by ChannelType (keyed DI)
      - Call adapter.SendAsync() with retry (Polly)
      - On exhaustion → publish to DLQ queue via Wolverine
    - `src/Comms.Application/Delivery/DeliveryRetryPolicy.cs` — Polly config: 3 retries, exponential backoff
    - `src/Comms.Application/Delivery/CircuitBreakerPolicy.cs` — Polly circuit breaker per adapter
    - `src/Comms.Api/Endpoints/DlqEndpoints.cs` — GET /api/v1/dlq (list), POST /api/v1/dlq/{id}/replay
    - Wolverine dead letter queue configuration in WolverineConfiguration
  - **REFACTOR**: Use Wolverine's built-in error handling where possible, Polly for adapter-level retries

  **Must NOT do**:
  - Do NOT implement custom DLQ storage (use Wolverine's built-in dead letter)
  - Do NOT implement notification on DLQ (future feature)
  - Do NOT add per-tenant retry configuration (global config only)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Retry logic, circuit breakers, DLQ management — reliability engineering
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with T25, T27)
  - **Blocks**: —
  - **Blocked By**: T19 (routing engine — presence events need routing to correct channels)

  **References**:

  **Pattern References**:
  - `nem.Mimir-typed-ids/src/Mimir.Sync/Configuration/WolverineConfiguration.cs` — Wolverine error handling + dead letter configuration
  - `docs/integration/MESSAGE-BUS-GUIDE.md` — RabbitMQ topology, DLQ conventions

  **External References**:
  - Wolverine error handling docs: https://wolverine.netlify.app/guide/handlers/error-handling.html
  - Polly retry patterns: https://github.com/App-vNext/Polly

  **WHY Each Reference Matters**:
  - `WolverineConfiguration.cs`: Wolverine already has dead letter handling — leverage it, don't reinvent
  - `MESSAGE-BUS-GUIDE.md`: DLQ queue naming conventions and RabbitMQ dead letter exchange setup

  **Acceptance Criteria**:
  - [x] `dotnet test --filter "Delivery"` → all delivery tests pass
  - [x] Failed delivery → 3 retries with exponential backoff
  - [x] Exhausted retries → message in DLQ
  - [x] DLQ API: list + replay work
  - [x] Circuit breaker: 5 failures → fast-fail for 30s

  **QA Scenarios**:

  ```
  Scenario: Delivery retries and DLQs on exhaustion
    Tool: Bash (dotnet test)
    Preconditions: Comms with delivery manager, mock adapter that always fails
    Steps:
      1. Run `dotnet test nem.Comms/tests/ --filter "Delivery" --logger "console;verbosity=detailed"`
      2. Verify "FailingAdapter_RetriesThreeTimes" passes — 3 retry attempts logged
      3. Verify "AllRetriesExhausted_MovesToDlq" passes — DLQ entry created
      4. Verify "DlqReplay_ResubmitsMessage" passes
    Expected Result: Retry → DLQ → replay cycle works end-to-end
    Failure Indicators: No retries, message lost (not in DLQ), replay fails
    Evidence: .sisyphus/evidence/nem-classification-comms/task-20-delivery-retries.txt

  Scenario: Circuit breaker opens after consecutive failures
    Tool: Bash (dotnet test)
    Preconditions: Mock adapter fails 5+ times consecutively
    Steps:
      1. Run test "CircuitBreaker_OpensAfterFiveFailures"
      2. Verify 6th call immediately fails (fast-fail, no adapter call)
      3. Verify circuit reopens after timeout (30s simulated)
    Expected Result: Circuit breaker protects against cascading failures
    Failure Indicators: All calls still go to adapter after 5 failures
    Evidence: .sisyphus/evidence/nem-classification-comms/task-20-circuit-breaker.txt
  ```

  **Commit**: YES
  - Message: `feat(comms): implement delivery retries, circuit breaker, and DLQ management`
  - Files: `nem.Comms/src/Comms.Application/Delivery/*`, `nem.Comms/src/Comms.Api/Endpoints/DlqEndpoints.cs`, `nem.Comms/tests/**`
  - Pre-commit: `dotnet test nem.Comms/tests/`

- [x] 21. Telegram Channel Adapter

  **What to do**:
  - **RED**: Write xunit tests:
    - `TelegramAdapter.SendAsync()` calls Telegram Bot API (sendMessage)
    - `TelegramAdapter.ValidateWebhook()` validates Telegram secret token
    - Normalization: Telegram Update → `ChannelEventReceivedIntegrationEvent` with text, sender, chatId
    - Handles text messages, photo captions, document descriptions
    - Adapter implements IChannelAdapter with ChannelType.Telegram
    - Bot API errors → logged with Telegram-specific error codes
  - **GREEN**: Implement in `nem.Comms/src/Comms.Infrastructure/Channels/Telegram/`:
    - `TelegramAdapter.cs` — implements IChannelAdapter
    - `TelegramBotClient.cs` — typed HttpClient to Telegram Bot API
    - `TelegramWebhookValidator.cs` — secret token validation
    - `TelegramOptions.cs` — config: BotToken, WebhookSecret
    - Register as `IChannelAdapter` for `ChannelType.Telegram`
  - **REFACTOR**: Follow same adapter pattern as T17 (WebWidget) and T18 (Teams)

  **Must NOT do**:
  - Do NOT implement Telegram inline keyboards or custom keyboards
  - Do NOT implement file upload/download via Telegram
  - Do NOT modify Mimir's existing TelegramBotService

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Telegram Bot API integration — well-documented, follows established adapter pattern
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with T15, T17, T18, T19, T22, T23, T31, T32)
  - **Blocks**: —
  - **Blocked By**: T4, T6, T16

  **References**:

  **Pattern References**:
  - `nem.Mimir-typed-ids/src/Mimir.Telegram/Services/TelegramBotService.cs` — Existing Telegram integration (reference, build NEW)
  - `nem.Comms/src/Comms.Infrastructure/Channels/WebWidget/WebWidgetAdapter.cs` — T17 adapter (same pattern)

  **External References**:
  - Telegram Bot API: https://core.telegram.org/bots/api

  **WHY Each Reference Matters**:
  - `TelegramBotService.cs`: Understand Telegram-specific validation, Update parsing, sendMessage format

  **Acceptance Criteria**:
  - [x] `dotnet test --filter "Telegram"` → all adapter tests pass
  - [x] SendAsync calls correct Telegram Bot API endpoint
  - [x] Webhook validation rejects invalid secret token
  - [x] Normalization extracts text, sender info, chatId correctly

  **QA Scenarios**:

  ```
  Scenario: Telegram adapter sends and receives
    Tool: Bash (dotnet test)
    Preconditions: Comms builds with Telegram adapter, mock Bot API
    Steps:
      1. Run `dotnet test nem.Comms/tests/ --filter "Telegram" --logger "console;verbosity=detailed"`
      2. Verify "SendAsync_CallsBotApi" passes
      3. Verify "NormalizeEvent_TelegramUpdate_MapsCorrectly" passes
      4. Verify "ValidateWebhook_ValidSecret_Accepted" passes
    Expected Result: All Telegram adapter tests pass
    Failure Indicators: Wrong API endpoint, normalization loses data
    Evidence: .sisyphus/evidence/nem-classification-comms/task-21-telegram-adapter.txt
  ```

  **Commit**: YES
  - Message: `feat(comms): add Telegram channel adapter`
  - Files: `nem.Comms/src/Comms.Infrastructure/Channels/Telegram/*`, `nem.Comms/tests/**`
  - Pre-commit: `dotnet test nem.Comms/tests/`

- [x] 22. WhatsApp Channel Adapter

  **What to do**:
  - **RED**: Write xunit tests:
    - `WhatsAppAdapter.SendAsync()` calls WhatsApp Business API (Cloud API)
    - `WhatsAppAdapter.ValidateWebhook()` validates Meta webhook signature (SHA256 HMAC)
    - Normalization: WhatsApp webhook payload → ChannelEventReceived
    - Handles text messages, template messages, interactive messages
    - Adapter implements IChannelAdapter with ChannelType.WhatsApp
    - 24-hour messaging window enforcement (track last customer message time)
  - **GREEN**: Implement in `nem.Comms/src/Comms.Infrastructure/Channels/WhatsApp/`:
    - `WhatsAppAdapter.cs` — implements IChannelAdapter
    - `WhatsAppCloudApiClient.cs` — typed HttpClient to Meta Cloud API
    - `WhatsAppWebhookValidator.cs` — SHA256 HMAC signature validation
    - `WhatsAppOptions.cs` — config: PhoneNumberId, AccessToken, WebhookVerifyToken, AppSecret
    - Register as `IChannelAdapter` for `ChannelType.WhatsApp`
  - **REFACTOR**: Follow same adapter pattern as T17, T18, T21

  **Must NOT do**:
  - Do NOT implement WhatsApp template message management
  - Do NOT implement media message handling (text only for now)
  - Do NOT modify Mimir's existing WhatsAppChannelAdapter

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: WhatsApp Business API — HMAC validation, Cloud API, follows established adapter pattern
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with T15, T17, T18, T19, T21, T23, T31, T32)
  - **Blocks**: —
  - **Blocked By**: T4, T6, T16

  **References**:

  **Pattern References**:
  - `nem.Mimir-typed-ids/src/Mimir.WhatsApp/Services/WhatsAppChannelAdapter.cs` — Existing WhatsApp adapter (reference for Cloud API integration)
  - `nem.Comms/src/Comms.Infrastructure/Channels/WebWidget/WebWidgetAdapter.cs` — T17 pattern

  **External References**:
  - WhatsApp Cloud API: https://developers.facebook.com/docs/whatsapp/cloud-api

  **WHY Each Reference Matters**:
  - `WhatsAppChannelAdapter.cs` in Mimir: Understand HMAC validation, message format, Cloud API endpoints

  **Acceptance Criteria**:
  - [x] `dotnet test --filter "WhatsApp"` → all adapter tests pass
  - [x] HMAC signature validation works
  - [x] Webhook payload correctly normalized to ChannelEvent
  - [x] Adapter registered for ChannelType.WhatsApp

  **QA Scenarios**:

  ```
  Scenario: WhatsApp adapter validates and normalizes
    Tool: Bash (dotnet test)
    Preconditions: Comms builds with WhatsApp adapter, mock Cloud API
    Steps:
      1. Run `dotnet test nem.Comms/tests/ --filter "WhatsApp" --logger "console;verbosity=detailed"`
      2. Verify "ValidateWebhook_ValidHmac_Accepted" passes
      3. Verify "NormalizeEvent_WhatsAppPayload_MapsCorrectly" passes
      4. Verify "SendAsync_CallsCloudApi" passes
    Expected Result: All WhatsApp adapter tests pass
    Failure Indicators: HMAC validation broken, Cloud API call wrong
    Evidence: .sisyphus/evidence/nem-classification-comms/task-22-whatsapp-adapter.txt
  ```

  **Commit**: YES
  - Message: `feat(comms): add WhatsApp channel adapter`
  - Files: `nem.Comms/src/Comms.Infrastructure/Channels/WhatsApp/*`, `nem.Comms/tests/**`
  - Pre-commit: `dotnet test nem.Comms/tests/`

- [x] 23. Signal Channel Adapter

  **What to do**:
  - **RED**: Write xunit tests:
    - `SignalAdapter.SendAsync()` calls Signal REST API (signal-cli-rest-api)
    - `SignalAdapter.ValidateWebhook()` validates webhook callback
    - Normalization: Signal message → ChannelEventReceived
    - Handles text messages
    - Adapter implements IChannelAdapter with ChannelType.Signal
  - **GREEN**: Implement in `nem.Comms/src/Comms.Infrastructure/Channels/Signal/`:
    - `SignalAdapter.cs` — implements IChannelAdapter
    - `SignalRestApiClient.cs` — typed HttpClient to signal-cli-rest-api
    - `SignalOptions.cs` — config: SignalApiUrl, PhoneNumber
    - Register as `IChannelAdapter` for `ChannelType.Signal`
  - **REFACTOR**: Follow same adapter pattern

  **Must NOT do**:
  - Do NOT implement Signal groups
  - Do NOT implement Signal attachments
  - Do NOT implement Signal registration/linking (assume pre-configured)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Signal REST API — simpler than Teams/WhatsApp, follows adapter pattern
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with T15, T17, T18, T19, T21, T22, T31, T32)
  - **Blocks**: —
  - **Blocked By**: T4, T6, T16

  **References**:

  **Pattern References**:
  - `nem.Mimir-typed-ids/src/Mimir.Signal/Services/SignalChannelAdapter.cs` — Existing Signal adapter (reference)
  - `nem.Comms/src/Comms.Infrastructure/Channels/WebWidget/WebWidgetAdapter.cs` — T17 pattern

  **External References**:
  - signal-cli-rest-api: https://github.com/bbernhard/signal-cli-rest-api

  **Acceptance Criteria**:
  - [x] `dotnet test --filter "Signal"` → all adapter tests pass
  - [x] SendAsync calls signal-cli-rest-api correctly
  - [x] Normalization maps Signal message fields
  - [x] Adapter registered for ChannelType.Signal

  **QA Scenarios**:

  ```
  Scenario: Signal adapter sends and normalizes
    Tool: Bash (dotnet test)
    Preconditions: Comms builds with Signal adapter, mock signal-cli-rest-api
    Steps:
      1. Run `dotnet test nem.Comms/tests/ --filter "Signal" --logger "console;verbosity=detailed"`
      2. Verify "SendAsync_CallsSignalApi" passes
      3. Verify "NormalizeEvent_SignalMessage_MapsCorrectly" passes
    Expected Result: All Signal adapter tests pass
    Failure Indicators: Wrong API format, missing message content
    Evidence: .sisyphus/evidence/nem-classification-comms/task-23-signal-adapter.txt
  ```

  **Commit**: YES
  - Message: `feat(comms): add Signal channel adapter`
  - Files: `nem.Comms/src/Comms.Infrastructure/Channels/Signal/*`, `nem.Comms/tests/**`
  - Pre-commit: `dotnet test nem.Comms/tests/`

- [x] 24. Identity & Policy — Tenant-Scoped Identity Links

  **What to do**:
  - **RED**: Write xunit tests:
    - `IdentityLinkService.LinkAsync()` creates ChannelIdentityLink: maps platform userId → federated participantId
    - `IdentityLinkService.ResolveAsync(channelType, externalUserId)` → returns federated participantId
    - Identity links are tenant-scoped (TenantA's links invisible to TenantB)
    - Multiple channel identities can link to same federated participant
    - API endpoints: POST /api/v1/identity/link, GET /api/v1/identity/resolve
    - Classification level assigned to identity links (inherit tenant default)
  - **GREEN**: Implement in `nem.Comms/`:
    - `src/Comms.Application/Identity/IdentityLinkService.cs` — CRUD + resolution
    - `src/Comms.Infrastructure/Persistence/IdentityLinkRepository.cs` — Marten-backed
    - `src/Comms.Api/Endpoints/IdentityEndpoints.cs` — REST API for identity management
    - `src/Comms.Application/Identity/IdentityLinkValidator.cs` — FluentValidation
    - Wire identity resolution into ChannelRouter (T19) — when routing, resolve federated identity
  - **REFACTOR**: Follow tenant isolation patterns from ITenantContext

  **Must NOT do**:
  - Do NOT implement identity auto-discovery (manual linking only)
  - Do NOT implement identity merging/splitting
  - Do NOT store user profile data beyond link metadata

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Identity management with tenant scoping — moderate complexity, REST + persistence
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with T8, T13, T14, T16)
  - **Blocks**: T25, T26
  - **Blocked By**: T1 (types), T4 (scaffolding), T6 (domain model)

  **References**:

  **Pattern References**:
  - `nem/src/nem.Messaging/Infrastructure/Security/ITenantContext.cs` — Tenant scoping pattern
  - `nem.KnowHub/services/KnowHub.Api/Services/CurrentRequestTenantContext.cs` — JWT tenant extraction
  - `nem.Comms/src/Comms.Domain/Entities/ChannelIdentityLink.cs` — Domain entity from T6

  **WHY Each Reference Matters**:
  - `ITenantContext.cs`: Identity links must be tenant-scoped using same mechanism
  - `CurrentRequestTenantContext.cs`: How to extract tenant from JWT for scoping queries

  **Acceptance Criteria**:
  - [x] `dotnet test --filter "Identity"` → all identity tests pass
  - [x] Link Telegram userId to federated participant → stored and retrievable
  - [x] Resolve by channelType + externalUserId → correct federated participant
  - [x] Cross-tenant isolation: TenantA's links not visible to TenantB
  - [x] Multiple channels linked to same participant

  **QA Scenarios**:

  ```
  Scenario: Identity linking and resolution
    Tool: Bash (dotnet test)
    Preconditions: Comms with Marten, Testcontainers PostgreSQL
    Steps:
      1. Run `dotnet test nem.Comms/tests/ --filter "Identity" --logger "console;verbosity=detailed"`
      2. Verify "LinkAsync_CreatesIdentityLink" passes
      3. Verify "ResolveAsync_ReturnsCorrectParticipant" passes
      4. Verify "TenantIsolation_CrossTenantLinkInvisible" passes
    Expected Result: Identity linking, resolution, and tenant isolation work
    Failure Indicators: Cross-tenant leak, resolution returns wrong participant
    Evidence: .sisyphus/evidence/nem-classification-comms/task-24-identity-links.txt

  Scenario: Multiple channels linked to same participant
    Tool: Bash (dotnet test)
    Preconditions: Identity link service available
    Steps:
      1. Run test "MultipleChannels_SameParticipant_AllResolve"
      2. Link TelegramUser123 → Participant-A
      3. Link TeamsUser456 → Participant-A
      4. Resolve TelegramUser123 → Participant-A
      5. Resolve TeamsUser456 → Participant-A
    Expected Result: Both channel identities resolve to same federated participant
    Failure Indicators: Different participants returned, link overwritten
    Evidence: .sisyphus/evidence/nem-classification-comms/task-24-multi-channel-identity.txt
  ```

  **Commit**: YES
  - Message: `feat(comms): add tenant-scoped identity linking and resolution`
  - Files: `nem.Comms/src/Comms.Application/Identity/*`, `nem.Comms/src/Comms.Infrastructure/Persistence/IdentityLinkRepository.cs`, `nem.Comms/src/Comms.Api/Endpoints/IdentityEndpoints.cs`, `nem.Comms/tests/**`
  - Pre-commit: `dotnet test nem.Comms/tests/`

### Wave 5 — Integration (operator API, classification in comms, docker, E2E)

- [x] 25. Operator Read API — Unified Inbox

  **What to do**:

  **RED** — Write xunit tests for operator inbox endpoints:
  - `GET /api/v1/operator/inbox` — returns paginated list of active sessions across all channels, filtered by queue/status/channel
  - `GET /api/v1/operator/sessions/{sessionId}` — returns full session detail with message history sourced from **local read-model projection** (see `ISessionReadModel` below; populated by consuming `MessageCreatedEvent` from Wolverine bus — published by Mimir whenever a message is persisted)
  - `POST /api/v1/operator/sessions/{sessionId}/claim` — assigns operator to session (idempotent, rejects if already claimed by another)
  - `POST /api/v1/operator/sessions/{sessionId}/respond` — sends operator reply, routed back through the originating channel adapter
  - Test authorization: only operators with `comms:operator` role can access
  - Test tenant isolation: operator sees only their tenant's sessions
  - Test pagination: offset/limit with total count header
  - Test claim conflict: 409 Conflict when session already claimed by different operator

  **GREEN** — Implement minimal endpoints:
  - First, create the integration event contract in nem.Contracts (if not already present):
    - `nem.Contracts/src/nem.Contracts/Events/Integration/MessageCreatedEvent.cs` — record: `SessionId`, `MessageId`, `TenantId`, `SenderName`, `Text`, `Timestamp`, `ChannelType`. Extends `IntegrationEvent`. Published by Mimir when a message is persisted, consumed by nem.Comms for local projection.
  - **Mimir-side publisher** (CRITICAL — without this, the read-model has no data):
    - Modify `nem.Mimir-typed-ids/src/Mimir.Application/Conversations/Commands/SendMessage.cs` — in `SendMessageCommandHandler`, after successful message persistence (`IUnitOfWork.SaveChangesAsync`), publish `MessageCreatedEvent` on Wolverine bus.
    - Pattern: inject `IMessageBus`, after save call `await _messageBus.PublishAsync(new MessageCreatedEvent { ... })`. Follow existing Wolverine publishing patterns in Mimir (search for `IMessageBus` or `PublishAsync` in Mimir codebase). Also consider adding to `Mimir.Application/ChannelEvents/IngestChannelEventHandler.cs` if inbound channel messages take a different persistence path.
    - This is a MINIMAL change to Mimir — add one `PublishAsync` call after message save. Do NOT refactor or change any other Mimir behavior.
  - `OperatorInboxEndpoints.cs` — Minimal API endpoint group mapped at `/api/v1/operator`
  - `ISessionReadModel` interface + `SessionReadModelRepository` — queries active sessions from nem.Comms local Marten projection (NOT from Mimir directly).
    **Message history mechanism**: Mimir publishes `MessageCreatedEvent` (already defined in `nem.Contracts/src/nem.Contracts/Events/`) on Wolverine bus whenever a message is persisted. nem.Comms consumes this event via a `MessageCreatedHandler` Wolverine handler that upserts into a local `SessionMessageProjection` Marten document. This projection stores: `SessionId`, `Messages[]` (sender, text, timestamp, channelType), `LastActivityAt`. The operator inbox reads from this local projection — no synchronous cross-service queries needed.
  - `MessageCreatedHandler.cs` — Wolverine handler consuming `MessageCreatedEvent` from bus, upserts into `SessionMessageProjection`
  - `SessionMessageProjection` — Marten document: `{ SessionId, TenantId, Messages: [{Sender, Text, Timestamp, ChannelType}], LastActivityAt }`
  - `SessionDetailDto`, `InboxItemDto`, `ClaimRequest`, `RespondRequest` — DTOs in `Comms.Application/Operator/`
  - `ClaimSessionHandler` — Wolverine handler that updates session assignment, publishes `SessionClaimedEvent` on bus
  - `OperatorRespondHandler` — Wolverine handler that resolves originating channel from session metadata, dispatches reply through correct `IChannelAdapter`
  - Wire Keycloak role check via `[Authorize(Policy = "CommsOperator")]`
  - Wire `ITenantContext` for tenant-scoped queries

  **REFACTOR** — Extract shared query filters (status, channel, date range) into `InboxQueryFilter` value object. Ensure all DTOs use records.

  **Must NOT do**:
  - Do NOT duplicate Mimir's Conversation/Message storage — read via bus query or local projection
  - Do NOT build a full admin UI — API only
  - Do NOT add WebSocket/SignalR for real-time updates (future scope)
  - Do NOT add operator-to-operator transfer (future scope)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Multi-endpoint API with authorization, tenant isolation, bus integration, and claim conflict logic requires deep reasoning
  - **Skills**: [`git-master`]
    - `git-master`: Atomic commit of API + handlers + tests
  - **Skills Evaluated but Omitted**:
    - `playwright`: No browser UI involved
    - `frontend-ui-ux`: Backend API only

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with T20, T27)
  - **Blocks**: F1, F2, F3, F4
  - **Blocked By**: T19 (routing engine — needed for respond-back routing), T24 (identity linking — needed for tenant-scoped session lookup)

  **References**:

  **Pattern References** (existing code to follow):
  - `nem.Mimir-typed-ids/src/Mimir.Api/Program.cs` — Minimal API endpoint registration pattern, Keycloak auth wiring
  - `nem.MCP/services/nem.MCP.Api/Endpoints/Configuration/ConfigurationEndpoints.cs` — Endpoint group structure: static `MapXxxEndpoints(this IEndpointRouteBuilder)` extension, response shapes, validation
  - `nem.Mimir-typed-ids/src/Mimir.Application/ChannelEvents/ChannelEventRouter.cs` — How channel routing resolves outbound adapter

  **API/Type References** (contracts to implement against):
  - `nem.Contracts/src/nem.Contracts/Channels/ChannelType.cs` — Channel enum for filtering
  - `nem.Contracts/src/nem.Contracts/Channels/InboundChannelMessage.cs` — Inbound message DTO shape for session detail
  - `nem.Contracts/src/nem.Contracts/Channels/OutboundChannelMessage.cs` — Outbound message DTO shape for operator replies
  - `nem.Contracts/src/nem.Contracts/Channels/IChannelMessageSender.cs` — Interface used by OperatorRespondHandler to dispatch replies
  - `nem.Contracts/src/nem.Contracts/Channels/ChannelMessageRef.cs` — Message reference for response correlation
  - T19's `ChannelRouter` (in `Comms.Application/Routing/ChannelRouter.cs`) — Used by `OperatorRespondHandler` to resolve which channel adapter to dispatch replies through
  - T6's `ChannelSession` aggregate — Session metadata queried for inbox items

  **External References**:
  - ASP.NET Minimal API docs: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis
  - Wolverine request/reply: https://wolverinefx.net/guide/messaging/request-reply.html

  **WHY Each Reference Matters**:
  - `Mimir.Api/Program.cs` — Copy the exact `app.MapGroup()` + `.RequireAuthorization()` pattern for consistency
  - `ChannelEventRouter` — The respond handler must use the same adapter-resolution logic to send replies back through the correct channel
  - `nem.Contracts/Messaging/` — Response DTOs must align with existing message shapes so frontends don't need dual parsing

  **Acceptance Criteria**:
  - [x] `OperatorInboxEndpoints.cs` exists with 4 endpoints mapped
  - [x] `dotnet test nem.Comms/tests/ --filter "Operator"` → PASS (≥8 tests)
  - [x] Claim conflict returns 409 with clear error body
  - [x] Tenant isolation enforced — operator A cannot see operator B's tenant sessions
  - [x] Respond dispatches through correct channel adapter based on session origin

  **QA Scenarios**:

  ```
  Scenario: Operator retrieves paginated inbox
    Tool: Bash (curl)
    Preconditions: nem.Comms running on localhost:5280, Keycloak token for operator user with comms:operator role, ≥3 active sessions seeded in DB
    Steps:
      1. curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:5280/api/v1/operator/inbox?limit=2&offset=0" -o response.json
      2. Assert HTTP 200, jq '.items | length' == 2, jq '.totalCount' >= 3
      3. curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:5280/api/v1/operator/inbox?limit=2&offset=2" -o response2.json
      4. Assert items in response2 do not overlap with response1 (by sessionId)
    Expected Result: Paginated results with correct total count, no duplicates across pages
    Failure Indicators: HTTP 401/403, totalCount mismatch, duplicate sessionIds across pages
    Evidence: .sisyphus/evidence/nem-classification-comms/task-25-inbox-pagination.json

  Scenario: Claim conflict returns 409
    Tool: Bash (curl)
    Preconditions: Active unclaimed session exists, two operator tokens available
    Steps:
      1. curl -s -X POST -H "Authorization: Bearer $TOKEN_A" "http://localhost:5280/api/v1/operator/sessions/{sessionId}/claim" → 200
      2. curl -s -X POST -H "Authorization: Bearer $TOKEN_B" "http://localhost:5280/api/v1/operator/sessions/{sessionId}/claim" -w "%{http_code}" → 409
      3. Assert response body contains "already claimed"
    Expected Result: First claim succeeds (200), second claim returns 409 Conflict
    Failure Indicators: Second claim returns 200 (race condition), or 500 (unhandled exception)
    Evidence: .sisyphus/evidence/nem-classification-comms/task-25-claim-conflict.json

  Scenario: Unauthorized user rejected
    Tool: Bash (curl)
    Preconditions: Token for user WITHOUT comms:operator role
    Steps:
      1. curl -s -H "Authorization: Bearer $NON_OPERATOR_TOKEN" "http://localhost:5280/api/v1/operator/inbox" -w "%{http_code}"
      2. Assert HTTP 403
    Expected Result: 403 Forbidden
    Failure Indicators: 200 (missing auth check), 401 (token valid but wrong error), 500
    Evidence: .sisyphus/evidence/nem-classification-comms/task-25-auth-rejected.txt
  ```

  **Commit**:
  - Message: `feat(comms): add operator unified inbox API with claim and respond`
  - Files: `nem.Contracts/src/nem.Contracts/Events/Integration/MessageCreatedEvent.cs`, `nem.Mimir-typed-ids/src/Mimir.Application/Conversations/Commands/SendMessage.cs`, `nem.Comms/src/Comms.Api/Endpoints/OperatorInboxEndpoints.cs`, `nem.Comms/src/Comms.Application/Operator/*`, `nem.Comms/src/Comms.Infrastructure/Persistence/SessionReadModelRepository.cs`, `nem.Comms/tests/**`
  - Pre-commit: `dotnet test nem.Comms/tests/ && dotnet test nem.Mimir-typed-ids/tests/Mimir.Application.Tests/`

- [x] 26. Classification Integration in nem.Comms

  **What to do**:

  **RED** — Write xunit tests for classification wiring in nem.Comms:
  - Test that `DataClassificationMiddleware` is registered in the HTTP pipeline and enriches `HttpContext.Items["DataClassification"]` from header or entity lookup
  - Test that `DataClassificationBehavior` (Wolverine) is registered and runs before message handlers, attaching classification metadata to `IMessageContext`
  - Test that inbound channel messages trigger classification: message text scanned for PII (Presidio), conversation classified based on channel rules (e.g., public WebWidget → Public, internal Teams → Internal by default)
  - Test that operator respond endpoint checks classification: if conversation is Confidential+, response is allowed (human-to-human), but any auto-reply/bot-generated content is blocked if it would leak Confidential data externally
  - Test that classification metadata propagates on outbound bus messages to Mimir

  **GREEN** — Implement classification integration:
  - In `Comms.Api/Program.cs`: add `app.UseDataClassification()` after auth middleware — references the middleware from `nem.Contracts.AspNetCore` (built in T8)
  - In `Comms.Api/Program.cs`: register `DataClassificationBehavior` in Wolverine config — `opts.Policies.Add<DataClassificationBehavior>()` (built in T10) — this enriches bus messages with classification metadata headers, it does NOT block/gate any messages
  - Create `Comms.Application/Classification/ChannelClassificationPolicy.cs` — maps channel types to default classification levels:
    - WebWidget → Public (external-facing)
    - Telegram → Internal (default, overridable)
    - Teams → Internal (corporate channel)
    - WhatsApp → Internal (default, overridable)
    - Signal → Confidential (privacy-focused channel)
  - Create `Comms.Application/Classification/MessageClassificationService.cs`:
    - On inbound message: resolve base level from `ChannelClassificationPolicy`, then call Presidio HTTP API for PII scan, set `hasPii` flag, elevate to max(channel-default, entity-override)
    - Attach `ClassificationResult` to message metadata before bus publish
  - Wire `IClassificationService` (T8's interface) via an HTTP client wrapper that calls nem.Classification API at `/api/v1/classify` for entity-level lookups
  - Wire Presidio HTTP client (from T3's shared service) for PII detection

  **REFACTOR** — Extract channel-to-classification mapping into configuration (`appsettings.json` section `Classification:ChannelDefaults`) so it's runtime-configurable without code changes.

  **Must NOT do**:
  - Do NOT block human operator responses based on classification — humans can respond to any classification level
  - Do NOT duplicate Presidio integration — reuse the shared Presidio service from T3
  - Do NOT add classification override UI — API-only override via T8's endpoints
  - Do NOT gate Wolverine bus messages between nem.Comms and Mimir — bus is internal trust boundary

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Cross-cutting integration touching middleware, Wolverine behaviors, channel adapters, and external service (Presidio) requires careful orchestration
  - **Skills**: [`git-master`]
    - `git-master`: Atomic commit of cross-cutting integration
  - **Skills Evaluated but Omitted**:
    - `playwright`: No browser UI
    - `frontend-ui-ux`: Backend service integration

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 6 (standalone — depends on Wave 5)
  - **Blocks**: F1, F2, F3, F4
  - **Blocked By**: T9 (HTTP middleware), T10 (Wolverine behavior), T24 (identity linking for entity-level classification lookup), T25 (operator API endpoints — QA uses `/api/v1/operator/inbox`)

  **References**:

  **Pattern References** (existing code to follow):
  - `nem.Contracts/src/nem.Contracts.AspNetCore/Authorization/OpaAuthorizationHandler.cs` — CANONICAL middleware registration pattern (`app.UseXxx()` extension method)
  - `nem/src/nem.Messaging/Infrastructure/WolverineConfiguration.cs` — How Wolverine behaviors/policies are registered
  - `nem.Mimir-typed-ids/src/Mimir.Api/Program.cs` — Middleware ordering reference (auth → classification → endpoints)

  **API/Type References** (contracts to implement against):
  - T5's `DataClassificationLevel` enum and `ClassificationResult` record in `nem.Contracts/Classification/`
  - T8's `IClassificationService` interface — for entity-level classification lookups
  - T9's `DataClassificationMiddleware` — the middleware being registered here
  - T10's `DataClassificationBehavior` — the Wolverine behavior being registered here
  - T3's Presidio HTTP API contract — `POST /analyze` with `text`, `language`, `entities` fields

  **External References**:
  - Presidio Analyzer API: https://microsoft.github.io/presidio/api-docs/api-docs.html#tag/Analyzer
  - Wolverine policies: https://wolverinefx.net/guide/handlers/middleware.html

  **WHY Each Reference Matters**:
  - `OpaAuthorizationHandler` — Follow the EXACT same `IApplicationBuilder.UseXxx()` extension pattern for classification middleware registration
  - `WolverineConfiguration.cs` — Shows where and how to add `.Policies.Add<T>()` in the Wolverine pipeline
  - T3's Presidio API — `MessageClassificationService` calls this for PII detection; must match request/response shapes
  - T5's types — All classification results must use these shared contract types, not local definitions

  **Acceptance Criteria**:
  - [x] `app.UseDataClassification()` present in `Comms.Api/Program.cs` after `app.UseAuthorization()`
  - [x] `DataClassificationBehavior` registered in Wolverine pipeline
  - [x] `dotnet test nem.Comms/tests/ --filter "Classification"` → PASS (≥6 tests)
  - [x] Channel-to-classification defaults configurable via `appsettings.json`
  - [x] Inbound message PII scan invokes Presidio and sets `hasPii` flag
  - [x] Outbound bus messages carry `ClassificationResult` in metadata envelope

  **QA Scenarios**:

  ```
  Scenario: WebWidget message with PII escalated to Restricted
    Tool: Bash (curl)
    Preconditions: nem.Comms + Presidio running, WebWidget adapter active, test tenant configured
    Steps:
      1. POST inbound webhook simulating WebWidget message with body: "Hi, my name is John Smith and my email is john@example.com"
         curl -s -X POST -H "Content-Type: application/json" -H "X-Tenant-Id: test-tenant" \
           -d '{"channel":"WebWidget","text":"Hi, my name is John Smith and my email is john@example.com","senderId":"visitor-1"}' \
           http://localhost:5280/api/v1/webhook/WebWidget
      2. Query session metadata: GET /api/v1/operator/inbox?channel=WebWidget&limit=1
      3. Assert classification in response: level == "Restricted", hasPii == true
         (WebWidget default is Public, but PII detected → T7 escalation rule raises to Restricted)
      4. Check Presidio was called: verify nem.Comms logs contain "Presidio analysis completed" with entities ["PERSON", "EMAIL_ADDRESS"]
    Expected Result: Message classified as Restricted (escalated from Public due to PII per T7 rule: PII + level < Restricted → Restricted), hasPii = true
    Failure Indicators: Classification level is "Public" (escalation didn't trigger), hasPii == false, Presidio not called
    Evidence: .sisyphus/evidence/nem-classification-comms/task-26-webwidget-pii.json

  Scenario: Signal message elevated to Confidential
    Tool: Bash (curl)
    Preconditions: nem.Comms running, Signal adapter active
    Steps:
      1. POST inbound Signal message (no PII): "Meeting at 3pm tomorrow"
      2. Query session metadata
      3. Assert classification level == "Confidential" (Signal default)
    Expected Result: Signal channel default applies Confidential classification
    Failure Indicators: Level is "Internal" or "Public" instead of "Confidential"
    Evidence: .sisyphus/evidence/nem-classification-comms/task-26-signal-confidential.json

  Scenario: WebWidget message WITHOUT PII classified as Public
    Tool: Bash (curl)
    Preconditions: nem.Comms + Presidio running, WebWidget adapter active
    Steps:
      1. POST inbound WebWidget message with NO PII: "What are your business hours?"
         curl -s -X POST -H "Content-Type: application/json" -H "X-Tenant-Id: test-tenant" \
           -d '{"channel":"WebWidget","text":"What are your business hours?","senderId":"visitor-2"}' \
           http://localhost:5280/api/v1/webhook/WebWidget
      2. Query session metadata: GET /api/v1/operator/inbox?channel=WebWidget&limit=1
      3. Assert classification: level == "Public" (WebWidget default, no PII escalation), hasPii == false
    Expected Result: WebWidget default (Public) applies without PII escalation
    Failure Indicators: Level is anything other than Public, hasPii incorrectly true
    Evidence: .sisyphus/evidence/nem-classification-comms/task-26-webwidget-no-pii.json

  Scenario: Classification metadata present on outbound bus message
    Tool: Bash (curl + RabbitMQ management API)
    Preconditions: nem.Comms + RabbitMQ running, test message sent via WebWidget with PII
    Steps:
      1. Send inbound message via WebWidget webhook (with PII): "Contact me at john@test.com"
      2. Check RabbitMQ management API for message on Mimir-bound queue: GET http://localhost:15672/api/queues/%2F/mimir.inbound/get (admin:admin)
      3. Parse message headers/properties for "X-Classification-Level" and "X-Classification-HasPii"
      4. Assert X-Classification-Level == "Restricted" and X-Classification-HasPii == "true" (PII triggers escalation from Public to Restricted per T7 rule)
    Expected Result: Bus message carries classification metadata in headers reflecting PII escalation
    Failure Indicators: Headers missing, wrong values (level shows "Public" despite PII), message not published to queue
    Evidence: .sisyphus/evidence/nem-classification-comms/task-26-bus-metadata.json
  ```

  **Commit**:
  - Message: `feat(comms): integrate data classification middleware, Wolverine behavior, and PII scanning`
  - Files: `nem.Comms/src/Comms.Api/Program.cs`, `nem.Comms/src/Comms.Application/Classification/*`, `nem.Comms/src/Comms.Api/appsettings.json`, `nem.Comms/tests/**`
  - Pre-commit: `dotnet test nem.Comms/tests/`

- [x] 27. Docker Compose — Full Stack

  **What to do**:

  **RED** — Write a shell-based integration smoke test:
  - Script `scripts/test-full-stack.sh` that: runs `docker compose -f docker-compose.classification.yml up -d`, waits for all services healthy (timeout 120s), curls each service health endpoint, asserts all return 200, then tears down
  - Test service connectivity: nem.Classification can reach Presidio, nem.Comms can reach RabbitMQ + PostgreSQL + Keycloak, OPA is reachable

  **GREEN** — Create `docker-compose.classification.yml` in repo root:
  - **PostgreSQL 16**: port 5432, init script creates databases `comms_db` and `classification_db`, healthcheck via `pg_isready`
  - **RabbitMQ 3.13-management**: port 5672 + 15672 (management), healthcheck via `rabbitmq-diagnostics -q ping`
  - **Keycloak 24**: port 8080, healthcheck via `/health/ready`, realm import from `docker/keycloak/nem-realm.json` containing:
      - Realm `nem` with OIDC login enabled
      - Client `nem-test` (client_credentials grant, `client_secret=test-secret`, public=false) for QA/integration tests
      - Client `nem-classification` (client_credentials grant) for service-to-service auth
      - Client `nem-comms` (client_credentials grant) for service-to-service auth
      - Realm roles: `FederationAdmin`, `ClassificationAdmin`, `comms:operator`
      - Service account for `nem-test` client with `FederationAdmin` and `ClassificationAdmin` roles assigned
      - Volume mount: `./docker/keycloak/nem-realm.json:/opt/keycloak/data/import/nem-realm.json`
      - Command: `start-dev --import-realm`
  - **OPA 0.68**: port 8181, volume-mount policies from `nem.MCP/policies/`, healthcheck via `/health`
  - **Presidio Analyzer**: port 5001 (from T3's Dockerfile), healthcheck via `GET /health`
  - **nem.Classification**: port 5270, depends_on Presidio + PostgreSQL + OPA, env vars for connection strings, healthcheck via `/health`
  - **nem.Comms**: port 5280, depends_on RabbitMQ + PostgreSQL + Keycloak + nem.Classification, env vars for all connection strings, healthcheck via `/health`
  - **OpenBao**: image `openbao/openbao:2.1`, port 8200, dev mode (`server -dev`), env `VAULT_DEV_ROOT_TOKEN_ID=dev-root-token`, healthcheck via `GET /v1/sys/health`, no depends_on (standalone secrets engine)
  - **nem.MCP API**: port 5000, depends_on PostgreSQL, env vars for database connection, healthcheck via `/health`
  - **nem.MCP Angular UI**: built via `npm run build` in `nem.MCP/packages/web-app/`, served on port 4200, depends_on nem.MCP API, healthcheck via HTTP GET on root
  - **nem.Mimir**: built from `nem.Mimir-typed-ids/docker/api/Dockerfile`, port 5223, depends_on PostgreSQL + RabbitMQ + Keycloak, env vars for database + LiteLLM connection strings (ClassificationGatingHandler wires automatically via DI), healthcheck via `/health`
  - **nem.KnowHub**: built from `nem.KnowHub/Dockerfile_Api`, port 5100 (dev port), depends_on PostgreSQL + Presidio, env vars for database + embedding + classification connection strings, healthcheck via `/health`
  - Shared Docker network `nem-classification-net`
  - Create `docker/keycloak/nem-realm.json` — Keycloak realm export containing: realm `nem`, clients `nem-test`/`nem-classification`/`nem-comms`, roles `FederationAdmin`/`ClassificationAdmin`/`comms:operator`, service account role mappings (see Keycloak service definition above)
  - `.env.classification` file with all default connection strings and secrets (development-only values), including `KEYCLOAK_CLIENT_SECRET=test-secret`

  **REFACTOR** — Add `profiles` to docker-compose so operators can run subsets: `docker compose --profile classification-only up` (Classification + Presidio + OPA + shared infra, skips Comms), `docker compose --profile comms-only up` (Comms + nem.Classification + Presidio + OPA + shared infra — includes Classification dependencies because Comms uses classification middleware).

  **Must NOT do**:
  - Do NOT use `latest` tags — pin ALL image versions
  - Do NOT include production secrets — development-only `.env` file
  - Do NOT add Nginx/reverse-proxy — direct port mapping for dev
  - Do NOT duplicate existing docker-compose files from other nem.* repos — this is additive

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Docker Compose is declarative YAML configuration, no complex logic — well-suited for quick category
  - **Skills**: [`git-master`]
    - `git-master`: Clean commit of infra files
  - **Skills Evaluated but Omitted**:
    - `playwright`: No browser interaction needed
    - `frontend-ui-ux`: Infrastructure task

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with T20, T25)
  - **Blocks**: F1, F2, F3, F4
  - **Blocked By**: T3 (Presidio Dockerfile), T8 (Classification API Dockerfile), T17 (WebWidget adapter), T18 (Teams adapter)

  **References**:

  **Pattern References** (existing code to follow):
  - `nem.KnowHub-enhancement-ocr/docker-compose.yml` — Reference for service definition patterns, healthcheck syntax, depends_on with condition
  - `nem.Mimir-typed-ids/docker-compose.yml` or equivalent — How existing nem services define compose services
  - `nem.MCP/policies/` — OPA policy files to volume-mount

  **API/Type References** (contracts to implement against):
  - T3's `presidio/Dockerfile` — Presidio image name and exposed port
  - T8's `nem.Classification/Dockerfile` — Classification service image and exposed port
  - T13's `nem.Comms/Dockerfile` — Comms service image and exposed port

  **External References**:
  - Docker Compose specification: https://docs.docker.com/reference/compose-file/
  - Keycloak Docker: https://www.keycloak.org/server/containers
  - RabbitMQ Docker: https://hub.docker.com/_/rabbitmq

  **WHY Each Reference Matters**:
  - `nem.KnowHub-enhancement-ocr/docker-compose.yml` — Copy healthcheck syntax and depends_on condition patterns for consistency across nem.* ecosystem
  - `nem.MCP/policies/` — OPA needs these policy files mounted to evaluate classification rules
  - Service Dockerfiles from T3/T8/T13 — Must match exposed ports, expected env vars, and health endpoints

  **Acceptance Criteria**:
  - [x] `docker-compose.classification.yml` exists with all 12 services defined (PostgreSQL, RabbitMQ, Keycloak, OPA, Presidio, nem.Classification, nem.Comms, OpenBao, nem.MCP API, nem.MCP Angular UI, nem.Mimir, nem.KnowHub)
  - [x] `docker/keycloak/nem-realm.json` exists with realm `nem`, clients `nem-test`/`nem-classification`/`nem-comms`, roles `FederationAdmin`/`ClassificationAdmin`/`comms:operator`, and service account role mappings
  - [x] `docker compose -f docker-compose.classification.yml config` → valid (no syntax errors)
  - [x] `docker compose -f docker-compose.classification.yml up -d` → all services reach "healthy" within 120s
  - [x] Each service healthcheck endpoint returns 200
  - [x] `.env.classification` contains all required env vars with dev defaults
  - [x] Profile `classification-only` starts only Presidio + OPA + PostgreSQL + nem.Classification
  - [x] Profile `comms-only` starts RabbitMQ + PostgreSQL + Keycloak + Presidio + nem.Classification + nem.Comms (comms requires classification)

  **QA Scenarios**:

  ```
  Scenario: Full stack starts and all services healthy
    Tool: Bash
    Preconditions: Docker daemon running, all service images built (T3, T8, T13 complete)
    Steps:
      1. docker compose -f docker-compose.classification.yml up -d
      2. Wait loop (max 120s, poll every 5s): docker compose -f docker-compose.classification.yml ps --format json | jq 'select(.Health != "healthy")'
       3. Assert all 12 services show Health: "healthy"
       4. curl -sf http://localhost:5001/health → 200 (Presidio)
       5. curl -sf http://localhost:5270/health → 200 (nem.Classification)
       6. curl -sf http://localhost:5280/health → 200 (nem.Comms)
       7. curl -sf http://localhost:8181/health → 200 (OPA)
       8. curl -sf http://localhost:8080/health/ready → 200 (Keycloak)
       9. curl -sf http://localhost:15672/api/healthchecks/node -u guest:guest → 200 (RabbitMQ)
       10. curl -sf http://localhost:8200/v1/sys/health → 200 (OpenBao)
       11. curl -sf http://localhost:5000/health → 200 (nem.MCP API)
       12. curl -sf http://localhost:4200/ → 200 (nem.MCP Angular UI)
       13. curl -sf http://localhost:5223/health → 200 (nem.Mimir)
       14. curl -sf http://localhost:5100/health → 200 (nem.KnowHub)
    Expected Result: All 12 services healthy, all health endpoints return 200
    Failure Indicators: Any service stuck in "starting" after 120s, health endpoint returns non-200, container exit code != 0
    Evidence: .sisyphus/evidence/nem-classification-comms/task-27-full-stack-health.txt

  Scenario: Classification-only profile starts subset
    Tool: Bash
    Preconditions: Docker daemon running
    Steps:
      1. docker compose -f docker-compose.classification.yml --profile classification-only up -d
      2. docker compose -f docker-compose.classification.yml ps --format "{{.Name}}"
      3. Assert: presidio, opa, postgresql, nem-classification are running
      4. Assert: nem-comms, rabbitmq, keycloak are NOT running
    Expected Result: Only classification-related services start
    Failure Indicators: Comms-related services start, or classification services fail to start
    Evidence: .sisyphus/evidence/nem-classification-comms/task-27-profile-classification.txt

  Scenario: Service tear down is clean
    Tool: Bash
    Preconditions: Full stack running from previous scenario
    Steps:
      1. docker compose -f docker-compose.classification.yml down -v
      2. docker compose -f docker-compose.classification.yml ps
      3. Assert no containers running, volumes removed
    Expected Result: Clean teardown with no orphaned containers or volumes
    Failure Indicators: Containers still running, volumes persisted
    Evidence: .sisyphus/evidence/nem-classification-comms/task-27-teardown.txt
  ```

  **Commit**:
  - Message: `infra: add full-stack docker-compose for classification and comms services`
  - Files: `docker-compose.classification.yml`, `.env.classification`, `scripts/test-full-stack.sh`, `docker/keycloak/nem-realm.json`
  - Pre-commit: `docker compose -f docker-compose.classification.yml config`

- [x] 28. End-to-End Integration Tests

  **What to do**:

  **RED** — Write xunit integration tests using Testcontainers:
  - **Inbound-to-Bus E2E**: WebWidget webhook POST → nem.Comms receives → routes → publishes to RabbitMQ → Mimir-bound queue has message with correct envelope (channel, tenant, classification metadata)
  - **Classification Gating E2E**: Classify a document as Confidential via nem.Classification API → attempt to send to external LLM via mock LLM endpoint → assert request is BLOCKED with classification error. Then classify as Public → assert request is ALLOWED
  - **PII Detection E2E**: Send message containing "My SSN is 123-45-6789 and my name is Jane Doe" → assert Presidio detects PERSON entity → assert `hasPii = true` in classification result → assert PII entities are logged in audit trail
  - **Multi-Channel Routing E2E**: Send messages via WebWidget and Telegram webhooks simultaneously → assert each routes to correct queue/handler → assert classification levels differ (Public vs Internal)
  - **Operator Flow E2E**: Inbound message → operator claims session → operator responds → response routed back through originating channel adapter (mock outbound)

  **GREEN** — Implement integration test infrastructure:
  - `nem.Comms/tests/Comms.IntegrationTests/` project using Testcontainers
  - `TestcontainersFixture.cs` — starts PostgreSQL, RabbitMQ, Presidio containers; configures nem.Comms and nem.Classification as in-process `WebApplicationFactory<T>` instances
  - Each E2E test class inherits from `IntegrationTestBase` which provides HTTP clients for all services, RabbitMQ consumer for asserting published messages, and DB access for asserting state
  - Mock external LLM endpoint using `WireMock.Net` — records whether requests were allowed/blocked
  - Mock channel outbound adapters — record responses for operator flow verification

  **REFACTOR** — Extract shared test builders: `InboundMessageBuilder`, `ClassificationRequestBuilder`, `OperatorFlowBuilder` for readable test setup.

  **Must NOT do**:
  - Do NOT test against real external services (Telegram API, Teams API, real LLMs) — all external dependencies are mocked
  - Do NOT create flaky tests with arbitrary `Task.Delay` — use polling with timeout for async assertions
  - Do NOT test unit-level logic here — only cross-service integration paths
  - Do NOT require Docker Compose — Testcontainers manages containers independently

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: E2E tests crossing multiple services with async messaging, container orchestration, and mock management require deep reasoning
  - **Skills**: [`git-master`]
    - `git-master`: Atomic commit of test infrastructure + all E2E tests
  - **Skills Evaluated but Omitted**:
    - `playwright`: Tests are API-level, not browser-based
    - `frontend-ui-ux`: Backend integration testing

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 7 (standalone — depends on Wave 6)
  - **Blocks**: F1, F2, F3, F4
  - **Blocked By**: T7 (classification engine), T8 (classification API), T16 (webhook ingestion), T17 (WebWidget adapter — for WebWidget E2E), T18 (Teams adapter), T19 (routing engine), T21 (Telegram adapter — for multi-channel E2E), T26 (classification middleware integration)

  **References**:

  **Pattern References** (existing code to follow):
  - `nem.Mimir-typed-ids/tests/Mimir.Api.IntegrationTests/` — xunit test project structure, Testcontainers patterns, assertion conventions, .csproj references
  - `nem/src/nem.Messaging/Infrastructure/WolverineConfiguration.cs` — Understanding bus topology for asserting message routing
  - `nem.Mimir-typed-ids/src/Mimir.Application/ChannelEvents/ChannelEventRouter.cs` — Channel routing logic that E2E tests must validate

  **API/Type References** (contracts to implement against):
  - T5's `DataClassificationLevel`, `ClassificationResult` — assertion shapes for classification E2E
  - T14's WebWidget webhook contract — request shape for inbound E2E
  - T21's Telegram webhook contract — request shape for multi-channel E2E (Telegram channel)
  - T25's operator endpoints — request/response shapes for operator flow E2E
  - T8's `POST /api/v1/classify` — request shape for classification gating E2E

  **External References**:
  - Testcontainers .NET: https://dotnet.testcontainers.org/
  - WireMock.Net: https://github.com/WireMock-Net/WireMock.Net
  - xunit collection fixtures: https://xunit.net/docs/shared-context

  **WHY Each Reference Matters**:
  - `Mimir.Api.IntegrationTests/` — Follow exact same test project structure (.csproj references, test naming, Testcontainers setup, assertion style) for consistency
  - `WolverineConfiguration.cs` — Understanding exchange/queue topology is critical for asserting messages arrive at the correct RabbitMQ queue
  - Testcontainers docs — Container lifecycle, network configuration, and wait strategies for reliable test startup
  - WireMock.Net — Used for mock LLM endpoint to verify classification gating blocks/allows requests

  **Acceptance Criteria**:
  - [x] `Comms.IntegrationTests.csproj` exists with Testcontainers + WireMock.Net dependencies
  - [x] `dotnet test nem.Comms/tests/Comms.IntegrationTests/` → PASS (≥5 E2E tests, 0 failures)
  - [x] No test uses `Task.Delay` — all async assertions use polling with configurable timeout
  - [x] Inbound-to-Bus test verifies message arrives on correct RabbitMQ queue with classification metadata
  - [x] Classification Gating test verifies Confidential data blocked from mock LLM, Public data allowed
  - [x] PII Detection test verifies Presidio integration and `hasPii` flag
  - [x] Multi-Channel test verifies different classification defaults per channel
  - [x] Operator Flow test verifies claim → respond → outbound routing

  **QA Scenarios**:

  ```
  Scenario: All E2E tests pass in clean environment
    Tool: Bash
    Preconditions: Docker daemon running (for Testcontainers), all nem.Comms + nem.Classification projects build successfully
    Steps:
      1. dotnet build nem.Comms/tests/Comms.IntegrationTests/ → exit code 0
      2. dotnet test nem.Comms/tests/Comms.IntegrationTests/ --verbosity normal --logger "console;verbosity=detailed" 2>&1 | tee test-output.txt
      3. Assert exit code 0
      4. Assert output contains "Passed!" with ≥5 tests
      5. Assert output contains NO "Failed!" lines
      6. Assert test execution time < 180s (containers should start within 60s)
    Expected Result: All E2E tests pass, containers managed automatically by Testcontainers
    Failure Indicators: Container startup timeout, test assertion failure, flaky async timing
    Evidence: .sisyphus/evidence/nem-classification-comms/task-28-e2e-results.txt

  Scenario: Classification gating blocks Confidential data from LLM
    Tool: Bash
    Preconditions: E2E test suite passes (previous scenario)
    Steps:
      1. grep -A 20 "Classification_Gating" test-output.txt
      2. Assert test output shows: document classified as Confidential → LLM request intercepted → WireMock received 0 requests (blocked)
      3. Assert test output shows: document classified as Public → LLM request allowed → WireMock received 1 request
    Expected Result: Confidential blocks LLM, Public allows LLM — zero false positives/negatives
    Failure Indicators: WireMock shows request for Confidential doc (leak), or no request for Public doc (over-blocking)
    Evidence: .sisyphus/evidence/nem-classification-comms/task-28-gating-detail.txt

  Scenario: No flaky tests on repeated runs
    Tool: Bash
    Preconditions: E2E tests passed once
    Steps:
      1. Run dotnet test 3 times in sequence with --no-build
      2. Assert all 3 runs pass with same test count
      3. Assert no test has different result across runs
    Expected Result: 3/3 runs pass — zero flakiness
    Failure Indicators: Any run fails, test count differs between runs
    Evidence: .sisyphus/evidence/nem-classification-comms/task-28-flakiness-check.txt
  ```

  **Commit**:
  - Message: `test(comms): add E2E integration tests for classification gating, PII detection, and multi-channel routing`
  - Files: `nem.Comms/tests/Comms.IntegrationTests/**`
  - Pre-commit: `dotnet test nem.Comms/tests/Comms.IntegrationTests/`

- [x] 29. MCP Backend — Extend Config for Classification & Comms Services

  **What to do**:
  - **RED**: Write tests for:
    - `McpTargetService` enum includes `Classification = 2` and `Comms = 3`
    - `PUT /api/v1/config/{serviceId}/{key}` publishes `ConfigurationChangedEvent` via Wolverine bus
    - `ConfigurationChangedEvent` contains `ServiceId`, `Key`, `Value`, `ChangedAt`, `ChangedBy`
    - Bulk update also publishes one event per changed key
  - **GREEN**: Implement:
    - Add `Classification = 2` and `Comms = 3` to `McpTargetService` enum in `nem.MCP/services/nem.MCP.Core/Domain/McpConfig/McpTargetService.cs`
    - Create `ConfigurationChangedEvent` record in `nem.MCP/services/nem.MCP.Core/Domain/Configuration/ConfigurationChangedEvent.cs` with properties: `string ServiceId, string Key, string? Value, bool IsSecret, DateTimeOffset ChangedAt, string ChangedBy`
    - Modify `ConfigurationManagementService` to publish `ConfigurationChangedEvent` via `IMessageBus` after every `SetConfigAsync` and `BulkUpdateAsync` call
    - Register `ConfigurationChangedEvent` in Wolverine topology for bus propagation to subscriber services
  - **REFACTOR**: Ensure event publishing doesn't break existing config operations

  **Must NOT do**:
  - Do NOT change existing Mimir/Cognitive config sync behavior
  - Do NOT modify existing config API contracts — only add event publishing as side-effect
  - Do NOT add new REST endpoints — existing `/api/v1/config` API is sufficient

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small targeted changes to an existing service — enum extension + event publishing
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No browser interaction needed — backend only

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with T1, T2, T3, T4, T5)
  - **Blocks**: T30, T31, T32
  - **Blocked By**: None — MCP exists, just extending it

  **References**:

  **Pattern References** (existing code to follow):
  - `nem.MCP/services/nem.MCP.Core/Domain/McpConfig/McpTargetService.cs` — Existing enum to extend (currently: Mimir=0, Cognitive=1)
  - `nem.MCP/services/nem.MCP.Api/Endpoints/Configuration/ConfigurationEndpoints.cs` — Existing config API that calls ConfigurationManagementService
  - `nem.MCP/services/nem.MCP.Infrastructure/Configuration/ConfigurationServiceCollectionExtensions.cs` — DI registration for config management
  - `nem/src/nem.Messaging/Infrastructure/WolverineConfiguration.cs` — Wolverine event registration pattern

  **API/Type References**:
  - `nem.Contracts/src/nem.Contracts/ControlPlane/IConfigurationManager.cs` — Contract interface (GetConfigAsync, SetConfigAsync, BulkUpdateAsync)

  **Acceptance Criteria**:
  - [x] `McpTargetService` enum has `Classification = 2` and `Comms = 3`
  - [x] `ConfigurationChangedEvent` record exists with correct properties
  - [x] `PUT /api/v1/config/classification/test.key` triggers event on bus
  - [x] `dotnet test nem.MCP` → PASS

  **QA Scenarios**:
  ```
  Scenario: Config change publishes event
    Tool: Bash (dotnet test)
    Preconditions: nem.MCP solution builds
    Steps:
      1. Run dotnet test with filter for ConfigurationChanged tests
      2. Assert test verifies: SetConfigAsync("classification", "level.default", "Confidential") publishes ConfigurationChangedEvent with ServiceId="classification", Key="level.default"
      3. Assert bulk update with 3 keys publishes 3 events
    Expected Result: All config-change event tests pass
    Failure Indicators: Events not published, wrong ServiceId, missing keys
    Evidence: .sisyphus/evidence/nem-classification-comms/task-29-config-event.txt

  Scenario: Enum extension doesn't break existing
    Tool: Bash (dotnet build + test)
    Preconditions: nem.MCP builds before changes
    Steps:
      1. dotnet build nem.MCP/services/ — assert 0 errors
      2. dotnet test nem.MCP/ — assert existing tests still pass
      3. Verify McpTargetService.Mimir and McpTargetService.Cognitive still resolve to 0 and 1
    Expected Result: Zero regressions, new enum values added cleanly
    Failure Indicators: Build errors, existing test failures, enum value shifts
    Evidence: .sisyphus/evidence/nem-classification-comms/task-29-no-regression.txt
  ```

  **Commit**: YES
  - Message: `feat(mcp): extend McpTargetService enum and publish ConfigurationChangedEvent on config writes`
  - Files: `nem.MCP/services/nem.MCP.Core/Domain/McpConfig/McpTargetService.cs, nem.MCP/services/nem.MCP.Core/Domain/Configuration/ConfigurationChangedEvent.cs, nem.MCP/services/nem.MCP.Infrastructure/Configuration/*`
  - Pre-commit: `dotnet test nem.MCP`

- [x] 30. MCP Angular UI — Service Configuration Management Page

  **What to do**:
  - Create new Angular page at `nem.MCP/packages/web-app/src/app/domain/service-config/`
  - **Page structure**:
    - Service selector dropdown (populated from `/api/v1/services` registry)
    - Key-value config table for selected service (from `/api/v1/config/{serviceId}`)
    - Add/Edit/Delete config entries
    - `isSecret` toggle per entry (masked display for secrets)
    - Bulk import/export (JSON)
  - **Labeled config sections** for known services:
    - Classification section: classification levels, PII config, LLM gating, Presidio connection, enforcement mode
    - Comms section: channel toggles, webhook config, routing strategy, delivery/retry config
    - Each section shows human-readable labels with descriptions, not raw key names
  - Add route: `{ path: 'service-config', component: ServiceConfigPage }` in `app.routes.ts`
  - Add sidebar nav item: `{ name: 'Service Config', icon: 'settings_applications', route: '/service-config' }` after 'Settings'
  - Wire to existing REST API: `GET/PUT/DELETE /api/v1/config/{serviceId}/{key}` and `POST /api/v1/config/bulk`

  **Must NOT do**:
  - Do NOT create new backend endpoints — use existing `/api/v1/config` API
  - Do NOT modify existing Angular pages (policies, settings, etc.)
  - Do NOT add inline config editing in other pages — this is the ONE config page

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Angular UI page with form components, tables, section layout
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Config editor needs good UX — section grouping, masked secrets, bulk operations
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not needed during build — QA scenarios use it post-build

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (with T6, T7, T9, T10, T11, T12)
  - **Blocks**: F1, F2, F3
  - **Blocked By**: T29 (needs updated McpTargetService enum for service list)

  **References**:

  **Pattern References** (existing code to follow):
  - `nem.MCP/packages/web-app/src/app/domain/policies/policies.page.ts` — Page structure pattern: list view, detail view, edit forms
  - `nem.MCP/packages/web-app/src/app/core/sidebar/sidebar.component.ts` — Where to add nav item (navItems array)
  - `nem.MCP/packages/web-app/src/app/app.routes.ts` — Where to add route
  - `nem.MCP/packages/web-app/src/app/domain/settings/settings.page.ts` — Simpler page pattern for reference

  **API/Type References**:
  - `nem.MCP/services/nem.MCP.Api/Endpoints/Configuration/ConfigurationEndpoints.cs` — REST API to wire against: GET/PUT/DELETE per key, bulk POST
  - `nem.MCP/services/nem.MCP.Api/Endpoints/ServiceRegistry/ServiceRegistryEndpoints.cs` — GET /api/v1/services for service list dropdown

  **Acceptance Criteria**:
  - [x] Route `/service-config` loads the page
  - [x] Sidebar shows "Service Config" nav item
  - [x] Service selector dropdown populates from registry API
  - [x] Config table shows all keys for selected service
  - [x] Add/Edit/Delete operations persist via REST API
  - [x] Secret values are masked in display
  - [x] Classification and Comms sections show human-readable config groups
  - [x] `ng build` → 0 errors

  **QA Scenarios**:
  ```
  Scenario: Navigate to Service Config page
    Tool: Playwright
    Preconditions: nem.MCP UI running on localhost:4200, user authenticated
    Steps:
      1. Navigate to http://localhost:4200/service-config
      2. Assert page title contains "Service Configuration" (selector: h1, h2, or .page-title)
      3. Assert service selector dropdown is visible (selector: mat-select or select[data-testid="service-selector"])
      4. Assert sidebar has "Service Config" item highlighted
    Expected Result: Page loads with service selector and empty config table
    Failure Indicators: 404, blank page, missing selector dropdown
    Evidence: .sisyphus/evidence/nem-classification-comms/task-30-page-load.png

  Scenario: Edit a classification config value
    Tool: Playwright
    Preconditions: nem.Classification registered in service registry, at least 1 config key exists
    Steps:
      1. Navigate to /service-config
      2. Select "classification" from service dropdown
      3. Assert config table shows existing keys (e.g., "level.default")
      4. Click edit on "level.default" row
      5. Change value from "Confidential" to "Internal"
      6. Click save
      7. Assert toast/notification shows "Configuration saved"
      8. Refresh page — assert value persists as "Internal"
    Expected Result: Config edit persists across page refresh
    Failure Indicators: Save fails, value reverts, API error
    Evidence: .sisyphus/evidence/nem-classification-comms/task-30-config-edit.png

  Scenario: Secret value is masked
    Tool: Playwright
    Preconditions: A config entry with isSecret=true exists
    Steps:
      1. Navigate to /service-config, select service
      2. Assert secret entry value column shows "••••••••" or similar mask (selector: .secret-mask, [data-secret="true"])
      3. Click reveal/eye icon if present
      4. Assert actual value is shown temporarily
    Expected Result: Secrets masked by default, revealable on click
    Failure Indicators: Secret shown in plaintext, no mask indicator
    Evidence: .sisyphus/evidence/nem-classification-comms/task-30-secret-mask.png
  ```

  **Commit**: YES
  - Message: `feat(mcp-ui): add Service Configuration management page with config editor`
  - Files: `nem.MCP/packages/web-app/src/app/domain/service-config/**, nem.MCP/packages/web-app/src/app/app.routes.ts, nem.MCP/packages/web-app/src/app/core/sidebar/sidebar.component.ts`
  - Pre-commit: `ng build`

- [x] 31. Wire nem.Classification to MCP Configuration

  **What to do**:
  - **RED**: Write tests for:
    - On startup, service registers with MCP via `POST /api/v1/services` (Id="classification", Name="nem.Classification", HealthEndpoint="/health")
    - Service reads classification config from MCP: `IConfigurationManager.GetConfigAsync("classification", key)` for keys: `level.default`, `pii.entities`, `pii.confidence_threshold`, `presidio.url`, `presidio.timeout_ms`, `enforcement.mode`, `gating.allowed_levels`
    - Falls back to `appsettings.json` values when MCP is unreachable
    - `ConfigurationChangedEvent` handler updates `IOptionsMonitor<ClassificationOptions>` at runtime
  - **GREEN**: Implement:
    - Create `McpIntegration/McpServiceRegistrar.cs` — `IHostedService` that calls `POST /api/v1/services` on startup
    - Create `McpIntegration/McpConfigurationProvider.cs` — Custom `IConfigurationProvider` that reads from MCP and populates `IConfiguration`
    - Create `McpIntegration/ConfigurationChangedHandler.cs` — Wolverine handler for `ConfigurationChangedEvent` that triggers config reload
    - Register in DI: `services.AddMcpIntegration(configuration)` in `Program.cs`
    - Define config key mapping: MCP key → .NET Options property (e.g., `level.default` → `ClassificationOptions.DefaultLevel`)
  - **REFACTOR**: Ensure MCP unavailability doesn't prevent service startup (graceful degradation)

  **Must NOT do**:
  - Do NOT make MCP a hard dependency — service MUST start without MCP (fallback to appsettings)
  - Do NOT store secrets in MCP config — credentials stay in OpenBao via `ISecretProvider`
  - Do NOT modify MCP backend code — only consume existing APIs

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Integration pattern with config provider, hosted service, and event handler
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No browser interaction — backend integration only

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with T15, T17, T18, T19, T21, T22, T23, T32)
  - **Blocks**: F1, F3
  - **Blocked By**: T2 (classification scaffold), T7 (classification engine — needs ClassificationOptions), T29 (MCP config events)

  **References**:

  **Pattern References** (existing code to follow):
  - `nem.Contracts/src/nem.Contracts/ControlPlane/IConfigurationManager.cs` — Contract for reading/writing config (GetConfigAsync, SetConfigAsync)
  - `nem.Contracts/src/nem.Contracts.AspNetCore/Secrets/NemSecretsExtensions.cs` — Pattern for `AddNemX(configuration)` DI extension
  - `nem.MCP/services/nem.MCP.Api/Endpoints/ServiceRegistry/ServiceRegistryEndpoints.cs` — POST /api/v1/services registration API
  - `nem.MCP/services/nem.MCP.Api/Endpoints/Configuration/ConfigurationEndpoints.cs` — GET /api/v1/config/{serviceId} API

  **API/Type References**:
  - `nem.MCP/services/nem.MCP.Core/Domain/Configuration/ConfigurationChangedEvent.cs` — Event to subscribe to (created in T29)

  **Acceptance Criteria**:
  - [x] Service registers with MCP on startup (verify via `GET /api/v1/services` showing "classification")
  - [x] Config values from MCP override appsettings defaults
  - [x] Service starts cleanly when MCP is unavailable (falls back to appsettings)
  - [x] Config change event triggers runtime update of `ClassificationOptions`
  - [x] `dotnet test nem.Classification` → PASS

  **QA Scenarios**:
  ```
  Scenario: Service registers with MCP on startup
    Tool: Bash (curl)
    Preconditions: MCP running on localhost:5000, nem.Classification starting, Keycloak running with test realm
    Steps:
      1. Acquire auth token: `TOKEN=$(curl -s -X POST http://localhost:8080/realms/nem/protocol/openid-connect/token -d 'grant_type=client_credentials&client_id=nem-test&client_secret=test-secret' | jq -r '.access_token')`
      2. Start nem.Classification service
      3. curl -H "Authorization: Bearer $TOKEN" GET http://localhost:5000/api/v1/services
      4. Parse JSON response, find entry with Id="classification"
      5. Assert Name="nem.Classification", HealthEndpoint="/health"
    Expected Result: classification service appears in registry within 10 seconds of startup
    Failure Indicators: Service not in registry, wrong metadata, registration timeout, 401/403 on API
    Evidence: .sisyphus/evidence/nem-classification-comms/task-31-service-registered.txt

  Scenario: MCP config overrides appsettings
    Tool: Bash (curl + dotnet test)
    Preconditions: MCP has classification config: level.default=Internal (appsettings has Confidential), Keycloak running
    Steps:
      1. Acquire auth token (same as above)
      2. curl -H "Authorization: Bearer $TOKEN" -X PUT http://localhost:5000/api/v1/config/classification/level.default -H "Content-Type: application/json" -d '{"value": "Internal"}'
      3. Start nem.Classification
      4. curl -H "Authorization: Bearer $TOKEN" -X POST http://localhost:5270/api/v1/classify -H "Content-Type: application/json" -d '{"text":"test doc","entityType":"Document","entityId":"test-doc-1"}' | jq '.level'
      5. Assert response shows level derived from defaultLevel=Internal (not Confidential)
    Expected Result: MCP config value takes precedence over appsettings
    Failure Indicators: Still using Confidential, config not read from MCP
    Evidence: .sisyphus/evidence/nem-classification-comms/task-31-config-override.txt

  Scenario: Graceful degradation without MCP
    Tool: Bash (dotnet run)
    Preconditions: MCP is NOT running
    Steps:
      1. Start nem.Classification without MCP available
      2. Assert service starts successfully (no crash, no unhandled exception)
      3. Assert service uses appsettings.json values as fallback
      4. curl GET http://localhost:5270/health — assert 200 OK
    Expected Result: Service starts and operates with appsettings defaults
    Failure Indicators: Startup crash, timeout, health check fails
    Evidence: .sisyphus/evidence/nem-classification-comms/task-31-graceful-fallback.txt
  ```

  **Commit**: YES
  - Message: `feat(classification): integrate MCP configuration with service registration, config pull, and change events`
  - Files: `nem.Classification/src/Classification.Api/McpIntegration/*, nem.Classification/src/Classification.Api/Program.cs`
  - Pre-commit: `dotnet test nem.Classification`

- [x] 32. Wire nem.Comms to MCP Configuration

  **What to do**:
  - **RED**: Write tests for:
    - On startup, service registers with MCP via `POST /api/v1/services` (Id="comms", Name="nem.Comms", HealthEndpoint="/health")
    - Service reads comms config from MCP: `IConfigurationManager.GetConfigAsync("comms", key)` for keys: `channels.telegram.enabled`, `channels.teams.enabled`, `channels.whatsapp.enabled`, `channels.signal.enabled`, `channels.webwidget.enabled`, `webhook.rate_limit`, `routing.strategy`, `routing.queue_priority`, `delivery.max_retries`, `delivery.backoff_ms`, `delivery.dlq_threshold`
    - Falls back to `appsettings.json` when MCP is unreachable
    - `ConfigurationChangedEvent` handler updates `IOptionsMonitor<CommsOptions>` and `IOptionsMonitor<ChannelOptions>` at runtime
    - Channel enable/disable changes take effect without restart
  - **GREEN**: Implement:
    - Create `McpIntegration/McpServiceRegistrar.cs` — same pattern as T31 but for comms
    - Create `McpIntegration/McpConfigurationProvider.cs` — reads comms config keys from MCP
    - Create `McpIntegration/ConfigurationChangedHandler.cs` — handles config changes, including channel toggle
    - Create `McpIntegration/ChannelToggleHandler.cs` — specifically handles channel enable/disable by registering/deregistering channel adapters
    - Register in DI: `services.AddMcpIntegration(configuration)` in `Program.cs`
  - **REFACTOR**: Extract common MCP integration base into shared helper if patterns are identical to T31

  **Must NOT do**:
  - Do NOT make MCP a hard dependency — service MUST start without MCP
  - Do NOT store channel credentials in MCP config — credentials stay in OpenBao via `ISecretProvider`
  - Do NOT modify existing channel adapter code — only add config-driven enable/disable wrapper

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Integration pattern with config provider, hosted service, event handler, plus channel toggle logic
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No browser interaction — backend integration only

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with T15, T17, T18, T19, T21, T22, T23, T31)
  - **Blocks**: F1, F3
  - **Blocked By**: T4 (comms scaffold), T16 (webhook ingestion — needs channel adapters registered), T29 (MCP config events)

  **References**:

  **Pattern References** (existing code to follow):
  - `nem.Contracts/src/nem.Contracts/ControlPlane/IConfigurationManager.cs` — Contract for reading/writing config
  - `nem.Contracts/src/nem.Contracts.AspNetCore/Secrets/NemSecretsExtensions.cs` — Pattern for AddNemX(configuration) DI extension
  - `nem.MCP/services/nem.MCP.Api/Endpoints/ServiceRegistry/ServiceRegistryEndpoints.cs` — POST /api/v1/services API
  - `nem.Classification/src/Classification.Api/McpIntegration/` — T31's implementation (share or follow pattern)

  **API/Type References**:
  - `nem.MCP/services/nem.MCP.Core/Domain/Configuration/ConfigurationChangedEvent.cs` — Event to subscribe to (created in T29)

  **Acceptance Criteria**:
  - [x] Service registers with MCP on startup (verify via `GET /api/v1/services` showing "comms")
  - [x] Config values from MCP override appsettings defaults
  - [x] Service starts cleanly when MCP is unavailable
  - [x] Channel toggle change via MCP config takes effect without restart
  - [x] `dotnet test nem.Comms` → PASS

  **QA Scenarios**:
  ```
  Scenario: Service registers with MCP on startup
    Tool: Bash (curl)
    Preconditions: MCP running, nem.Comms starting, Keycloak running with test realm
    Steps:
      1. Acquire auth token: `TOKEN=$(curl -s -X POST http://localhost:8080/realms/nem/protocol/openid-connect/token -d 'grant_type=client_credentials&client_secret=test-secret&client_id=nem-test' | jq -r '.access_token')`
      2. Start nem.Comms service
      3. curl -H "Authorization: Bearer $TOKEN" GET http://localhost:5000/api/v1/services
      4. Parse JSON response, find entry with Id="comms"
      5. Assert Name="nem.Comms", HealthEndpoint="/health"
    Expected Result: comms service appears in registry within 10 seconds
    Failure Indicators: Service not in registry, wrong metadata, 401/403 on API
    Evidence: .sisyphus/evidence/nem-classification-comms/task-32-service-registered.txt

  Scenario: Channel toggle via MCP config
    Tool: Bash (curl)
    Preconditions: nem.Comms running with Telegram enabled, MCP running, Keycloak running
    Steps:
      1. Acquire auth token (same as above)
      2. curl -H "Authorization: Bearer $TOKEN" -X PUT http://localhost:5000/api/v1/config/comms/channels.telegram.enabled -H "Content-Type: application/json" -d '{"value": "false"}'
      2. Wait 5 seconds for config change event propagation
      3. curl POST http://localhost:5280/api/v1/webhook/telegram with a test payload
      4. Assert response is 503 Service Unavailable or 404 (channel disabled)
      5. curl PUT to re-enable: config/comms/channels.telegram.enabled = "true"
      6. Wait 5 seconds
      7. curl POST http://localhost:5280/api/v1/webhook/telegram — assert 200 OK
    Expected Result: Channel dynamically enabled/disabled via MCP config without restart
    Failure Indicators: Channel stays active after disable, restart required
    Evidence: .sisyphus/evidence/nem-classification-comms/task-32-channel-toggle.txt

  Scenario: Graceful degradation without MCP
    Tool: Bash (dotnet run)
    Preconditions: MCP is NOT running
    Steps:
      1. Start nem.Comms without MCP available
      2. Assert service starts successfully
      3. Assert all channels from appsettings are active
      4. curl GET http://localhost:5280/health — assert 200 OK
    Expected Result: Service starts with appsettings defaults, all configured channels active
    Failure Indicators: Startup crash, channels not loading, health check fails
    Evidence: .sisyphus/evidence/nem-classification-comms/task-32-graceful-fallback.txt
  ```

  **Commit**: YES
  - Message: `feat(comms): integrate MCP configuration with service registration, config pull, channel toggle, and change events`
  - Files: `nem.Comms/src/Comms.Api/McpIntegration/*, nem.Comms/src/Comms.Api/Program.cs`
  - Pre-commit: `dotnet test nem.Comms`

---

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [x] F1. **Plan Compliance Audit** — `oracle`

  **What to do**:
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, curl endpoint, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in `.sisyphus/evidence/nem-classification-comms/`. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

  **Recommended Agent Profile**:
  - **Category**: `oracle` (deep architecture/compliance review)

  **QA Scenarios**:

  ```
  Scenario: Verify all "Must Have" deliverables exist
    Tool: Bash (find, dotnet build, curl)
    Preconditions: All implementation tasks T1-T32 marked complete
    Steps:
      1. Read plan's "Must Have" section — extract each requirement
      2. For each "Must Have":
         - File deliverable: `find . -path "*<expected-path>"` → file exists
         - Endpoint: `curl -s -o /dev/null -w "%{http_code}" http://localhost:<port>/<path>` → 200/204
         - Build: `dotnet build --no-restore nem.Classification/` and `dotnet build --no-restore nem.Comms/` → exit 0
      3. Count: N verified / N total
    Expected Result: 100% of "Must Have" items verified (all N/N)
    Failure Indicators: Any file missing, endpoint unreachable, build failure
    Evidence: .sisyphus/evidence/nem-classification-comms/f1-must-have-audit.md

  Scenario: Verify no "Must NOT Have" violations
    Tool: Bash (grep -rn)
    Preconditions: Codebase in post-implementation state
    Steps:
      1. Read plan's "Must NOT Have" section — extract each forbidden pattern
      2. For "No Azure Cognitive Services": `grep -rn "Azure.AI\|CognitiveServices\|azure-cognitive" nem.Classification/ nem.Comms/` → 0 matches
      3. For "No bus message blocking": `grep -rn "Reject\|Dead.?Letter\|throw.*Classification" nem.Contracts/src/nem.Contracts.Wolverine/` → 0 matches
      4. For "No paid cloud dependencies": review all .csproj PackageReference entries for commercial-only NuGet packages
      5. Count: N clean / N total
    Expected Result: 0 violations found across all "Must NOT Have" rules
    Failure Indicators: Any grep returns matches, commercial NuGet package found
    Evidence: .sisyphus/evidence/nem-classification-comms/f1-must-not-have-audit.md

  Scenario: Verify task evidence files exist
    Tool: Bash (find, wc)
    Preconditions: All tasks complete
    Steps:
      1. `find .sisyphus/evidence/nem-classification-comms/ -type f | wc -l` → count
      2. For each task T1-T32, verify at least one evidence file exists: `ls .sisyphus/evidence/nem-classification-comms/task-{N}-*`
      3. Spot-check 5 evidence files for non-empty content: `wc -c <file>` → > 0
    Expected Result: ≥32 evidence files, all non-empty
    Failure Indicators: Missing evidence for any task, empty evidence files
    Evidence: .sisyphus/evidence/nem-classification-comms/f1-evidence-audit.md
  ```

- [x] F2. **Code Quality Review** — `unspecified-high`

  **What to do**:
  Run `dotnet build --warnaserror` + linter + `dotnet test`. Review all changed files for: `#pragma warning disable`, empty catches, `Console.Write` in prod, commented-out code, unused usings. Check AI slop: excessive comments, over-abstraction, generic names (data/result/item/temp).
  Output: `Build [PASS/FAIL] | Lint [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high` (code review with build/test verification)

  **QA Scenarios**:

  ```
  Scenario: Solution builds with warnings-as-errors
    Tool: Bash (dotnet build)
    Preconditions: All implementation complete
    Steps:
      1. `dotnet build --warnaserror nem.Classification/nem.Classification.sln 2>&1 | tee /tmp/f2-build-classification.txt` → exit 0
      2. `dotnet build --warnaserror nem.Comms/nem.Comms.sln 2>&1 | tee /tmp/f2-build-comms.txt` → exit 0
      3. `dotnet build --warnaserror nem.Contracts/nem.Contracts.slnx 2>&1 | tee /tmp/f2-build-contracts.txt` → exit 0
      4. `dotnet build --warnaserror nem.MCP/services/nem.MCP.Api/nem.MCP.Api.csproj 2>&1 | tee /tmp/f2-build-mcp.txt` → exit 0
      5. `cd nem.MCP/packages/web-app && npm run build 2>&1 | tee /tmp/f2-build-mcp-ui.txt` → exit 0
      6. Verify zero warnings in all outputs
    Expected Result: All 4 .NET solutions + Angular UI build cleanly with zero warnings
    Failure Indicators: Non-zero exit code, any CS#### warning, Angular build error
    Evidence: .sisyphus/evidence/nem-classification-comms/f2-build-results.txt

  Scenario: All tests pass across all solutions
    Tool: Bash (dotnet test)
    Preconditions: Solutions build successfully
    Steps:
      1. `dotnet test nem.Classification/ --logger "console;verbosity=detailed" 2>&1 | tee /tmp/f2-test-classification.txt` → all pass
      2. `dotnet test nem.Comms/ --logger "console;verbosity=detailed" 2>&1 | tee /tmp/f2-test-comms.txt` → all pass
      3. `dotnet test nem.Contracts/ --logger "console;verbosity=detailed" 2>&1 | tee /tmp/f2-test-contracts.txt` → all pass
      4. `dotnet test nem.MCP/ --logger "console;verbosity=detailed" 2>&1 | tee /tmp/f2-test-mcp.txt` → all pass
      5. `cd nem.MCP/packages/web-app && npm test -- --watch=false 2>&1 | tee /tmp/f2-test-mcp-ui.txt` → all pass
      6. Count total: tests passed, tests failed, tests skipped
    Expected Result: 0 failures, 0 skipped across all test suites (including MCP backend + Angular)
    Failure Indicators: Any test failure, skipped tests without documented reason
    Evidence: .sisyphus/evidence/nem-classification-comms/f2-test-results.txt

  Scenario: No AI slop patterns in new code
    Tool: Bash (grep -rn)
    Preconditions: Know which files were added/modified (git diff --name-only)
    Steps:
      1. `git diff --name-only main...HEAD` → list of changed files
      2. For each changed .cs file:
         - `grep -n "#pragma warning disable" <file>` → 0 matches (or justified)
         - `grep -n "catch.*{.*}" <file>` → verify no empty catch blocks
         - `grep -n "Console\.Write" <file>` → 0 matches in non-test files
         - `grep -n "// TODO\|// HACK\|// FIXME" <file>` → 0 matches
      3. Spot-check 10 files for: excessive comments (>30% comment lines), over-abstraction (interfaces with single implementation not in contracts), generic variable names
    Expected Result: Zero slop patterns, clean professional code
    Failure Indicators: Empty catches, Console.Write in production code, excessive TODOs
    Evidence: .sisyphus/evidence/nem-classification-comms/f2-code-quality.md
  ```

- [x] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill if UI)

  **What to do**:
  Start from clean `docker compose up`. Execute EVERY QA scenario from EVERY task — follow exact steps, capture evidence. Test cross-task integration (classification enrichment + channel message flow). Test edge cases: unclassified data, PII in message, Confidential doc → LLM request blocked. Save to `.sisyphus/evidence/nem-classification-comms/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: [`playwright`] (if any task has browser-based QA)

  **QA Scenarios**:

  ```
  Scenario: Full stack boots from clean state
    Tool: Bash (docker compose)
    Preconditions: No containers running, images built
    Steps:
      1. `docker compose -f docker-compose.classification.yml down -v` → clean slate
      2. `docker compose -f docker-compose.classification.yml up -d --build 2>&1 | tee /tmp/f3-compose-up.txt`
      3. Wait 30s for services to initialize
      4. `docker compose -f docker-compose.classification.yml ps --format json | jq -r '.[] | "\(.Name) \(.State)"'` → all 12 services "running"
      5. Health checks (all 12 services):
         - `curl -sf http://localhost:5270/health` → 200 (nem.Classification)
         - `curl -sf http://localhost:5280/health` → 200 (nem.Comms)
         - `curl -sf http://localhost:5001/health` → 200 (Presidio)
         - `curl -sf http://localhost:8200/v1/sys/health` → 200 (OpenBao)
         - `curl -sf http://localhost:8181/health` → 200 (OPA)
         - `curl -sf http://localhost:5000/health` → 200 (nem.MCP API)
         - `curl -sf http://localhost:4200/` → 200 (nem.MCP Angular UI)
         - `curl -sf http://localhost:5223/health` → 200 (nem.Mimir)
         - `curl -sf http://localhost:5100/health` → 200 (nem.KnowHub)
         - `docker compose -f docker-compose.classification.yml exec postgres pg_isready` → "accepting connections" (PostgreSQL)
         - `curl -sf http://localhost:15672/api/healthchecks/node -u guest:guest` → 200 (RabbitMQ)
         - `curl -sf http://localhost:8080/health/ready` → 200 (Keycloak)
    Expected Result: All 12 services running, all health endpoints return 200
    Failure Indicators: Any service not running, health check failure, container restart loop
    Evidence: .sisyphus/evidence/nem-classification-comms/final-qa/f3-stack-boot.txt

  Scenario: Cross-task integration — classify document then gate LLM request
    Tool: Bash (curl)
    Preconditions: Full stack running, test document exists
    Steps:
      1. Acquire auth token: `TOKEN=$(curl -s -X POST http://localhost:8080/realms/nem/protocol/openid-connect/token -d 'grant_type=client_credentials&client_id=nem-test&client_secret=test-secret' | jq -r '.access_token')`
      2. Classify a document as Confidential:
         `curl -s -X POST http://localhost:5270/api/v1/classify -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{"text":"Internal revenue report Q4 2025 - executive summary with projections","entityType":"Document","entityId":"doc-001"}' | jq .`
         → 200, response has `"level":"Confidential"` or higher
      3. Verify stored classification:
         `curl -s -H "Authorization: Bearer $TOKEN" http://localhost:5270/api/v1/classification/Document/doc-001 | jq .`
         → 200, returns ClassificationResult with level
       4. Attempt LLM request referencing the Confidential document — this tests the ClassificationGatingHandler on HttpClientFactory:
          `curl -s -w "\n%{http_code}" -X POST http://localhost:5223/api/v1/conversations -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{"title":"Test gating","messages":[{"role":"user","content":"Summarize document doc-001"}],"documentReferences":["doc-001"]}' | tee /tmp/f3-gating-blocked.txt`
          → HTTP 403 or response body contains `"blocked":true` / `"error":"classification_gated"` (Confidential data cannot flow to external LLM via ClassificationGatingHandler in Mimir)
      5. Classify a different document as Public:
         `curl -s -X POST http://localhost:5270/api/v1/classify -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{"text":"Public knowledge base FAQ about general product features","entityType":"Document","entityId":"doc-002"}' | jq .`
         → 200, response has `"level":"Public"`
      6. Attempt LLM request with Public document → ALLOWED
    Expected Result: Confidential blocked, Public allowed — gating works end-to-end
    Failure Indicators: Confidential data reaches LLM, Public data blocked
    Evidence: .sisyphus/evidence/nem-classification-comms/final-qa/f3-classify-gate-e2e.txt

  Scenario: Cross-task integration — PII detection in communication message
    Tool: Bash (curl)
    Preconditions: Full stack running, Presidio reachable
    Steps:
      1. Acquire auth token: `TOKEN=$(curl -s -X POST http://localhost:8080/realms/nem/protocol/openid-connect/token -d 'grant_type=client_credentials&client_id=nem-test&client_secret=test-secret' | jq -r '.access_token')`
      2. Send message containing PII through nem.Comms inbound webhook:
         `curl -s -X POST http://localhost:5280/api/v1/webhook/telegram -H "Content-Type: application/json" -d '{"messageId":"msg-001","chatId":"chat-001","text":"Contact John Smith at john.smith@example.com or 555-0123","from":"user-001"}' | jq .`
         → 200/202
      3. Wait 2s for async classification enrichment via Wolverine bus
      4. Query classification for the message:
         `curl -s -H "Authorization: Bearer $TOKEN" http://localhost:5270/api/v1/classification/Message/msg-001 | jq .`
         → 200, hasPii = true, piiEntities includes EMAIL_ADDRESS, PHONE_NUMBER, PERSON
      5. Verify PII detection audit log: `docker logs nem-classification-api 2>&1 | grep "PII detected" | tail -5`
    Expected Result: PII automatically detected, classification enriched with PII flag
    Failure Indicators: PII not detected, hasPii=false for message with obvious PII, 404 on classification lookup (enrichment didn't run)
    Evidence: .sisyphus/evidence/nem-classification-comms/final-qa/f3-pii-detection.txt

  Scenario: Edge case — unclassified entity is fail-closed at gating layer
    Tool: Bash (curl + opa eval)
    Preconditions: Full stack running
    Steps:
      1. Acquire auth token: `TOKEN=$(curl -s -X POST http://localhost:8080/realms/nem/protocol/openid-connect/token -d 'grant_type=client_credentials&client_id=nem-test&client_secret=test-secret' | jq -r '.access_token')`
      2. Query classification for entity that was never classified:
         `curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" http://localhost:5270/api/v1/classification/Document/nonexistent-doc`
         → 404 Not Found (no classification stored for this entity)
      3. Verify LLM gating treats unclassified entities as blocked (fail-closed):
         OPA policy with missing/null classification_level defaults to deny:
         `opa eval -d nem.MCP/policies/ -i <(echo '{"classification_level":null,"has_pii":false,"destination_type":"external","tenant_id":"t1"}') "data.nem.mcp.controlplane.llm_gating.allow"`
         → result is `false` (fail-closed: no classification = no external access)
    Expected Result: Unclassified entities get 404 from API, and LLM gating blocks access (fail-closed default via OPA policy `default allow := false`)
    Failure Indicators: 200 returned for non-existent entity, or OPA allows null/unclassified data to reach external LLM
    Evidence: .sisyphus/evidence/nem-classification-comms/final-qa/f3-default-classification.txt

  Scenario: MCP Configuration Integration — service configs manageable through nem.MCP
    Tool: Bash (curl) + Playwright
    Preconditions: nem.MCP, nem.Classification, nem.Comms running via docker compose, Keycloak running with test realm
    Steps:
      1. Acquire auth token: `TOKEN=$(curl -s -X POST http://localhost:8080/realms/nem/protocol/openid-connect/token -d 'grant_type=client_credentials&client_id=nem-test&client_secret=test-secret' | jq -r '.access_token')`
       2. Register nem.Classification service: `curl -H "Authorization: Bearer $TOKEN" -X POST http://localhost:5000/api/v1/services -H 'Content-Type: application/json' -d '{"id":"classification","name":"nem.Classification","url":"http://nem-classification:5270","version":"1.0.0","tags":["classification"],"healthEndpoint":"/health"}'` → 200
       3. Set a config key: `curl -H "Authorization: Bearer $TOKEN" -X PUT http://localhost:5000/api/v1/config/classification/DefaultLevel -H 'Content-Type: application/json' -d '{"value":"Confidential"}'` → 200
       4. Read config key: `curl -H "Authorization: Bearer $TOKEN" http://localhost:5000/api/v1/config/classification/DefaultLevel` → `{"value":"Confidential"}`
      5. Verify nem.Classification pulls updated config on next request (restart or config-change event)
      6. Open MCP Angular UI → navigate to "Service Configuration" page → verify nem.Classification and nem.Comms listed
      7. Edit a config value through UI → verify change persisted via API GET
    Expected Result: Config round-trips through MCP API and Angular UI, services consume updated config
    Failure Indicators: 404 on config endpoints, service doesn't reflect updated config, Angular page missing or broken
    Evidence: .sisyphus/evidence/nem-classification-comms/final-qa/f3-mcp-config-integration.txt
  ```

- [x] F4. **Scope Fidelity Check** — `deep`

  **What to do**:
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

  **Recommended Agent Profile**:
  - **Category**: `deep` (thorough diff analysis)

  **QA Scenarios**:

  ```
  Scenario: Every task's deliverables match spec 1:1
    Tool: Bash (git diff, find)
    Preconditions: All tasks complete, git history available
    Steps:
      1. For each task T1-T32:
         - Read task's "What to do" section from plan
         - Identify committed files from task's "Commit → Files" section
         - `git log --oneline --all | grep "<task-commit-message>"` → commit exists
         - `git show <commit-hash> --stat` → files changed match plan's file list
         - Verify no EXTRA files beyond spec (scope creep)
         - Verify no MISSING files from spec (incomplete)
      2. Tally: N compliant / 32 total
    Expected Result: 32/32 tasks compliant — every file in spec exists, no extras
    Failure Indicators: Missing deliverable files, unexpected files in commit
    Evidence: .sisyphus/evidence/nem-classification-comms/f4-task-compliance.md

  Scenario: No cross-task contamination
    Tool: Bash (git log)
    Preconditions: Git history with per-task commits
    Steps:
      1. For each task commit, list changed files: `git show <hash> --name-only`
      2. Cross-reference: does any file belong to a DIFFERENT task's responsibility?
         - e.g., T5 commit changes a file that belongs to T8's scope
      3. Flag any file changed by multiple task commits (indicates contamination)
      4. `git diff --name-only main...HEAD | sort > /tmp/all-changed.txt`
      5. Compare all-changed.txt against union of all task file lists → identify unaccounted files
    Expected Result: Zero cross-task contamination, zero unaccounted files
    Failure Indicators: File owned by task X modified in task Y's commit, orphan files
    Evidence: .sisyphus/evidence/nem-classification-comms/f4-contamination-check.md

  Scenario: "Must NOT do" compliance per task
    Tool: Bash (grep -rn)
    Preconditions: Implementation complete
    Steps:
      1. For each task, read its "Must NOT do" section
      2. Verify each prohibition:
         - T2: no EF Core in contracts → `grep -rn "EntityFrameworkCore" nem.Contracts/` → 0
         - T10: no bus message blocking → `grep -rn "throw\|Reject\|DeadLetter" nem.Contracts/src/nem.Contracts.Wolverine/Classification/DataClassificationBehavior.cs` → 0
         - T14: no embedding model changes → verify only DI registration changed in ServiceCollectionExtensions.cs
      3. Spot-check 5 additional tasks' "Must NOT do" rules
    Expected Result: 100% compliance with all "Must NOT do" rules
    Failure Indicators: Any grep returns forbidden patterns in task scope
    Evidence: .sisyphus/evidence/nem-classification-comms/f4-must-not-do-compliance.md
  ```

---

## Commit Strategy

| Task | Commit Message | Files | Pre-commit |
|------|---------------|-------|------------|
| T1 | `feat(contracts): add classification types and channel event contract to nem.Contracts` | `nem.Contracts/src/nem.Contracts/Classification/*, nem.Contracts/src/nem.Contracts/Events/Integration/ChannelEventReceivedIntegrationEvent.cs` | `dotnet build nem.Contracts` |
| T2 | `feat(classification): scaffold nem.Classification service` | `nem.Classification/**` | `dotnet build nem.Classification` |
| T3 | `feat(classification): add Presidio PII detection sidecar` | `nem.Classification/sidecar/presidio/**` | `docker compose build presidio` |
| T4 | `feat(comms): scaffold nem.Comms service` | `nem.Comms/**` | `dotnet build nem.Comms` |
| T5 | `feat(policy): add OPA classification and LLM gating policies` | `nem.MCP/policies/classification.rego, nem.MCP/policies/llm_gating.rego` | `opa check nem.MCP/policies/` |
| T6 | `feat(comms): add domain model and persistence` | `nem.Comms/src/Comms.Domain/**, Comms.Infrastructure/**` | `dotnet build nem.Comms` |
| T7 | `feat(classification): implement classification engine with Presidio` | `nem.Classification/src/**` | `dotnet test Classification.Tests` |
| T8 | `feat(classification): add classification REST API` | `nem.Classification/src/Classification.Api/**` | `dotnet test Classification.Tests` |
| T9 | `feat(contracts): add DataClassificationMiddleware for HTTP` | `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/**` | `dotnet test Contracts.Tests` |
| T10 | `feat(contracts): add DataClassificationBehavior for Wolverine` | `nem.Contracts/src/nem.Contracts.Wolverine/Classification/**` | `dotnet test Contracts.Tests` |
| T11 | `feat(contracts): add ClassificationGatingHandler for HttpClient` | `nem.Contracts/src/nem.Contracts.AspNetCore/Classification/**` | `dotnet test Contracts.Tests` |
| T12 | `feat(classification): add classification audit trail` | `nem.Classification/src/Classification.Infrastructure/Audit/**` | `dotnet test Classification.Tests` |
| T13 | `feat(mimir): add classification gating to LiteLlmClient` | `nem.Mimir-typed-ids/src/Mimir.Infrastructure/LiteLlm/**` | `dotnet build Mimir.Infrastructure` |
| T14 | `feat(knowhub): add classification gating to EmbeddingService` | `nem.KnowHub/services/KnowHub.Embedding/**` | `dotnet build KnowHub.Embedding` |
| T15 | `feat(classification): add migration CLI and audit-only mode` | `nem.Classification/src/Classification.Cli/**` | `dotnet build Classification.Cli` |
| T16 | `feat(comms): implement Channel Edge webhook ingestion` | `nem.Comms/src/Comms.Api/Endpoints/WebhookEndpoints.cs, nem.Comms/src/Comms.Application/Webhooks/*` | `dotnet test Comms.Tests` |
| T17 | `feat(comms): add WebWidget channel adapter` | `nem.Comms/src/Comms.Infrastructure/Channels/WebWidget/*` | `dotnet test Comms.Tests` |
| T18 | `feat(comms): add Teams channel adapter` | `nem.Comms/src/Comms.Infrastructure/Channels/Teams/*` | `dotnet test Comms.Tests` |
| T19 | `feat(comms): implement federation routing and operator assignment` | `nem.Comms/src/Comms.Application/Routing/*, nem.Comms/src/Comms.Domain/Events/*, nem.Mimir-typed-ids/src/Mimir.Application/ChannelEvents/ChannelEventReceivedConsumer.cs` | `dotnet test Comms.Tests && dotnet test nem.Mimir-typed-ids/tests/Mimir.Application.Tests/` |
| T20 | `feat(comms): add delivery retries and DLQ` | `nem.Comms/src/Comms.Application/Delivery/*, nem.Comms/src/Comms.Api/Endpoints/DlqEndpoints.cs` | `dotnet test Comms.Tests` |
| T21 | `feat(comms): add Telegram channel adapter` | `nem.Comms/src/Comms.Infrastructure/Channels/Telegram/*` | `dotnet test Comms.Tests` |
| T22 | `feat(comms): add WhatsApp channel adapter` | `nem.Comms/src/Comms.Infrastructure/Channels/WhatsApp/*` | `dotnet test Comms.Tests` |
| T23 | `feat(comms): add Signal channel adapter` | `nem.Comms/src/Comms.Infrastructure/Channels/Signal/*` | `dotnet test Comms.Tests` |
| T24 | `feat(comms): add tenant-scoped identity links` | `nem.Comms/src/Comms.Application/Identity/*, nem.Comms/src/Comms.Infrastructure/Persistence/IdentityLinkRepository.cs, nem.Comms/src/Comms.Api/Endpoints/IdentityEndpoints.cs` | `dotnet test Comms.Tests` |
| T25 | `feat(comms): add unified inbox Operator API` | `nem.Comms/src/Comms.Api/Endpoints/OperatorInboxEndpoints.cs, nem.Comms/src/Comms.Application/Operator/*, nem.Comms/src/Comms.Infrastructure/Persistence/SessionReadModelRepository.cs, nem.Contracts/src/nem.Contracts/Events/Integration/MessageCreatedEvent.cs, nem.Mimir-typed-ids/src/Mimir.Application/Conversations/Commands/SendMessage.cs` | `dotnet test Comms.Tests && dotnet test nem.Mimir-typed-ids/tests/Mimir.Application.Tests/` |
| T26 | `feat(comms): integrate classification middleware` | `nem.Comms/src/Comms.Api/Program.cs, nem.Comms/src/Comms.Application/Classification/*, nem.Comms/src/Comms.Api/appsettings.json` | `dotnet test Comms.Tests` |
| T27 | `feat(infra): add full-stack docker-compose` | `docker-compose.classification.yml` | `docker compose config` |
| T28 | `test(e2e): add end-to-end integration tests` | `nem.Comms/tests/Comms.IntegrationTests/**` | `dotnet test nem.Comms/tests/Comms.IntegrationTests` |
| T29 | `feat(mcp): extend config backend for Classification and Comms services` | `nem.MCP/services/nem.MCP.Core/Domain/McpConfig/McpTargetService.cs, nem.MCP/services/nem.MCP.Api/Endpoints/Configuration/*` | `dotnet test nem.MCP` |
| T30 | `feat(mcp-ui): add Service Configuration management page` | `nem.MCP/packages/web-app/src/app/domain/service-config/**` | `ng build` |
| T31 | `feat(classification): wire MCP configuration integration` | `nem.Classification/src/Classification.Api/McpIntegration/*` | `dotnet test Classification.Tests` |
| T32 | `feat(comms): wire MCP configuration integration` | `nem.Comms/src/Comms.Api/McpIntegration/*` | `dotnet test Comms.Tests` |

---

## Success Criteria

### Verification Commands
```bash
# Classification service builds and tests pass
dotnet build nem.Classification/nem.Classification.sln  # Expected: 0 warnings, 0 errors
dotnet test nem.Classification/  # Expected: all tests pass

# Comms service builds and tests pass
dotnet build nem.Comms/nem.Comms.sln  # Expected: 0 warnings, 0 errors
dotnet test nem.Comms/  # Expected: all tests pass

# Docker stack runs
docker compose -f docker-compose.classification.yml up -d  # Expected: all services healthy
curl http://localhost:5270/health  # Expected: 200 OK (nem.Classification)
curl http://localhost:5280/health  # Expected: 200 OK (nem.Comms)
curl http://localhost:5001/health  # Expected: 200 OK (Presidio)

# Classification gating works
curl -X POST http://localhost:5270/api/v1/classify -d '{"text":"My email is john@example.com","entityType":"Document","entityId":"doc-1"}' 
# Expected: {"level":"Confidential","hasPii":true,"piiEntities":["EMAIL_ADDRESS"]}

# LLM gating works
# Confidential doc → LLM: Expected: 403 ClassificationGatingDenied
# Public doc → LLM: Expected: 200 OK with response

# MCP configuration integration works (requires FederationAdmin token)
# TOKEN=$(curl -s -X POST http://localhost:8080/realms/nem/protocol/openid-connect/token -d 'grant_type=client_credentials&client_id=nem-test&client_secret=test-secret' | jq -r '.access_token')
curl -H "Authorization: Bearer $TOKEN" http://localhost:5000/api/v1/config/classification/DefaultLevel  # Expected: 200 with value
curl -H "Authorization: Bearer $TOKEN" http://localhost:5000/api/v1/config/comms/DefaultChannel  # Expected: 200 with value
curl -H "Authorization: Bearer $TOKEN" http://localhost:5000/api/v1/services  # Expected: nem.Classification + nem.Comms registered
```

### Final Checklist
- [x] All "Must Have" items present and verified
- [x] All "Must NOT Have" items absent (search codebase for forbidden patterns)
- [x] All tests pass (`dotnet test`)
- [x] Classification gating blocks Confidential+ from external LLMs
- [x] PII detection identifies 5 core entity types
- [x] Audit-only mode works (logs but doesn't block)
- [x] Channel message routing works (inbound webhook → nem.Comms → Wolverine → Mimir)
- [x] Docker stack runs with all services healthy
- [x] MCP config API serves Classification & Comms config keys
- [x] MCP Angular UI has "Service Configuration" page listing both services
- [x] Both services pull config from MCP on startup (graceful degradation if MCP unavailable)
- [x] Corporate freeware only (no paid dependencies)
