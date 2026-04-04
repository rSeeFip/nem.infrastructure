# nem.infrastructure — Dokumentationsindex

**Stufe**: Tier 3
**Repository**: `nem.infrastructure`

## Übersicht

Shared Docker Compose configurations, reverse proxy, and infrastructure tooling.
Diese Dokumentationssammlung umfasst die Architektur, Geschäftslogik, Qualitätssicherung, Sicherheitsarchitektur und betrieblichen Richtlinien des Services gemäß dem nem.* Dokumentationsstandard.

### Dokumentationsstandard

Alle Dokumentationen in diesem Repository folgen den nem.* Dokumentationskonventionen:

- **GROSSBUCHSTABEN**-Dateibenennung für alle Dokumentationsdateien
- **Zweisprachig**: Englisch als Primärsprache mit deutschen (`.de.md`) Übersetzungen
- **Strukturiert**: Jedes Dokument hat eine Hauptüberschrift, mindestens drei Abschnitte und substanziellen Inhalt
- **Querverwiesen**: Dokumente verlinken auf verwandte Dateien innerhalb des Repositorys

## Kerndokumentation

Diese Dokumente behandeln die primären Aspekte des Services:

| Dokument | Beschreibung |
|----------|-------------|
| [ARCHITECTURE](./ARCHITECTURE.de.md) | System architecture, component structure, and design decisions |
| [INFRASTRUCTURE](./INFRASTRUCTURE.de.md) | Deployment architecture, CI/CD pipeline, and observability setup |
| [QA](./QA.de.md) | Quality assurance strategy, test pyramid, and quality gates |
| [USER-MANUAL](./USER-MANUAL.de.md) | User guide for developers and operators working with the service |

## Ergänzende Dokumentation

Zusätzliche Referenzdokumente und Anleitungen:

| Dokument | Beschreibung |
|----------|-------------|
| [LOCAL-FULL-PLATFORM-RUNBOOK](./LOCAL-FULL-PLATFORM-RUNBOOK.de.md) | Local full platform setup runbook |
| [MONITORING-ARCHITECTURE](./MONITORING-ARCHITECTURE.de.md) | Monitoring architecture and design |
| [MONITORING-DEVELOPMENT](./MONITORING-DEVELOPMENT.de.md) | Monitoring development guide |
| [MONITORING-OPERATIONS](./MONITORING-OPERATIONS.de.md) | Monitoring operations procedures |
| [README](./README.de.md) | Project overview and quick start guide |

## Navigationsführer

### Für Entwickler

Beginnen Sie mit der Architekturdokumentation, um das Systemdesign zu verstehen, dann überprüfen Sie die Geschäftslogik für Domänenregeln und die QA-Dokumentation für Testkonventionen.

### Für Betriebsteams

Beginnen Sie mit der Infrastrukturdokumentation für Deployment-Details und dann dem Benutzerhandbuch für Betriebsverfahren.

### Für Sicherheitsprüfungen

Überprüfen Sie die Sicherheitsdokumentation für die Sicherheitsarchitektur und die Compliance-Anforderungen.

## Wartung

### Letzte Aktualisierung

Dieser Index wurde als Teil des nem.* Dokumentationsvalidierungsprozesses erstellt. Er spiegelt den aktuellen Stand der Dokumentationsdateien in diesem Repository wider.

### Validierung

Diese Dokumentationssammlung wird mit der nem.* Dokumentationsvalidierungssuite validiert, die folgendes prüft:

- Dateistruktur und Namenskonventionen
- Inhaltsqualität (Mindestzeilenanzahl, Abschnittsanzahl)
- Link-Integrität (keine defekten internen Links)
- Zweisprachige Abdeckung (deutsche Übersetzungen vorhanden)
- Markdown-Lint-Konformität
- Glossar-Begriffsverwendung

## Schnellreferenz

### Build-Befehle

```bash
# Lösung erstellen
dotnet build nem.infrastructure.slnx

# Alle Tests ausführen
dotnet test nem.infrastructure.slnx

# Mit spezifischer Konfiguration erstellen
dotnet build nem.infrastructure.slnx --configuration Release
```

### Schlüsselkontakte

- **Repository-Besitzer**: nem.* Plattform-Team
- **Dokumentation**: Wird zusammen mit Code-Änderungen gepflegt
- **Issue-Tracking**: Repository-Issue-Tracker

### Konventionen

- Alle Dokumentationen folgen dem [nem.* Dokumentationsstandard](../../docs/040426/GLOSSARY.md)
- Deutsche Übersetzungen sind für alle Dokumentationsdateien erforderlich
- Dateinamen verwenden GROSSBUCHSTABEN-Konvention mit Bindestrichen
