# Host-Config-Backup

PVE-Host-Configs werden separat gesichert (vzdump sichert NICHT den Host selbst!).

## Lokal (täglich)

Skript: `/usr/local/sbin/backup-host-config.sh` (siehe [../scripts/backup-host-config.sh](../scripts/backup-host-config.sh))

| Setting    | Wert                                            |
|------------|-------------------------------------------------|
| Schedule   | `01:30` täglich                                 |
| Ziel       | `/mnt/storage/host-configs/`                    |
| Format     | `rxf-sys-config-YYYY-MM-DD-HHMM.tar.zst`        |
| Größe      | ~5 MB pro Backup                                |
| Retention  | 30 Tage                                         |

systemd-units: `backup-host-config.timer` + `.service`

## PBS (wöchentlich)

Skript: `/usr/local/sbin/backup-host-config-pbs.sh` (siehe [../scripts/backup-host-config-pbs.sh](../scripts/backup-host-config-pbs.sh))

| Setting       | Wert                                                 |
|---------------|------------------------------------------------------|
| Schedule      | `Sun 01:00`                                          |
| Backup-Type   | `host`                                               |
| Backup-ID     | `rxf-sys-config`                                     |
| Group in PBS  | `host/rxf-sys-config/<timestamp>`                    |
| Größe initial | ~6 MB (inkrementelle ~1 MB)                          |

## Gesicherte Pfade

| Pfad                            | Inhalt                                                |
|---------------------------------|-------------------------------------------------------|
| `/etc`                          | komplett — inkl. /etc/pve (pmxcfs)                    |
| `/var/lib/pve-cluster`          | SQLite hinter pmxcfs                                  |
| `/var/lib/rrdcached/db`         | Performance-Historie für PVE-Graphen                  |
| `/var/lib/dpkg`                 | Package-State                                         |
| `/usr/local/bin`, `/usr/local/sbin` | eigene Skripte                                    |
| `/var/spool/cron`               | per-user crons                                        |
| `/root/.ssh`                    | SSH-Keys, authorized_keys                             |
| `/var/backups`                  | dpkg-history etc.                                     |
| `snapshots/`                    | textuelle Recovery-Cheatsheets (lsblk, pvesm, pct list…) |

## systemd-Status

```bash
systemctl list-timers backup-host-config* --no-pager
systemctl status backup-host-config.service
systemctl status backup-host-config-pbs.service

# letztes Backup
ls -la /mnt/storage/host-configs/ | tail
```

## Restore-Strategie

Bei totalem Verlust:
1. Frische PVE-Installation
2. Erstes Backup-Tar herunterladen (entweder vom /mnt/storage/host-configs/ oder via proxmox-backup-client von PBS)
3. Auspacken nach `/`:
   ```bash
   tar -I zstd -xf rxf-sys-config-YYYY-MM-DD.tar.zst -C /
   systemctl daemon-reload
   pvesm status
   ```
4. Snapshots-Datei prüfen für Topologie

Siehe [../10-disaster-recovery/](../10-disaster-recovery/).
