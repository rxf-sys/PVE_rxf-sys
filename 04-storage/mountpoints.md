# Mount-Punkte und Ordnerstruktur

## /etc/fstab

```
# System (automatisch bei Installation)
# /dev/pve/root    /           ext4  defaults       0 1
# /dev/pve/swap    none        swap  sw             0 0
# UUID=...         /boot/efi   vfat  defaults       0 1

# Daten-SSD
UUID=<DEINE-UUID> /mnt/storage ext4 defaults,noatime,nofail 0 2

# Backup-SSD (USB)
UUID=<DEINE-UUID> /mnt/backups ext4 defaults,noatime,nofail 0 2
```

> **nofail**: Verhindert Boot-Fehler falls die Disk nicht angeschlossen ist (besonders wichtig fuer USB).

## Ordnerstruktur

```
/mnt/storage/                    # Samsung 860 EVO (458 GB)
├── shared/                      # Samba-Freigabe: Allgemeine Dateien
│   └── .recycle/                # Papierkorb pro Benutzer
├── media/                       # Samba-Freigabe + Jellyfin
│   ├── movies/                  # Filme
│   ├── music/                   # Musik
│   └── photos/                  # Fotos
└── backups/                     # Samba-Freigabe: Geraete-Backups

/mnt/backups/                    # Lexar 480GB (USB)
└── proxmox/                     # PBS Datastore
```

## Container Bind-Mounts

| Container | Host-Pfad | Container-Pfad | Beschreibung |
|-----------|-----------|----------------|--------------|
| CT 100 (Samba) | /mnt/storage/shared | /srv/shared | Dateifreigabe |
| CT 100 (Samba) | /mnt/storage/media | /srv/media | Medien-Freigabe |
| CT 100 (Samba) | /mnt/storage/backups | /srv/backups | Backup-Freigabe |
| CT 105 (Jellyfin) | /mnt/storage/media | /media | Medien-Bibliothek |

### Konfiguration in Container-Config

```ini
# CT 100 (Samba) - /etc/pve/lxc/100.conf
mp0: /mnt/storage/shared,mp=/srv/shared
mp1: /mnt/storage/media,mp=/srv/media
mp2: /mnt/storage/backups,mp=/srv/backups

# CT 105 (Jellyfin) - /etc/pve/lxc/105.conf
mp0: /mnt/storage/media,mp=/media
```

## Proxmox Storage-Konfiguration

```bash
# Aktuelle Storage-Konfiguration anzeigen
pvesm status

# Storage-Datei
cat /etc/pve/storage.cfg
```
