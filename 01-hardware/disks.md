# Disk-Layout

## nvme0n1 — System (Kingston SA2000M8500G, 500 GB)

```
nvme0n1
├── nvme0n1p1   1007 K  (BIOS-Boot-Reserve)
├── nvme0n1p2     1 G  vfat   /boot/efi
└── nvme0n1p3   464 G  LVM2_member (VG: pve)
    ├── pve-swap     8 G  swap
    ├── pve-root    94 G  ext4 → /
    └── pve-data   337 G  thinpool (VG-DATA), enthält:
        ├── vm-100-disk-0   8 G  CT 100 rootfs
        ├── vm-101-disk-0  16 G  CT 101 rootfs
        ├── vm-102-disk-0   4 G  CT 102 rootfs
        ├── vm-103-disk-0   4 G  CT 103 rootfs
        ├── vm-104-disk-0  20 G  CT 104 rootfs
        ├── vm-106-disk-0  10 G  CT 106 rootfs
        ├── vm-107-disk-0   8 G  CT 107 rootfs
        ├── vm-108-disk-0   8 G  CT 108 rootfs
        ├── vm-109-disk-0   8 G  CT 109 rootfs
        ├── vm-200-disk-0   4 M  VM 200 EFI-Disk
        ├── vm-200-disk-1  32 G  VM 200 (HA OS)
        └── vm-201-disk-0  32 G  VM 201 (PBS rootfs)
```

| Pfad         | UUID                                   | Filesystem |
|--------------|----------------------------------------|------------|
| /boot/efi    | 9045-7D51                              | vfat       |
| /            | 4515a06f-cfcb-4fff-9b93-5883a2512cbd   | ext4       |
| pve-swap     | ccb14a98-0487-412b-8a8e-c224d6198c95   | swap       |

## sda — Daten (Samsung SSD 860 EVO, 500 GB)

```
sda
└── sda1   458 G  ext4 (label: storage)   /mnt/storage
```

- UUID: `37be5df3-1c31-4470-84d5-d651eaa25a22`
- Mount-Optionen: `defaults,noatime,nofail,x-systemd.device-timeout=30`
- Verwendung: Bind-Mount-Quelle für mehrere CTs

```
/mnt/storage/
├── shared/             ← CT 100 /srv/shared  (Samba)
├── media/              ← CT 100 /srv/media, CT 106 /media (Jellyfin)
├── backups/            ← CT 100 /srv/backups
├── games/              ← CT 100 /srv/games
├── extra-backups/      (manuelle Ablage)
├── immich/             ← CT 104 /srv/immich-data
├── host-configs/       (lokales Host-Config-Backup, 30 d retention)
└── lost+found/
```

## sdb — PBS-Backup-Disk (Lexar 480 GB SSD)

```
sdb
└── sdb1   447 G  ext4 (label: backups)
```

- UUID: `30c72a06-d623-4f42-b913-08e0abd784b7`
- **Nicht auf Host gemountet** — wird per `scsi1` Disk-Passthrough an VM 201 weitergereicht
- Mount-Pfad in VM 201: `/mnt/backups`
- PBS-Datastore: `backups` mit Path `/mnt/backups`
- Aktuell ~21 GB belegt, ~415 GB frei

## Backup-Strategie pro Disk

| Disk    | Verwendung    | Backup-Quelle für          | Wird selbst gesichert? |
|---------|---------------|----------------------------|------------------------|
| nvme0n1 | System + CTs/VMs | vzdump → pbs (tägl. 02:00) | ✔ via vzdump           |
| sda     | Bind-Mount-Quellen | Host-Config-Backup deckt /etc | ✘ Daten ungesichert (B9 offen) |
| sdb     | PBS-Datastore | —                          | ✘ off-site fehlt       |

**Offen:** Operator schließt 2. SSD als Spiegel für /mnt/storage an (siehe [09-wartung](../09-wartung/)).
