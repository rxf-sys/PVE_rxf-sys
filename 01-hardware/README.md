# 01 — Hardware

## System

| Komponente   | Wert                                     |
|--------------|------------------------------------------|
| Hersteller   | HP                                       |
| Modell       | EliteDesk 800 G5 Desktop Mini            |
| Mainboard    | HP 8594                                  |
| BIOS         | R21 Ver. 02.25.00 (09.01.2026)           |
| EFI          | aktiv, Secure Boot enabled (shim-signed) |

## CPU

| Spec                | Wert                                  |
|---------------------|---------------------------------------|
| Modell              | Intel Core i5-9500T                   |
| Architektur         | x86_64                                |
| Frequenz            | 2.20 GHz Basistakt, 3.70 GHz Turbo    |
| Kerne / Threads     | 6 / 6 (keine Hyper-Threading)         |
| TDP                 | 35 W                                  |
| Generation          | Coffee Lake Refresh (9. Gen)          |
| iGPU                | Intel UHD Graphics 630 (für Jellyfin) |

## RAM

| Spec       | Wert                |
|------------|---------------------|
| Gesamt     | 32 GB DDR4 SO-DIMM  |
| Slots      | 2 × 16 GB           |
| Geschwindigkeit | DDR4-2666 (oder höher, je nach Setup) |

## Disks

| Device  | Größe   | Modell                       | Seriennummer       | Verwendung                                       |
|---------|---------|------------------------------|--------------------|--------------------------------------------------|
| nvme0n1 | 500 GB  | Kingston SA2000M8500G        | 50026B7683BC92D3   | System (LVM): `pve-root`, `pve-swap`, `pve-data` |
| sda     | 500 GB  | Samsung SSD 860 EVO 500GB    | S4CNNX0N806119L    | Daten ext4 `/mnt/storage` (Bind-Mount-Quellen)   |
| sdb     | 480 GB  | Lexar 480GB SSD (**USB-Transport**) | J36482R000574 | Disk-Passthrough an VM 201 → `/mnt/backups`      |

Siehe [disks.md](disks.md) für Partitionierung und Mount-Details.

## Netzwerk-Hardware

- 1× Gigabit-Ethernet integriert (Intel I219-LM), benannt `nic0`
- Bridge `vmbr0` auf `nic0`, alle Guests hängen über `vmbr0`

## Anschluss / Kabel

- Stromanschluss: HP-Netzteil (135 W)
- Ethernet zu Router (Speedport / UniFi Switch)
- USB-Stick `sdc` wurde nach Recovery entfernt

> **Hinweis zu sdb:** `lsblk` meldet für die Backup-Disk `TRAN=usb`, nicht
> `sata`. Sie hängt also über Adapter/Gehäuse am USB-Bus. Das ist die
> anfälligste Stelle der Backup-Kette — siehe [disks.md](disks.md).
