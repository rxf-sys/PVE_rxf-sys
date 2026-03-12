# vzdump Backup-Jobs

## Automatischer Backup-Job

Konfiguriert ueber Proxmox Web-UI: Datacenter -> Backup

| Parameter | Wert |
|-----------|------|
| Zeitplan | Taeglich um 03:00 |
| Modus | Snapshot |
| Komprimierung | zstd |
| Storage | local (oder PBS) |
| Container | Alle |

### Konfigurationsdatei

`/etc/pve/vzdump.cron` oder `/etc/pve/jobs.cfg`

```
# Beispiel vzdump.conf
vzdump: backup-all
    enabled 1
    schedule 03:00
    all 1
    storage local
    compress zstd
    mode snapshot
    mailnotification always
    mailto root@localhost
```

## Retention Policy

| Parameter | Wert | Beschreibung |
|-----------|------|--------------|
| keep-daily | 3 | Letzte 3 Tages-Backups |
| keep-weekly | 2 | Letzte 2 Wochen-Backups |
| keep-monthly | 1 | Letztes Monats-Backup |

## Manuelle Backups

```bash
# Einzelnen Container sichern
vzdump 100 --storage local --compress zstd --mode snapshot

# Alle Container sichern
for i in $(pct list | awk 'NR>1 {print $1}'); do
  echo "=== Backup CT $i ==="
  vzdump $i --storage local --compress zstd --mode snapshot
done

# Backup mit Notizen
vzdump 103 --storage local --compress zstd --mode snapshot --notes-template "Vor Update"
```

## Backup-Speicherort

```bash
# Standard-Speicherort fuer vzdump
ls -la /var/lib/vz/dump/

# Backup-Groessen pruefen
du -sh /var/lib/vz/dump/*
```

## Backup-Benachrichtigungen

Proxmox sendet E-Mail-Benachrichtigungen bei:
- Erfolgreichen Backups
- Fehlgeschlagenen Backups

Konfiguration unter: Datacenter -> Notifications
