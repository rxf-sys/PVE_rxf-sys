# Disk-Layout

## nvme0n1 — System (Kingston SA2000M8500G, 500 GB)

SMART: PASSED, **7 % Abnutzung**, 31,2 TB geschrieben, 10751 Betriebsstunden,
36 °C, 0 Fehler, Available Spare 100 %.


```
nvme0n1
├── nvme0n1p1   1007 K  (BIOS-Boot-Reserve)
├── nvme0n1p2     1 G  vfat   /boot/efi
└── nvme0n1p3   464 G  LVM2_member (VG: pve)
    ├── pve-swap     8 G  swap
    ├── pve-root    96 G  ext4 → /   (94 G nutzbar, 26 % belegt)
    └── pve-data   337.9 G  thinpool, 18.4 % Data / 1.1 % Meta, enthält:
        ├── vm-100-disk-0   8 G  CT 100 rootfs   (14 %)
        ├── vm-101-disk-0  16 G  CT 101 rootfs   (40 %)
        ├── vm-102-disk-0   4 G  CT 102 rootfs   (47 %)
        ├── vm-103-disk-0   4 G  CT 103 rootfs   (61 %)
        ├── vm-105-disk-0  12 G  CT 105 rootfs   (26 %)
        ├── vm-106-disk-0  10 G  CT 106 rootfs   (18 %)
        ├── vm-107-disk-0   8 G  CT 107 rootfs   (15 %)
        ├── vm-108-disk-0   8 G  CT 108 rootfs   (14 %)
        ├── vm-109-disk-0  24 G  CT 109 rootfs   (79 %)  ← höchste Belegung
        ├── vm-110-disk-0   8 G  CT 110 rootfs   (20 %)
        ├── vm-111-disk-0  16 G  CT 111 rootfs   (56 %)
        ├── vm-200-disk-0   4 M  VM 200 EFI-Disk
        ├── vm-200-disk-1  32 G  VM 200 (HA OS)  (24 %)
        └── vm-201-disk-0  32 G  VM 201 (PBS rootfs) (18 %)
```

Die VG `pve` hat noch **16 GB PFree** — Reserve für eine Thin-Pool-Erweiterung.
`vm-104-disk-0` (20 G) ist mit CT 104 entfallen; es sind keine verwaisten
Volumes mehr in `local-lvm`.

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
- Belegung: 248 GB von 458 GB (58 %)
- SMART: PASSED, 8261 Betriebsstunden, 2059 Power-Cycles, Wear-Leveling 18,
  0 realloziert, 42 °C

```
/mnt/storage/
├── shared/             ← CT 100 /srv/shared  (Samba)
├── media/              ← CT 100 /srv/media, CT 106 /media (Jellyfin)
├── backups/            ← CT 100 /srv/backups
├── games/              ← CT 100 /srv/games
├── extra-backups/      (manuelle Ablage)
├── immich/             ← verwaist: CT 104 wurde aufgelöst, Immich entfernt
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
- Aktuell ~31 GB belegt von 460 GB (6,99 %), 174 Snapshots
- SMART: PASSED, 10340 Betriebsstunden, 919 Power-Cycles, 48 °C

> **Transport ist USB, nicht SATA.** `lsblk` meldet für sdb `TRAN=usb` — die
> Disk hängt also über einen Adapter oder ein Gehäuse am Bus, nicht direkt am
> SATA-Port. Für die Backup-Disk ist das die schwächste Stelle der Kette: USB
> ist anfälliger für Resets und Verbindungsabbrüche als SATA, und ein
> weggebrochener Datastore bricht die nächtlichen Backups. Beim nächsten
> Gehäuse-Eingriff prüfen, ob ein direkter SATA-Anschluss möglich ist.

## Backup-Strategie pro Disk

| Disk    | Verwendung    | Backup-Quelle für          | Wird selbst gesichert? |
|---------|---------------|----------------------------|------------------------|
| nvme0n1 | System + CTs/VMs | vzdump → pbs (tägl. 02:00) | ✔ via vzdump           |
| sda     | Bind-Mount-Quellen | Host-Config-Backup deckt /etc | ✘ Daten ungesichert (B9 offen) |
| sdb     | PBS-Datastore | —                          | ✘ off-site fehlt       |

**Offen:** Operator schließt 2. SSD als Spiegel für /mnt/storage an (siehe [09-wartung](../09-wartung/)).
