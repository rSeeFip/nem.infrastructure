# nem.infrastructure — Documentation Index

**Tier**: Tier 3
**Repository**: `nem.infrastructure`

## Overview

Shared Docker Compose configurations, reverse proxy, and infrastructure tooling.
This documentation set covers the service's architecture, business logic, quality assurance, security posture, and operational guidelines following the nem.* documentation standard.

### Documentation Standard

All documentation in this repository follows the nem.* documentation conventions:

- **UPPER-CASE** file naming for all documentation files
- **Bilingual**: English primary with German (`.de.md`) translations
- **Structured**: Each document has a top-level heading, at least three sections, and substantive content
- **Cross-referenced**: Documents link to related files within the repository

## Core Documentation

These documents cover the primary aspects of the service:

| Document | Description |
|----------|-------------|
| [ARCHITECTURE](./ARCHITECTURE.md) | System architecture, component structure, and design decisions |
| [INFRASTRUCTURE](./INFRASTRUCTURE.md) | Deployment architecture, CI/CD pipeline, and observability setup |
| [QA](./QA.md) | Quality assurance strategy, test pyramid, and quality gates |
| [USER-MANUAL](./USER-MANUAL.md) | User guide for developers and operators working with the service |

## Supplementary Documentation

Additional reference documents and guides:

| Document | Description |
|----------|-------------|
| [LOCAL-FULL-PLATFORM-RUNBOOK](./LOCAL-FULL-PLATFORM-RUNBOOK.md) | Local full platform setup runbook |
| [MONITORING-ARCHITECTURE](./MONITORING-ARCHITECTURE.md) | Monitoring architecture and design |
| [MONITORING-DEVELOPMENT](./MONITORING-DEVELOPMENT.md) | Monitoring development guide |
| [MONITORING-OPERATIONS](./MONITORING-OPERATIONS.md) | Monitoring operations procedures |
| [README](./README.md) | Project overview and quick start guide |

## Navigation Guide

### For Developers

Start with [ARCHITECTURE](./ARCHITECTURE.md) to understand the system design, then review the business logic for domain rules, and [QA](./QA.md) for testing conventions.

### For Operators

Begin with [INFRASTRUCTURE](./INFRASTRUCTURE.md) for deployment details, then [USER-MANUAL](./USER-MANUAL.md) for operational procedures.

### For Security Reviews

Review the security documentation for the security architecture and compliance requirements.

## Maintenance

### Last Updated

This index was generated as part of the nem.* documentation validation process. It reflects the current state of documentation files in this repository.

### Validation

This documentation set is validated using the nem.* documentation validation suite, which checks:

- File structure and naming conventions
- Content quality (minimum line counts, section counts)
- Link integrity (no broken internal links)
- Bilingual coverage (German translations present)
- Markdown lint compliance
- Glossary term usage

## Quick Reference

### Build Commands

```bash
# Build the solution
dotnet build nem.infrastructure.slnx

# Run all tests
dotnet test nem.infrastructure.slnx

# Run with specific configuration
dotnet build nem.infrastructure.slnx --configuration Release
```

### Key Contacts

- **Repository Owner**: nem.* Platform Team
- **Documentation**: Maintained alongside code changes
- **Issue Tracking**: Repository issue tracker

### Conventions

- All documentation follows the [nem.* Documentation Standard](../../docs/040426/GLOSSARY.md)
- German translations are required for all documentation files
- File names use UPPER-CASE convention with hyphens
