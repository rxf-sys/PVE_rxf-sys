# 04 — Storage

## Überblick

| Storage     | Typ      | Größe   | Belegt | Verwendung                                  |
|-------------|----------|---------|--------|---------------------------------------------|
| `local`     | dir      | 94 GB   | ~6 GB  | ISOs, Templates, vzdump (lokal)             |
| `local-lvm` | lvmthin  | 337 GB  | ~15 %  | CT/VM Disks (thin-provisioned)              |
| `pbs`       | pbs      | 460 GB  | ~5 %   | PBS-Datastore (in VM 201 via Token-Access)  |

```bash
pvesm status
```

## NVMe-Layout (System)

```
nvme0n1 (500 GB)
├── nvme0n1p1   (BIOS-Boot-Reserve)
├── nvme0n1p2   1 G   vfat   /boot/efi
└── nvme0n1p3   464 G LVM2 (VG: pve)
    ├── pve-swap     8 G   swap
    ├── pve-root    94 G   ext4 /
    └── pve-data   337 G   thinpool
```

`pve-data` enthält alle Guest-Disks (siehe [01-hardware/disks.md](../01-hardware/disks.md)).

## sda — /mnt/storage

Samsung SSD 860 EVO 500 GB, ext4. Mount via `/etc/fstab`:

```
UUID=37be5df3-1c31-4470-84d5-d651eaa25a22 /mnt/storage ext4 defaults,noatime,nofail,x-systemd.device-timeout=30 0 2
```

Verzeichnisstruktur und Bind-Mounts: siehe [bind-mounts.md](bind-mounts.md).

## sdb — PBS-Passthrough

Lexar 480 GB SSD wird per `scsi1` Disk-Passthrough an VM 201 weitergereicht:

```
qm config 201 | grep scsi1
# scsi1: /dev/disk/by-id/ata-Lexar_480GB_SSD_J36482R000574,backup=0,iothread=1,size=468851544K
```

- **Nicht auf Host gemountet** (sonst Dateisystem-Konflikt mit VM)
- In VM 201: `/dev/sdb1` → `/mnt/backups`
- PBS-Datastore `backups`, Pfad `/mnt/backups`
- `backup=0` damit die Disk NICHT in PVE-Backups landet (wäre ja Backup-Storage doppelt)

## Storage-Sicherung

| Storage                    | Backup-Mechanismus                            |
|----------------------------|-----------------------------------------------|
| local-lvm (CT/VM Disks)    | vzdump → pbs daily 02:00                      |
| local (ISOs/Templates)     | Nicht gebackupt (sind extern beziehbar)       |
| /mnt/storage (sda)         | **OFFEN** — siehe [09-wartung](../09-wartung/) |
| pbs-datastore (sdb in VM)  | Off-site fehlt (alles auf einer Platte)       |

Siehe [../06-backup/](../06-backup/) für Backup-Strategie.
