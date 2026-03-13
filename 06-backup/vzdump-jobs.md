# vzdump Backup-Jobs

## Automatischer Backup-Job

Konfiguriert ueber Proxmox Web-UI: Datacenter -> Backup

| Parameter | Wert |
|-----------|------|
| Zeitplan | Taeglich um 03:00 |
| Modus | Snapshot |
| Komprimierung | zstd |
| Storage | backup-ssd (`/mnt/backups`) |
| Container | Alle |

### Konfigurationsdatei

`/etc/pve/jobs.cfg`

```
vzdump: backup-all
    enabled 1
    schedule 03:00
    all 1
    storage backup-ssd
    compress zstd
    mode snapshot
    mailnotification always
    mailto root@localhost
    prune-backups keep-daily=7,keep-weekly=4,keep-monthly=3
```

## Retention Policy

| Parameter | Wert | Beschreibung |
|-----------|------|--------------|
| keep-daily | 7 | Letzte 7 Tages-Backups |
| keep-weekly | 4 | Letzte 4 Wochen-Backups |
| keep-monthly | 3 | Letzte 3 Monats-Backups |

> **Speicherbedarf:** 14 Versionen x ~20 GB = ~280 GB. Backup-SSD hat 440 GB.

## Manuelle Backups

```bash
# Einzelnen Container sichern
vzdump 100 --storage backup-ssd --compress zstd --mode snapshot

# Alle Container sichern
for i in $(pct list | awk 'NR>1 {print $1}'); do
  echo "=== Backup CT $i ==="
  vzdump $i --storage backup-ssd --compress zstd --mode snapshot
done

# Backup mit Notizen
vzdump 103 --storage backup-ssd --compress zstd --mode snapshot --notes-template "Vor Update"
```

## Backup-Speicherort

```bash
# Backup-SSD (primaerer Speicherort)
ls -la /mnt/backups/dump/

# Backup-Groessen pruefen
du -sh /mnt/backups/dump/*
```

## Backup-Benachrichtigungen

Proxmox sendet E-Mail-Benachrichtigungen bei:
- Erfolgreichen Backups
- Fehlgeschlagenen Backups

Konfiguration unter: Datacenter -> Notifications
