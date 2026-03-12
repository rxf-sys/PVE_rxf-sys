# Proxmox VE Installation

## Voraussetzungen

- USB-Stick mit Proxmox VE ISO (mind. 2 GB)
- Proxmox ISO Download: https://www.proxmox.com/de/downloads
- Rufus oder Etcher zum Erstellen des Boot-Sticks

## Installations-Parameter

| Parameter | Wert |
|-----------|------|
| **Version** | Proxmox VE 9.x |
| **Ziel-Disk** | `/dev/nvme0n1` (500GB Kingston NVMe) |
| **Dateisystem** | ext4 |
| **Swap** | 8 GB |
| **Root-Partition** | 96 GB |
| **Thin Pool** | 337 GB (Rest) |
| **Hostname** | rxfsys |
| **IP** | 192.168.2.120/24 |
| **Gateway** | 192.168.2.1 |
| **DNS** | 192.168.2.1 (spaeter Pi-hole) |

## Partitionierung

```
/dev/nvme0n1 (500 GB NVMe)
├── nvme0n1p1    1007K   BIOS boot
├── nvme0n1p2    1G      /boot/efi (FAT32)
└── nvme0n1p3    464G    LVM (pve)
    ├── pve-swap     8G      [SWAP]
    ├── pve-root    96G      / (ext4)
    └── pve-data   337G      LVM-Thin Pool
```

## Installations-Schritte

1. Von USB booten (UEFI-Modus)
2. "Install Proxmox VE" auswaehlen
3. EULA akzeptieren
4. Ziel-Disk `/dev/nvme0n1` auswaehlen
5. Land/Zeitzone: Deutschland / Europe/Berlin
6. Root-Passwort und E-Mail setzen
7. Netzwerk konfigurieren (siehe Tabelle oben)
8. Zusammenfassung pruefen und installieren
9. Nach Neustart: https://192.168.2.120:8006

## Nach der Installation

Weiter mit [post-install.md](post-install.md)
