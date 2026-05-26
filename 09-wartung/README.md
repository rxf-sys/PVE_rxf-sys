# 09 — Wartung

Routinen für regelmäßigen Betrieb.

## Schedules

| Cadenz       | Was                                                                |
|--------------|--------------------------------------------------------------------|
| täglich      | (auto) vzdump 02:00, host-config-backup 01:30, GC 03:30, Prune 04:00 |
| wöchentlich  | (auto) PBS-Verify Sa 05:00, Host-Config-Backup zu PBS So 01:00      |
| wöchentlich  | (manuell) apt list --upgradable auf Host + jedem Guest              |
| monatlich    | (manuell) SMART-Self-Test, dmesg-Review, freier Platz prüfen        |
| ad-hoc       | (manuell) nach Notification-Failures: Logs prüfen                   |

Siehe [checklisten.md](checklisten.md) für konkrete Step-by-Step Anleitungen.

## Häufige Tasks

- [updates.md](updates.md) — Update-Strategie und -Reihenfolge
- [checklisten.md](checklisten.md) — wöchentlich/monatlich
- [../scripts/](../scripts/) — Automatisierungs-Skripte
