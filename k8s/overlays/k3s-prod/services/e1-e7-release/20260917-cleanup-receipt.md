# 2026-09-17 bounded cleanup receipt

## Scope and publication baseline

This receipt records an explicitly authorized, exact-name cleanup after the E1-E7 release. No broad prune, volume/PVC, database, source-of-unknown-provenance, or force operation was used.

- Published WMReflect master: `437d5d04114e882772375f30e025e7650ba8ddeb`
- Published MCP master and deployed source: `9be6943470503806f7e90d823813e97a7ee20f7e`
- Infrastructure release baseline: `a0fdcf46aca062d4fc5988293f0351ce0698fedf`
- This receipt was created on the fast-forwarded infrastructure main baseline `9274710f4d63c0f8ec35450ba016a64342455173`.

## Exact removals

| Target | Proof before removal | Removed size |
| --- | --- | ---: |
| Pods `nem-mcp-startup-9be694347050`, `nem-agenticgateway-startup-bb90360f`, `nem-agenticgateway-startup-bb90360f-2`, and `nem-mcp-9be694347050-candidate` | All were terminal, had no owner references, had no `preStop` lifecycle, and were not Service endpoints. Their only mounts were projected service-account tokens and ConfigMaps. | Pod objects only |
| `localhost/nem.mcp:2f9756256ce4650b6d9134f70f014816c600f902-lock-713f09f72593` | No Pod, Deployment, ReplicaSet, Job, CronJob, or runtime container referenced it. It was an undeployed candidate; containerd listed 93.2 MiB logical size. | 93.2 MiB logical tag |
| `/tmp/nem-mcp-hotfix-2f9756256ce4-20260917` | Never-deployed candidate context; exact pre-delete size was `115979844` bytes. Its OCI archive hash was recorded before removal. | `115979844` bytes |
| `/workspace/.release-worktrees/nem.MCP-release-2f97562` | Clean detached worktree at `2f9756256ce4650b6d9134f70f014816c600f902`, proven reachable from published MCP master. | `3450329` bytes |

The candidate OCI archive SHA-256 recorded before removal was `d80f5f123ab9d7339eaeb4fcf8c80cccbeba634472a8ba70927d942bbe8a2fc5`; its containerd manifest digest was `sha256:be3f9f416eb01e4af27f2c4637087bcb4a43113a524e5090e7bd811bf8cfbede`.

## Retained evidence and rollback boundaries

- Current MCP archive retained at `/tmp/nem-mcp-9be694347050-20260917/nem.mcp-9be694347050-lock-2e18da38d426.oci.tar`; SHA-256: `1f3f3408f594628677b1e14345f1c400765de6369f487df8ec0664aa83849553`.
- Sanitized terminal-pod logs and pre/post-delete proofs retained under `/tmp/nem-mcp-9be694347050-20260917/cleanup-evidence-20260917`.
- Current Gateway `bb90360f2760af08bd6646e5ca770ee8e590835e-lock-c68e13bf2928`, last healthy Gateway rollback `ee47210dbfda`, MCP rollback `8e5e3d1905f6`, dependency closure images, and the preserved external Mimir `3338708c8136` and Inference `e5fd832-lock-e45a13542778` images were not removed.
- No persistent volume, PVC, database, Docker volume, unknown `/tmp/opencode` content, dirty worktree, active branch, ERP, or HolisticWorld artifact was removed. The earlier Docker-volume incident remains unresolved; its evidence was preserved and no recovery or impact claim is made.

## Post-cleanup service proof

The Gateway and MCP endpoints remained exclusively on managed serving pods after cleanup. All ten scoped E1-E7 deployments reported `desired=1`, `ready=1`, and `available=1`: AgenticGateway, MCP, Comms, Configuration, InferenceGateway, Mimir, Scheduler, Sentinel, Workflow, and Workflow Approval Signer.
