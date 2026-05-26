# 06 — Backup

## Schichten

1. **PVE vzdump** — Snapshot aller CTs+VMs → PBS-Datastore (siehe [pve-vzdump.md](pve-vzdump.md))
2. **PBS-Datastore** — Dedup-Storage in VM 201, automatisches GC/Prune/Verify (siehe [pbs-setup.md](pbs-setup.md))
3. **Host-Config-Backup** — eigenes Skript für PVE-Host-Files (siehe [host-config-backup.md](host-config-backup.md))
4. **Restore** — Procedures (siehe [restore-procedures.md](restore-procedures.md))

## Schedules

| Cron                | Job                                                 |
|---------------------|-----------------------------------------------------|
| 01:30 daily         | Host-Config-Backup (local tar.zst → /mnt/storage/)  |
| 02:00 daily         | vzdump `pbs-nightly` (alle Guests außer VM 201)     |
| 03:30 daily         | PBS Garbage Collection (Datastore: backups)         |
| 04:00 daily         | PBS Prune `daily-prune` (keep-daily 7, keep-weekly 4, keep-monthly 6) |
| 05:00 Sa            | PBS Verify (Default-Verify-Job)                     |
| 01:00 So            | Host-Config-Backup zu PBS (host/rxf-sys-config)     |

## Übersicht Backup-Wege

```
PVE-Host (rxf-sys)                       PBS-VM (192.168.2.209)
    │                                          │
    │ vzdump pbs-nightly (02:00 daily)         │
    │  → snapshots aller CTs+VMs               │
    ├──────────────────────────────────────────┤
    │ host-config-backup-pbs.sh (Sun 01:00)    │
    │  → host/rxf-sys-config                   │
    └──────────────────────────────────────────┤
                                               │
                                          PBS-Datastore "backups"
                                               │  GC (03:30)
                                               │  Prune (04:00)
                                               │  Verify (Sa 05:00)
                                               ↓
                                          sdb (/mnt/backups, 460 GB)
```

## Was NICHT in PBS gesichert wird

| Daten                              | Sicherung      |
|------------------------------------|----------------|
| /mnt/storage/* (Bind-Mount-Quellen) | ❌ B9 offen   |
| sdb-Passthrough (PBS-Datastore selbst) | ❌ kein Off-Site |
| VM 201 (PBS-VM) selbst             | ❌ (exclude 201) |

Sind alles Single-Point-of-Failure-Risiken. Off-Site-Backup-Plan: siehe [../09-wartung/](../09-wartung/).
