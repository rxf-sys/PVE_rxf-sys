# Storage-Layout

## Festplatten-Uebersicht

| Disk | Modell | Schnittstelle | Groesse | Mount | Verwendung | SMART |
|------|--------|---------------|---------|-------|------------|-------|
| NVMe | Kingston SA2000M8 | NVMe (`/dev/nvme0n1`) | 465 GB | `/` | Proxmox + LVM | PASSED |
| SSD | Samsung 860 EVO | SATA (`/dev/sda`) | 458 GB | `/mnt/storage` | Daten, Medien | PASSED |
| SSD | Lexar 480GB | USB (`/dev/sdb`) | 447 GB | `/mnt/backups` | Backups | USB* |

> *SMART via USB: `smartctl -d sat -H /dev/sdb`*

## Disk-Layout (System-NVMe)

```
/dev/nvme0n1 (500 GB NVMe)
├── nvme0n1p1    1007K   BIOS boot
├── nvme0n1p2    1G      /boot/efi (FAT32)
└── nvme0n1p3    464G    LVM (pve)
    ├── pve-swap     8G      [SWAP]
    ├── pve-root    96G      / (ext4)
    └── pve-data   337G      LVM-Thin Pool
        ├── vm-100-disk-0  15G   Samba
        ├── vm-101-disk-0   8G   Pi-hole
        ├── vm-102-disk-0   8G   WireGuard
        ├── vm-103-disk-0   8G   Vaultwarden
        ├── vm-104-disk-0   8G   Nginx PM
        ├── vm-105-disk-0  32G   Jellyfin
        ├── vm-106-disk-0  15G   Prometheus
        ├── vm-107-disk-0   8G   Grafana
        ├── vm-108-disk-0  20G   PBS
        ├── vm-109-disk-0  10G   Home Assistant
        └── vm-110-disk-0  10G   Paperless
```

## LVM-Thin Pool Status

```
LV            Size    Data%   Beschreibung
─────────────────────────────────────────────
data          337 GB  ~14%    Thin Pool
vm-100-disk-0  15 GB   9%    Samba
vm-101-disk-0   8 GB  16%    Pi-hole
vm-102-disk-0   8 GB  25%    WireGuard
vm-103-disk-0   8 GB  23%    Vaultwarden
vm-104-disk-0   8 GB  38%    Nginx PM
vm-105-disk-0  32 GB  66%    Jellyfin
vm-106-disk-0  15 GB  12%    Prometheus
vm-107-disk-0   8 GB  29%    Grafana
vm-108-disk-0  20 GB  11%    PBS
vm-109-disk-0  10 GB  47%    Home Assistant
vm-110-disk-0  10 GB  41%    Paperless
```

## Daten-SSD Mount

```bash
# UUID ermitteln
blkid /dev/sda

# /etc/fstab Eintrag
UUID=<DEINE-UUID> /mnt/storage ext4 defaults,noatime,nofail 0 2
```

## Ordnerstruktur

```
/mnt/storage/
├── shared/           # Samba-Freigabe: Allgemeine Dateien
│   └── .recycle/     # Papierkorb pro Benutzer
├── media/            # Samba-Freigabe + Jellyfin
│   ├── movies/       # Filme
│   ├── music/        # Musik
│   └── photos/       # Fotos
└── backups/          # Samba-Freigabe: Geraete-Backups

/mnt/backups/         # Backup-SSD (USB)
└── proxmox/          # PBS Datastore
```

## SMART-Pruefung

```bash
# Samsung SSD (SATA)
smartctl -H /dev/sda
smartctl -a /dev/sda

# Kingston NVMe
smartctl -H /dev/nvme0n1
smartctl -a /dev/nvme0n1

# Lexar SSD (USB)
smartctl -d sat -H /dev/sdb
smartctl -d sat -a /dev/sdb
```

## Pruefbefehle

```bash
# Storage-Status
df -h /mnt/storage /mnt/backups
pvesm status

# LVM-Status
lvs
pvs
vgs
```
