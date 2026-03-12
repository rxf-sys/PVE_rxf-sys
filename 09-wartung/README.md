# Wartung

Wartungsplan und Routinen fuer den Proxmox Server.

| Dokument | Beschreibung |
|----------|--------------|
| [update-prozedur.md](update-prozedur.md) | PVE Updates, Kernel Updates, Container Updates |
| [checkliste-woechentlich.md](checkliste-woechentlich.md) | Woechentliche Pruefungen |
| [checkliste-monatlich.md](checkliste-monatlich.md) | Monatliche Pruefungen |

## Automatisierte Tasks

| Task | Zeitplan | Beschreibung |
|------|----------|--------------|
| DuckDNS Update | */5 * * * * | IP-Aktualisierung |
| Container-Backup | 03:00 taeglich | vzdump aller Container |
| PBS Prune | woechentlich | Alte Backups entfernen |

## Schnelldiagnose

```bash
# Diagnose-Script ausfuehren
./scripts/rxfsys-diagnostics.sh

# Auto-Update Script
./scripts/rxfsys-autoupdate.sh
```
