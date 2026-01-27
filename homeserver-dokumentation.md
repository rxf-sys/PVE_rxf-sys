# Home-Server Hauptdokumentation

**Server:** rxfsys  
**Erstellt:** Januar 2026  
**Proxmox Version:** 9.1.1  
**Kernel:** Linux 6.17.2-1-pve (EFI Secure Boot)

---

## Inhaltsverzeichnis

1. [Hardware-Spezifikationen](#hardware-spezifikationen)
2. [Netzwerk-Konfiguration](#netzwerk-konfiguration)
3. [Storage-Konfiguration](#storage-konfiguration)
4. [Container-Konfigurationen](#container-konfigurationen)
5. [Firewall-Regeln](#firewall-regeln)
6. [Dienste und Zugangsdaten](#dienste-und-zugangsdaten)
7. [DuckDNS Konfiguration](#duckdns-konfiguration)
8. [Backup-Strategie](#backup-strategie)
9. [Wartungsprozeduren](#wartungsprozeduren)

---

## Hardware-Spezifikationen

### System

| Komponente | Spezifikation |
|------------|---------------|
| **CPU** | Intel Core i5-9500T @ 2.20GHz (6 Cores, 6 Threads) |
| **RAM** | 32 GB DDR4 |
| **Boot-Mode** | EFI (Secure Boot aktiv) |

### Storage

| Disk | Modell | Schnittstelle | Größe | Mount | Verwendung |
|------|--------|---------------|-------|-------|------------|
| System | Kingston SA2000M8 500GB | NVMe (`/dev/nvme0n1`) | 465 GB | `/` | Proxmox, LVM |
| Daten | Samsung SSD 860 EVO 500GB | SATA (`/dev/sda`) | 458 GB | `/mnt/storage` | NAS, Medien |
| Backup | 500 GB SSD | SATA | 500 GB | `/mnt/backups` | Backups (TODO) |

### SMART-Status

```bash
# Prüfbefehle
smartctl -H /dev/sda        # Samsung SSD
smartctl -H /dev/nvme0n1    # Kingston NVMe
```

### Ressourcen-Verteilung

```
RAM-Aufteilung:
  Proxmox Host:        ~2 GB
  CT 100 (NAS):         1 GB
  CT 101 (Pi-hole):     1 GB
  CT 102 (WireGuard):   1 GB
  CT 103 (Vaultwarden): 2 GB
  CT 104 (Nginx):       1 GB
  CT 105 (Jellyfin):    2 GB
  ─────────────────────────
  Gesamt zugewiesen:   ~10 GB
  Verfügbar:           ~22 GB
```

---

## Netzwerk-Konfiguration

### Host-Netzwerk

**Datei:** `/etc/network/interfaces`

```
auto lo
iface lo inet loopback

iface nic0 inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.2.120/24
    gateway 192.168.2.1
    bridge-ports nic0
    bridge-stp off
    bridge-fd 0

source /etc/network/interfaces.d/*
```

### IP-Adress-Schema

| Bereich | IPs | Verwendung |
|---------|-----|------------|
| 192.168.2.1 | .1 | Router/Gateway (Speedport Smart 4) |
| 192.168.2.2-29 | .2-.29 | Reserviert (statische Geräte) |
| 192.168.2.30-119 | .30-.119 | DHCP-Bereich (Pi-hole) |
| 192.168.2.120-126 | .120-.126 | Server-Infrastruktur (statisch) |
| 192.168.2.127-254 | .127-.254 | Reserviert/Frei |

### Statische IP-Zuweisungen

| IP | Hostname | MAC-Adresse | Dienst |
|----|----------|-------------|--------|
| 192.168.2.120 | rxfsys (Host) | - | Proxmox |
| 192.168.2.121 | nas | BC:24:11:90:E2:A7 | Samba |
| 192.168.2.122 | pi-hole | BC:24:11:44:B6:42 | DNS/DHCP |
| 192.168.2.123 | wireguard | BC:24:11:7B:30:3F | VPN |
| 192.168.2.124 | vaultwarden | BC:24:11:C6:9B:7C | Passwörter |
| 192.168.2.125 | nginx-proxy | BC:24:11:F6:DB:42 | Reverse Proxy |
| 192.168.2.126 | jellyfin | - | Media Server |

### DHCP-Konfiguration (Pi-hole)

| Parameter | Wert |
|-----------|------|
| DHCP-Server | 192.168.2.122 (Pi-hole) |
| Bereich Start | 192.168.2.30 |
| Bereich Ende | 192.168.2.119 |
| Gateway | 192.168.2.1 |
| DNS-Server | 192.168.2.122 |
| Lease-Zeit | 24 Stunden |
| Domain | .home |

### Lokale DNS-Einträge

In Pi-hole unter `/etc/pihole/custom.list`:

```
192.168.2.120 proxmox.home
192.168.2.121 nas.home
192.168.2.122 pihole.home
192.168.2.123 vpn.home
192.168.2.124 vault.home
192.168.2.125 proxy.home
192.168.2.126 jellyfin.home
```

---

## Storage-Konfiguration

### Disk-Layout (System-NVMe)

```
/dev/nvme0n1 (500 GB NVMe)
├── nvme0n1p1    1007K   BIOS boot
├── nvme0n1p2    1G      /boot/efi (FAT32)
└── nvme0n1p3    464G    LVM (pve)
    ├── pve-swap     8G      [SWAP]
    ├── pve-root    96G      / (ext4)
    └── pve-data   337G      LVM-Thin Pool
        ├── vm-100-disk-0  15G   NAS rootfs
        ├── vm-101-disk-0   8G   Pi-hole rootfs
        ├── vm-102-disk-0   8G   WireGuard rootfs
        ├── vm-103-disk-0   8G   Vaultwarden rootfs
        ├── vm-104-disk-0   8G   Nginx rootfs
        └── vm-105-disk-0  10G   Jellyfin rootfs
```

### Storage-SSD Mount

```bash
# UUID ermitteln
blkid /dev/sda

# /etc/fstab Eintrag
UUID=<DEINE-UUID> /mnt/storage ext4 defaults,noatime,nofail 0 2
```

### Ordnerstruktur

```
/mnt/storage/
├── shared/           # Samba: Allgemeine Dateien
│   └── .recycle/     # Papierkorb (pro Benutzer)
├── media/            # Samba + Jellyfin
│   ├── movies/       # Filme
│   ├── music/        # Musik
│   └── photos/       # Fotos
└── backups/          # Samba: Geräte-Backups
```

### Berechtigungen für unprivileged Container

```bash
# NAS-Freigaben
chown -R 100000:100000 /mnt/storage/shared
chown -R 100000:100000 /mnt/storage/backups
chmod -R 2770 /mnt/storage/shared
chmod -R 2770 /mnt/storage/backups

# Media (Jellyfin)
chown -R 101000:101000 /mnt/storage/media
chmod -R 755 /mnt/storage/media
```

---

## Container-Konfigurationen

### CT 100 - NAS (Samba)

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: nas
memory: 1024
mp0: /mnt/storage/shared,mp=/srv/shared
mp1: /mnt/storage/media,mp=/srv/media
mp2: /mnt/storage/backups,mp=/srv/backups
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,hwaddr=BC:24:11:90:E2:A7,ip=192.168.2.121/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-100-disk-0,size=15G
swap: 1024
unprivileged: 1
```

### CT 101 - Pi-hole

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: pi-hole
memory: 1024
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,hwaddr=BC:24:11:44:B6:42,ip=192.168.2.122/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-101-disk-0,size=8G
swap: 1024
unprivileged: 1
```

### CT 102 - WireGuard

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: wireguard
memory: 1024
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,hwaddr=BC:24:11:7B:30:3F,ip=192.168.2.123/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-102-disk-0,size=8G
swap: 1024
unprivileged: 1
```

### CT 103 - Vaultwarden

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: vaultwarden
memory: 2048
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,hwaddr=BC:24:11:C6:9B:7C,ip=192.168.2.124/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-103-disk-0,size=8G
swap: 2048
unprivileged: 1
```

### CT 104 - Nginx Proxy Manager

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: nginx-proxy
memory: 1024
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,hwaddr=BC:24:11:F6:DB:42,ip=192.168.2.125/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-104-disk-0,size=8G
swap: 1024
unprivileged: 1
```

### CT 105 - Jellyfin

```ini
arch: amd64
cores: 2
features: nesting=1
hostname: jellyfin
memory: 2048
mp0: /mnt/storage/media,mp=/media
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,ip=192.168.2.126/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-105-disk-0,size=10G
swap: 2048
unprivileged: 1
```

---

## Firewall-Regeln

### Übersicht

| Container | Port | Protokoll | Quelle | Beschreibung |
|-----------|------|-----------|--------|--------------|
| Host | 8006 | TCP | LAN | Proxmox Web-UI |
| Host | 22 | TCP | LAN | SSH |
| CT 100 | 445 | TCP | LAN | Samba/SMB |
| CT 101 | 53 | TCP/UDP | LAN | DNS |
| CT 101 | 80 | TCP | LAN | Pi-hole Web |
| CT 101 | 67 | UDP | Alle | DHCP |
| CT 102 | 51820 | UDP | **Extern** | WireGuard VPN |
| CT 102 | 51821 | TCP | LAN | WG-Easy Web |
| CT 103 | 8081 | TCP | Nginx | Vaultwarden |
| CT 104 | 80, 443 | TCP | **Extern** | HTTP/HTTPS |
| CT 104 | 81 | TCP | LAN | NPM Admin |
| CT 105 | 8096 | TCP | LAN | Jellyfin |

---

## Dienste und Zugangsdaten

> ⚠️ **WICHTIG:** Trage deine echten Passwörter ein!

| Dienst | URL | Benutzer | Passwort |
|--------|-----|----------|----------|
| Proxmox | https://192.168.2.120:8006 | root@pam | `_________` |
| Pi-hole | http://192.168.2.122/admin | - | `_________` |
| NAS | `\\192.168.2.121\shared` | homeserver | `_________` |
| WireGuard | http://192.168.2.123:51821 | - | `_________` |
| Vaultwarden | https://vault-rxfsys.duckdns.org | - | Admin-Token: `_________` |
| Nginx PM | http://192.168.2.125:81 | - | `_________` |
| Jellyfin | http://192.168.2.126:8096 | - | `_________` |

---

## DuckDNS Konfiguration

| Domain | Verwendung |
|--------|------------|
| rxfsys.duckdns.org | WireGuard VPN |
| vault-rxfsys.duckdns.org | Vaultwarden |

**Token:** `___________________`

### IP-Update Cronjob

```bash
*/5 * * * * curl -s "https://www.duckdns.org/update?domains=rxfsys,vault-rxfsys&token=DEIN_TOKEN&ip=" > /dev/null
```

---

## Backup-Strategie

### Kritische Backup-Ziele

| Dienst | Pfad | Priorität |
|--------|------|-----------|
| Vaultwarden DB | `/srv/appdata/vaultwarden/db.sqlite3` | 🔴 Kritisch |
| WireGuard Keys | `/srv/appdata/wireguard/` | 🔴 Kritisch |
| Pi-hole Config | `/etc/pihole/` | 🟡 Wichtig |
| Nginx Certs | `/srv/appdata/nginx-proxy/letsencrypt/` | 🟡 Wichtig |

### Container-Backup

```bash
# Einzeln
vzdump 100 --storage local --compress zstd --mode snapshot

# Alle
for i in $(pct list | awk 'NR>1 {print $1}'); do
  vzdump $i --storage local --compress zstd --mode snapshot
done
```

---

## Wartungsprozeduren

### Updates

```bash
# Host
apt update && apt full-upgrade -y

# Alle Container
for i in $(pct list | awk 'NR>1 {print $1}'); do
  pct exec $i -- apt update && pct exec $i -- apt upgrade -y
done

# Docker-Images (CT 102, 103, 104)
pct exec 102 -- bash -c 'cd /srv/appdata/wireguard && docker compose pull && docker compose up -d'
```

### Health-Checks

```bash
# SMART
smartctl -H /dev/sda && smartctl -H /dev/nvme0n1

# Logs
journalctl -p err -b

# Container-Status
pct list
```

---

*Dokumentation für Server rxfsys | Januar 2026*
