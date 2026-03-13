# Changelog

Alle wichtigen Aenderungen am Server und an der Dokumentation.

## [2026-03-13] - Security-Hardening und Best-Practice Audit

### Geaendert
- SSH-Haertung: PermitRootLogin prohibit-password, PasswordAuthentication no
- Fail2ban aktiviert mit SSH-Jail und Proxmox-Jail (Port 8006)
- 2FA (TOTP) fuer Proxmox Web-UI aktiviert
- Backup-Storage von `local` (System-SSD) auf `backup-ssd` (/mnt/backups) umgestellt
- Backup-Retention erweitert: keep-daily=7, keep-weekly=4, keep-monthly=3
- Swap auf 0 fuer alle 12 Container gesetzt
- keyctl fuer alle Docker-Container aktiviert (CT 102, 103, 104, 110, 111)
- CPU-Limits fuer alle Container konfiguriert
- Firewall-Regeln fuer CT 105 (Jellyfin), 109 (Home Assistant), 110 (Paperless), 111 (Finance) erstellt
- Alte Kernel entfernt (nur noch 6.17.13-1-pve)
- PBS-Repo Suite von bookworm auf trixie korrigiert
- CT 111 (Finance) in Netzwerk-Diagramm und Container-Uebersicht aufgenommen

### Dokumentation aktualisiert
- 09-wartung/proxmox-best-practices.md: Alle erledigten Punkte als "Erledigt" markiert
- 08-sicherheit/haertung.md: SSH und Fail2ban Status aktualisiert, Proxmox-Jail dokumentiert
- 08-sicherheit/2fa.md: 2FA-Status auf "Aktiv" gesetzt
- 08-sicherheit/README.md: Sicherheits-Uebersicht aktualisiert
- 03-netzwerk/firewall.md: Firewall-Regeln fuer alle Container dokumentiert
- 06-backup/vzdump-jobs.md: Storage und Retention aktualisiert
- README.md: Proxmox-Version, Kernel, CT 111 hinzugefuegt

### Audit-Ergebnis
- Vorher: 38/50 PASS, 3 WARN, 9 FAIL
- Nachher: 48/50 PASS, 2 WARN, 0 FAIL

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
