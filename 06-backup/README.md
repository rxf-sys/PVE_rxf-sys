# Backup

Backup-Konzept, Zeitplaene und Restore-Anleitungen.

| Dokument | Beschreibung |
|----------|--------------|
| [vzdump-jobs.md](vzdump-jobs.md) | Backup-Zeitplaene, Retention |
| [proxmox-backup-server.md](proxmox-backup-server.md) | PBS Konfiguration (CT 108) |
| [restore-anleitung.md](restore-anleitung.md) | Restore-Prozeduren und Tests |

## Backup-Strategie

| Ebene | Methode | Ziel | Zeitplan |
|-------|---------|------|----------|
| Container-Backup | vzdump (Snapshot) | local / PBS | Taeglich 03:00 |
| PBS Prune | Retention Policy | PBS Datastore | Woechentlich |
| Kritische Daten | Datei-Backup | /mnt/backups | Nach Bedarf |

## Kritische Backup-Ziele

| Dienst | Pfad | Prioritaet |
|--------|------|------------|
| Vaultwarden DB | `/srv/appdata/vaultwarden/db.sqlite3` | KRITISCH |
| WireGuard Keys | `/srv/appdata/wireguard/` | KRITISCH |
| Pi-hole Config | `/etc/pihole/` | Wichtig |
| Nginx SSL-Zerts | `/srv/appdata/nginx-proxy/letsencrypt/` | Wichtig |
| Home Assistant | `/srv/homeassistant/` | Wichtig |
| Paperless Daten | `/srv/paperless/` | Wichtig |
