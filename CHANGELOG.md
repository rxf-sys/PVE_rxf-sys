# Changelog

Alle wichtigen Aenderungen am Server und an der Dokumentation.

## [2026-03-12] - Dokumentationsstruktur

### Hinzugefuegt
- Vollstaendige Dokumentationsstruktur mit nummerierten Abschnitten (01-10)
- 01-hardware: Server-Specs, Storage-Layout, Netzwerk-Hardware
- 02-installation: Proxmox Installation, Post-Install, Automatisierungs-Script
- 03-netzwerk: Bridges, IP-Schema, Firewall, Netzwerk-Diagramme (ASCII + Mermaid)
- 04-storage: LVM-Thin, Mount-Punkte, Berechtigungen
- 05-container: Neue Struktur mit lxc/, vms/, templates/ Unterordnern
- 06-backup: vzdump Jobs, PBS-Konfiguration, Restore-Anleitung
- 07-monitoring: Prometheus + Grafana Setup, Alerting
- 08-sicherheit: Benutzer/Rollen, Zertifikate, 2FA, System-Haertung
- 09-wartung: Update-Prozedur, woechentliche/monatliche Checklisten
- 10-disaster-recovery: Notfall-Kontakte, Wiederherstellung, Bare-Metal-Restore, Troubleshooting
- configs/ Verzeichnis mit anonymisierten Konfigurationsdateien
- Neue Scripts: backup-all.sh, health-check.sh, vm-inventory.sh
- Templates fuer neue Container-Dokumentation
- diagramme/ Verzeichnis fuer draw.io Dateien
- .gitignore fuer sensible Daten
- CHANGELOG.md

## [2026-02-xx] - Initiale Dokumentation

### Hinzugefuegt
- README.md mit Server-Uebersicht
- homeserver-dokumentation.md (Haupt-Dokumentation)
- Container-Dokumentation (CT100-CT110)
- Scripts: rxfsys-diagnostics.sh, rxfsys-autoupdate.sh

## [2026-01-xx] - Server-Aufbau

### Hinzugefuegt
- Proxmox VE 9.1.x Installation
- LXC-Container: Samba, Pi-hole, WireGuard, Vaultwarden, Nginx PM, Jellyfin
- DuckDNS Konfiguration
- Let's Encrypt via Nginx Proxy Manager

---

*Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/)*
