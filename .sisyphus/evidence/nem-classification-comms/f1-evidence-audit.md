# F1 Evidence Audit Summary

## Verdict Basis
- Must Have: 11/13 confirmed
- Must NOT Have: 9/11 clean
- Final verdict: REJECT

## Key verification notes
1. **Checklist path drift exists.**
   - MCP policy files are under `nem.MCP/policies/`, not `/server/nem.MCP/Policies/`.
   - The relevant `OpenAiEmbeddingService.cs` is in `nem.KnowHub/services/KnowHub.Embedding/Services/`, not `nem.Mimir-typed-ids`.

2. **LLM egress gating is implemented mostly through wiring, not inside the named client classes.**
   - LiteLLM is gated via `LiteLlmClassificationInterceptor` + `ClassificationGatingHandler` attached in `nem.Mimir-typed-ids/src/Mimir.Api/Program.cs`.
   - OpenAI-compatible embeddings are gated via `EmbeddingClassificationInterceptor` + `ClassificationGatingHandler` attached in `nem.KnowHub/services/KnowHub.Embedding/ServiceCollectionExtensions.cs`.
   - This was strong enough to confirm functional blocking (MH4), but not strong enough to satisfy the checklist’s file-local wording for MH10.

3. **Classification API is generic by entity type.**
   - `ClassifyRequest` carries `EntityType`/`EntityId` and persistence is keyed by those fields.
   - Explicit test evidence was found for `Document`; `Conversation` and `KnowledgeArticle` were not explicitly found in inspected tests.

## Failed items
- **MH8** — No human override endpoint/handler or raise-only validation found.
- **MH10** — Named egress client files do not themselves contain gating logic; gating is applied externally in DI/startup wiring, and the expected `OpenAiEmbeddingService.cs` is not in Mimir.
- **MNH2** — `nem.Comms` owns `ChannelSession` persistence and operator inbox/claim/respond flows, exceeding pure routing/federation.
- **MNH5** — `WebhookNormalizer` introduces a message normalization/transformation stage.

## Supporting evidence locations
- Must Have detail: `.sisyphus/evidence/nem-classification-comms/f1-must-have-audit.md`
- Must NOT Have detail: `.sisyphus/evidence/nem-classification-comms/f1-must-not-have-audit.md`
