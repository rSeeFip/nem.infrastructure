# nem.infrastructure Security Configuration Stack

## Overview
The nem.infrastructure project provides a unified, composable security and observability stack for the nem.* microservice ecosystem. This document outlines the operational configuration for the core security components:

- **Keycloak**: Handles Authentication (AuthN), Identity Management, and OIDC/JWT issuance.
- **OPA (Open Policy Agent)**: Handles Authorization (AuthZ) through fine-grained Rego policy evaluation.
- **OpenBao**: Provides secure Secrets Management and sensitive data handling (Transit, KV).

### Environment Separation
- **Dev**: Relaxed security, auto-unsealed Vault, local database credentials, no HTTPS requirement.
- **Test**: Production-like configuration with brute-force protection, shortened token lifetimes, and strict OPA enforcement.
- **Prod**: Hardened, HA-ready configuration (OpenBao in non-dev mode), mandatory TLS, and encrypted communication.

## Directory Structure
```
nem.infrastructure/
├── config/
│   ├── dev/
│   │   ├── .env.dev
│   │   └── nem-realm-dev.json
│   ├── test/
│   │   ├── .env.test
│   │   └── nem-realm-test.json
│   ├── prod/
│   │   ├── .env.prod.template
│   │   └── nem-realm-prod.template.json
│   └── shared/
│       ├── keycloak-roles.json
│       ├── clearance-levels.json
│       ├── segments.json
│       └── llm-providers.json
├── opa/
│   └── bundles/nem/
│       ├── .manifest
│       ├── data/
│       │   ├── dev.json
│       │   ├── test.json
│       │   └── prod.json
│       ├── federation/
│       │   ├── common/
│       │   ├── services/
│       │   └── tests/
│       └── mcp/
│           └── controlplane/
├── openbao/
│   ├── policies/*.hcl
│   ├── init-dev.sh
│   ├── init-test.sh
│   └── init-prod.sh.template
├── docker-compose.yml
├── docker-compose.dev.yml
├── docker-compose.test.yml
└── docker-compose.prod.yml.template
```

## Quick Start (Dev)

Follow these steps to spin up the infrastructure in a development environment:

```bash
# 1. Start infrastructure
cd nem.infrastructure
docker compose -f docker-compose.yml -f docker-compose.dev.yml --env-file config/dev/.env.dev up -d

# 2. Wait for services to be healthy (30-60s)
docker compose ps

# 3. Initialize OpenBao secrets
bash openbao/init-dev.sh

# 4. Verify
# Keycloak admin UI: http://localhost:8080 (admin / admin)
# OPA health: curl http://localhost:8181/health
# OpenBao: curl http://localhost:8200/v1/sys/health
```

## Environment Comparison Table

| Setting | Dev | Test | Prod |
| :--- | :--- | :--- | :--- |
| SSL Required | none | external | all |
| Brute Force Protection | false | true | true |
| Access Token Lifetime | 30 min | 5 min | 15 min |
| OPA Clearance Enforcement | false | true | true |
| OPA Segment Enforcement | false | true | true |
| PII Strict Mode | false | true | true |
| OpenBao Token | root (dev) | test-root-token | External (no default) |
| Audit Logging | false | true | true |
| Rate Limit | 1000/min | 100/min | 60/min |

## Dev Seed Users Table

The following users are provisioned in the `nem` realm for development and testing:

| Username | Password | Roles | Clearance Level | Segments |
| :--- | :--- | :--- | :--- | :--- |
| fed-admin | dev-password | FederationAdmin, admin | 4 (Secret) | seg-default |
| admin-user | dev-password | admin | 3 (Restricted) | seg-default |
| workflow-viewer | dev-password | WorkflowViewer, user | 1 (Internal) | seg-default |
| workflow-executor | dev-password | WorkflowExecutor, user | 1 (Internal) | seg-default |
| workflow-designer | dev-password | WorkflowDesigner, user | 2 (Confidential) | seg-default |
| workflow-approver | dev-password | WorkflowApprover, user | 2 (Confidential) | seg-default |
| workflow-admin | dev-password | WorkflowAdmin, admin | 3 (Restricted) | seg-default |
| skill-publisher | dev-password | SkillPublisher, SkillExecutor, user | 1 (Internal) | seg-default |
| skill-reviewer | dev-password | SkillReviewer, SkillExecutor, user | 2 (Confidential) | seg-default |
| platform-admin | dev-password | PlatformAdmin, admin | 3 (Restricted) | seg-default |
| basic-user | dev-password | user | 0 (Public) | seg-default |
| restricted-user | dev-password | user | 0 (Public) | none (no segment) |
| nem-developer | dev-password | nem:developer, user, SkillExecutor | 1 (Internal) | seg-default |

## LLM Provider Tiers Table

LLM gating is enforced by `nem.mcp.controlplane.llm_gating` Rego policy based on classification level and PII mode.

| Tier | Provider | Max Classification | Models | URL |
| :--- | :--- | :--- | :--- | :--- |
| local | LMStudio | Secret (4) | qwen3.5-9b | http://192.168.1.85:1234/v1 |
| mid | LiteLLM | Confidential (2) | qwen3.5-27b, qwen3.5-0.8b-mlx | http://192.168.8.75:4000/v1 |
| premium | GitHubCopilot | Internal (1) | gpt-4o, claude-sonnet | external |

## Config Promotion Checklist

Guidelines for promoting configurations across environments:

### Dev → Test
- [ ] Copy env vars from `.env.dev` to `.env.test`, update passwords.
- [ ] Verify Keycloak test realm has correct test users.
- [ ] Set `KEYCLOAK_REQUIRE_HTTPS=true` in test env.
- [ ] Run `bash openbao/init-test.sh`.
- [ ] Test configuration: `docker compose -f docker-compose.yml -f docker-compose.dev.yml --env-file config/test/.env.test config`.

### Test → Prod
- [ ] Fill in all `${PLACEHOLDER}` values in `.env.prod.template` → `.env.prod`.
- [ ] Fill in all `${PLACEHOLDER}` values in `nem-realm-prod.template.json`.
- [ ] Fill in all `${PLACEHOLDER}` values in `init-prod.sh.template` → `init-prod.sh`.
- [ ] Provision real TLS certificates.
- [ ] Run OpenBao in HA mode (not dev mode).
- [ ] Run `bash openbao/init-prod.sh` from a secure bastion host.
- [ ] Delete `init-prod.sh` after use (it contains sensitive operations).

## Troubleshooting

1. **OPA has no policies**: Verify `--bundle /policies` flag is in OPA command. Check `docker compose ... config | grep -A5 opa`.
2. **Keycloak realm not imported**: Verify volume mount and `--import-realm` flag. Check `docker logs nem-keycloak | grep import`.
3. **OpenBao sealed**: In dev, vault starts in dev mode (auto-unsealed). Run `bash openbao/init-dev.sh` to load secrets.
4. **JWT missing nem:clearance_level claim**: Protocol mappers must be present on Keycloak clients. Verify in Keycloak admin → Clients → nem-mcp → Mappers.
5. **OPA returning 404 for policy path**: Check bundle `.manifest` roots include `nem`. Query: `curl http://localhost:8181/v1/data/nem`.
