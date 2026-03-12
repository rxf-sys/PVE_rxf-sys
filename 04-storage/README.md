# Storage

Storage-Konzept und Konfiguration des Proxmox Servers.

| Dokument | Beschreibung |
|----------|--------------|
| [lvm-thin.md](lvm-thin.md) | LVM-Thin Pool Konfiguration |
| [mountpoints.md](mountpoints.md) | Mount-Punkte, fstab, Ordnerstruktur |
| [berechtigungen.md](berechtigungen.md) | Dateisystem-Berechtigungen fuer unprivileged Container |

## Kurzuebersicht

| Disk | Groesse | Mount | Verwendung |
|------|---------|-------|------------|
| Kingston NVMe | 465 GB | `/` | Proxmox + LVM-Thin |
| Samsung SSD | 458 GB | `/mnt/storage` | Daten, Medien |
| Lexar SSD (USB) | 447 GB | `/mnt/backups` | Backups, PBS |

> Detailliertes Disk-Layout siehe [01-hardware/storage-layout.md](../01-hardware/storage-layout.md)
