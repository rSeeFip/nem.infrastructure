# F1 Must NOT Have Audit

## Result
Clean: 9/11

## Checklist

### MNH1 — PASS
No Angular/React/UI/dashboard footprint was found in `nem.Classification` or `nem.Comms`. Grep for UI/component markers returned no matches.

### MNH2 — FAIL
`nem.Comms` owns session/conversation-like state and operator workflow beyond pure routing/federation:
- `nem.Comms/src/Comms.Domain/Entities/ChannelSession.cs` defines persisted channel sessions
- `nem.Comms/src/Comms.Domain/Repositories/IChannelSessionRepository.cs` persists them
- `nem.Comms/src/Comms.Application/Routing/ChannelRouter.cs:26-59` creates/updates sessions and assigns/queues operators
- `nem.Comms/src/Comms.Api/Endpoints/OperatorInboxEndpoints.cs` exposes inbox/session claim/respond endpoints.
This exceeds a route-only/federate-only boundary.

### MNH3 — PASS
`nem.Classification/src/Classification.Infrastructure/Presidio/PresidioClient.cs:8-20` limits PII detection to the 5 core entity types only.

### MNH4 — PASS
No channel capability runtime negotiation was found. Grep for `capability negotiation`, `runtime negotiation`, `negotiat`, and `capabilit` returned no relevant matches in `nem.Comms/src`.

### MNH5 — FAIL
A normalization/transformation stage exists before routing:
- `nem.Comms/src/Comms.Application/Webhooks/WebhookNormalizer.cs:10-62` transforms raw webhook payloads into normalized `ChannelEventReceivedIntegrationEvent` objects.
Even though adapter send paths preserve `message.Content`, this still introduces a message transformation pipeline.

### MNH6 — PASS
The inspected classification-related `nem.Contracts` changes were additive:
- git commit `1b24bb3` created new classification files/types only
- git commit `53ae848` created new AspNetCore/Wolverine classification files/projects/tests only.
No existing contracts interface modification was evidenced in those inspected commits.

### MNH7 — PASS
No evidence of extracting/moving adapters out of Mimir was found. `nem.Mimir-typed-ids` still contains channel projects such as `Mimir.Teams` and `Mimir.Telegram`, while `nem.Comms` contains separate adapter implementations.

### MNH8 — PASS
`nem.Contracts/src/nem.Contracts.Wolverine/Classification/DataClassificationBehavior.cs:28-52` enriches classification context and logs only; it always continues with `await next()` and does not block/reject bus messages.

### MNH9 — PASS
No explicit paid/commercial dependency package references were found in `nem.Classification` or `nem.Comms` project files during csproj inspection; the implementation relies on Presidio/OPA and direct HTTP adapters rather than clearly paid SaaS SDK additions.

### MNH10 — PASS
PII detection is not over-engineered:
- `nem.Classification/src/Classification.Infrastructure/Presidio/PresidioOptions.cs:9` sets `ConfidenceThreshold = 0.7d`
- `nem.Classification/src/Classification.Infrastructure/Presidio/PresidioClient.cs:8-20` uses only 5 supported entities.

### MNH11 — PASS
No approval workflow/approval chain for human override was found. Grep for `approval|workflow|approve` in `nem.Classification/src` returned no relevant implementation.
