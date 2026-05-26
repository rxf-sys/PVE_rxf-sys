# Storage-Diagramm

## Physische Disks

```
┌────────────────────────────────────────────────────────────────────┐
│  PVE-Host rxf-sys                                                  │
│                                                                    │
│  ┌─────────────────┐  ┌────────────────┐  ┌────────────────────┐   │
│  │ nvme0n1   500 G │  │  sda     500 G │  │  sdb         480 G │   │
│  │ Kingston SA2000 │  │  Samsung 860EVO│  │  Lexar SSD         │   │
│  │                 │  │                │  │                    │   │
│  │ ┌─ pve-root 94G │  │ ┌── sda1 458G  │  │ ┌── sdb1 (PT)      │   │
│  │ ├─ pve-swap  8G │  │ │   ext4       │  │ │   (passthrough   │   │
│  │ └─ pve-data    │  │ │   /mnt/      │  │ │    an VM 201)    │   │
│  │    337G thinpool│  │ │   storage    │  │ │                  │   │
│  │      │          │  │ │              │  │ │                  │   │
│  │      ├ vm-100-* │  │ │ shared/      │  │ └── in VM 201:     │   │
│  │      ├ vm-101-* │  │ │ media/       │  │     /mnt/backups   │   │
│  │      ├ vm-102-* │  │ │ backups/     │  │     PBS-Datastore  │   │
│  │      ├ vm-103-* │  │ │ games/       │  │     "backups"      │   │
│  │      ├ vm-104-* │  │ │ immich/      │  │                    │   │
│  │      ├ vm-106-* │  │ │ host-configs/│  │     ~21 GB / 447 GB│   │
│  │      ├ vm-107-* │  │ │              │  │     Dedup-Ratio    │   │
│  │      ├ vm-108-* │  │ │              │  │     ~32×           │   │
│  │      ├ vm-109-* │  │ │              │  │                    │   │
│  │      ├ vm-200-* │  │ │              │  │                    │   │
│  │      └ vm-201-* │  │ │              │  │                    │   │
│  └─────────────────┘  └────────────────┘  └────────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
```

## Bind-Mounts (Host → CTs)

```mermaid
flowchart LR
  subgraph "/mnt/storage (sda1)"
    shared[/mnt/storage/shared/]
    media[/mnt/storage/media/]
    backups[/mnt/storage/backups/]
    games[/mnt/storage/games/]
    immich[/mnt/storage/immich/]
    hostcfg[/mnt/storage/host-configs/]
  end

  CT100[CT 100 nas]
  CT104[CT 104 docker-host]
  CT106[CT 106 jellyfin]
  HostBackup[Host-Config-Backup]

  shared --> CT100
  media  --> CT100
  backups --> CT100
  games  --> CT100
  media  --> CT106
  immich --> CT104
  HostBackup --> hostcfg
```

## Storage-Flow Backup

```
┌──────────────┐  vzdump 02:00     ┌─────────────────────────┐
│  PVE-Host    │ ───────────────► │  PBS-VM 201 Datastore   │
│  + alle CTs/VMs│                  │  /mnt/backups (sdb1)    │
└──────────────┘                    │  47 % verfügbar 415 GB  │
        │                           └───────────┬─────────────┘
        │                                       │
        │ host-config-backup.sh 01:30           │ Garbage Collection 03:30
        ▼                                       │ Prune 04:00
┌──────────────────────────────┐                │ Verify Sa 05:00
│  /mnt/storage/host-configs/  │                │
│  (sda1, 30 d retention)      │                │
└──────────────────────────────┘                │
        │                                       │
        │ host-config-backup-pbs.sh So 01:00    │
        └───────────────────────────────────────┤
                                                ▼
                                       host/rxf-sys-config
```

## PBS-Datastore Inhalt (Stand 2026-05-25)

```
backups (in VM 201)
├── ct/
│   ├── 100/  (nas)            ~ 9 Snapshots
│   ├── 101/  (admin-dashboard) ~ 9 Snapshots
│   ├── 102/  (vaultwarden)    ~ 9 Snapshots
│   ├── 103/  (uptime-kuma)    ~ 9 Snapshots
│   ├── 104/  (docker-host)    ~ 9 Snapshots
│   ├── 105/  (DEPRECATED)     alte Snapshots, pruned over time
│   ├── 106/  (jellyfin)       ~ 9 Snapshots
│   ├── 107/  (portfolio)      ~ 9 Snapshots
│   ├── 108/  (welcome-page)   ~ 9 Snapshots
│   └── 109/  (orynthia)       ~ 9 Snapshots
├── vm/
│   └── 200/  (homeassistant)  ~ 9 Snapshots
└── host/
    └── rxf-sys-config/         ~ 4 wöchentliche Snapshots
```

Retention (Prune-Policy `daily-prune`):
- keep-daily: 7
- keep-weekly: 4
- keep-monthly: 6
