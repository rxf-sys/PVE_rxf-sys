# Home-Server Dokumentation

**Server:** rxfsys  
**Erstellt:** 2025-01-26  
**Zuletzt aktualisiert:** 2025-01-26  
**Proxmox Version:** 9.1.1  
**Kernel:** Linux 6.17.2-1-pve (EFI Secure Boot)  

---

## Inhaltsverzeichnis

1. [Quick Reference](#quick-reference)
2. [Hardware-Übersicht](#hardware-übersicht)
3. [Netzwerk-Konfiguration](#netzwerk-konfiguration)
4. [Storage-Konfiguration](#storage-konfiguration)
5. [Container-Übersicht](#container-übersicht)
6. [Dienste und Zugangsdaten](#dienste-und-zugangsdaten)
7. [Firewall-Konfiguration](#firewall-konfiguration)
8. [SMART-Monitoring](#smart-monitoring)
9. [Backup-Strategie](#backup-strategie)
10. [Wichtige Befehle](#wichtige-befehle)
11. [Wartung und Updates](#wartung-und-updates)
12. [Troubleshooting](#troubleshooting)

---

## Quick Reference

```
┌─────────────────────────────────────────────────────────────┐
│  PROXMOX HOST        https://192.168.2.120:8006            │
│                      SSH: root@192.168.2.120               │
├─────────────────────────────────────────────────────────────┤
│  CT 100 - NAS          192.168.2.121   Samba :445          │
│  CT 101 - Pi-hole      192.168.2.122   DNS :53, Web :80    │
│  CT 102 - WireGuard    192.168.2.123   VPN :51820          │
│  CT 103 - Vaultwarden  192.168.2.124   (via Nginx)         │
│  CT 104 - Nginx-Proxy  192.168.2.125   Web :80/:443/:81    │
├─────────────────────────────────────────────────────────────┤
│  Storage-SSD           /mnt/storage    458 GB              │
│  Backup-SSD            /mnt/backups    (einrichten!)       │
└─────────────────────────────────────────────────────────────┘
```

### Wichtige URLs

| Dienst | URL |
|--------|-----|
| Proxmox | https://192.168.2.120:8006 |
| Pi-hole | http://192.168.2.122/admin |
| WireGuard (wg-easy) | http://192.168.2.123:51821 |
| Nginx Proxy Manager | http://192.168.2.125:81 |
| NAS (Windows) | `\\192.168.2.121\shared` |

---

## Hardware-Übersicht

| Komponente | Spezifikation |
|------------|---------------|
| **CPU** | Intel Core i5-9500T @ 2.20GHz (6 Cores) |
| **RAM** | 32 GB DDR4 |
| **System-Disk** | Kingston SA2000M8 500GB NVMe (`/dev/nvme0n1`) |
| **Storage-Disk** | Samsung SSD 860 EVO 500GB (`/dev/sda`) → `/mnt/storage` |
| **Backup-Disk** | 500 GB SSD (noch nicht eingebunden) |
| **Boot-Mode** | EFI (Secure Boot) |

### Ressourcen-Auslastung

```
RAM:
  Gesamt:     32 GB
  Zugewiesen: ~6.5 GB (Container)
  Verfügbar:  ~25 GB

Storage:
  NVMe (System):     465 GB
  LVM-Thin Pool:     337 GB (für Container-Disks)
  Storage-SSD:       458 GB (/mnt/storage)
  Genutzt (LVM):     ~10 GB
```

### SMART-Status

| Disk | Modell | Status |
|------|--------|--------|
| `/dev/sda` | Samsung SSD 860 EVO 500GB | ✅ PASSED |
| `/dev/nvme0n1` | Kingston SA2000M8 500GB | ✅ PASSED |

---

## Netzwerk-Konfiguration

### Host-Netzwerk

| Parameter | Wert |
|-----------|------|
| **Interface** | `vmbr0` (Bridge) |
| **Host-IP** | `192.168.2.120/24` |
| **Gateway** | `192.168.2.1` |
| **Physical NIC** | `nic0` |

### Konfigurationsdatei

**Pfad:** `/etc/network/interfaces`

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

iface nic1 inet manual

source /etc/network/interfaces.d/*
```

### IP-Adressen aller Dienste

| Dienst | Container | IPv4 | IPv6 (SLAAC) | Ports |
|--------|-----------|------|--------------|-------|
| **Proxmox** | Host | 192.168.2.120 | - | 8006, 22 |
| **NAS** | CT 100 | 192.168.2.121 | 2003:e7:4f3f:c63f:be24:11ff:fe90:e2a7 | 445, 139 |
| **Pi-hole** | CT 101 | 192.168.2.122 | 2003:e7:4f3f:c63f:be24:11ff:fe44:b642 | 53, 80 |
| **WireGuard** | CT 102 | 192.168.2.123 | 2003:e7:4f3f:c63f:be24:11ff:fe7b:303f | 51820, 51821 |
| **Vaultwarden** | CT 103 | 192.168.2.124 | 2003:e7:4f3f:c63f:be24:11ff:fec6:9b7c | 80, 3012 |
| **Nginx-Proxy** | CT 104 | 192.168.2.125 | 2003:e7:4f3f:c63f:be24:11ff:fef6:db42 | 80, 443, 81 |

### Docker-Netzwerke in Containern

Einige Container haben zusätzliche Docker-Bridge-Netzwerke:

| Container | Zusätzliche IPs |
|-----------|-----------------|
| CT 102 (WireGuard) | 172.17.0.1, 172.18.0.1, 10.8.1.1 (WG-Tunnel) |
| CT 103 (Vaultwarden) | 172.17.0.1, 172.18.0.1 |
| CT 104 (Nginx-Proxy) | 172.17.0.1, 172.18.0.1 |

---

## Storage-Konfiguration

### Übersicht

| Storage | Typ | Mountpoint | Größe | Verwendung |
|---------|-----|------------|-------|------------|
| `local` | Directory | `/var/lib/vz` | 94 GB | ISOs, Templates, Backups |
| `local-lvm` | LVM-Thin | - | 337 GB | Container-Disks |
| Storage-SSD | ext4 | `/mnt/storage` | 458 GB | Daten, Medien, Shares |

### Disk-Layout

```
/dev/nvme0n1 (500 GB NVMe - System)
├── nvme0n1p1    1007K   BIOS boot
├── nvme0n1p2    1G      /boot/efi (FAT32)
└── nvme0n1p3    464G    LVM (pve)
    ├── pve-swap           8G    [SWAP]
    ├── pve-root          96G    / (ext4)
    └── pve-data         337G    LVM-Thin Pool
        ├── vm-100-disk-0  15G   CT 100 rootfs
        ├── vm-100-disk-1   8G   CT 100 mp0 (alt, nicht mehr genutzt)
        ├── vm-101-disk-0   8G   CT 101 rootfs
        ├── vm-102-disk-0   8G   CT 102 rootfs
        ├── vm-103-disk-0   8G   CT 103 rootfs
        └── vm-104-disk-0   8G   CT 104 rootfs

/dev/sda (500 GB SATA SSD - Storage)
└── sda              458G    /mnt/storage (ext4)
```

### fstab-Eintrag

**Pfad:** `/etc/fstab`

```bash
# Storage-SSD (Prüfen ob vorhanden!)
UUID=DEINE-UUID /mnt/storage ext4 defaults,noatime,nofail 0 2
```

**Prüfen:**
```bash
grep storage /etc/fstab
```

### Ordnerstruktur (empfohlen)

```
/mnt/storage/
├── shared/       # Samba-Freigaben (NAS) → CT 100
├── media/        # Filme, Musik, Fotos (Jellyfin)
├── backups/      # Daten-Backups
└── appdata/      # Container-Anwendungsdaten
```

---

## Container-Übersicht

### Alle Container

| VMID | Name | Status | OS | RAM | CPU | Disk | IP |
|------|------|--------|-----|-----|-----|------|-----|
| 100 | nas | ✅ running | Debian | 1024 MB | 1 | 15 GB | 192.168.2.121 |
| 101 | pi-hole | ✅ running | Debian | 1024 MB | 1 | 8 GB | 192.168.2.122 |
| 102 | wireguard | ✅ running | Debian | 1024 MB | 1 | 8 GB | 192.168.2.123 |
| 103 | vaultwarden | ✅ running | Debian | 2048 MB | 1 | 8 GB | 192.168.2.124 |
| 104 | nginx-proxy | ✅ running | Debian | 1024 MB | 1 | 8 GB | 192.168.2.125 |

### Detailkonfigurationen

#### CT 100 - NAS (Samba)

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: nas
memory: 1024
mp0: local-lvm:vm-100-disk-1,mp=/srv/shared,backup=1,size=8G
net0: name=eth0,bridge=vmbr0,firewall=1,hwaddr=BC:24:11:90:E2:A7,ip=dhcp,type=veth
ostype: debian
rootfs: local-lvm:vm-100-disk-0,size=15G
swap: 1024
unprivileged: 1
```

**TODO:** Mountpoint ändern auf `/mnt/storage/shared` (siehe Anleitung)

#### CT 101 - Pi-hole

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: pi-hole
memory: 1024
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,hwaddr=BC:24:11:44:B6:42,ip=192.168.2.122/24,type=veth
ostype: debian
rootfs: local-lvm:vm-101-disk-0,size=8G
swap: 1024
unprivileged: 1
```

#### CT 102 - WireGuard

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: wireguard
memory: 1024
net0: name=eth0,bridge=vmbr0,firewall=1,hwaddr=BC:24:11:7B:30:3F,ip=dhcp,type=veth
ostype: debian
rootfs: local-lvm:vm-102-disk-0,size=8G
swap: 1024
unprivileged: 1
```

#### CT 103 - Vaultwarden

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: vaultwarden
memory: 2048
net0: name=eth0,bridge=vmbr0,firewall=1,hwaddr=BC:24:11:C6:9B:7C,ip=dhcp,type=veth
ostype: debian
rootfs: local-lvm:vm-103-disk-0,size=8G
swap: 2048
unprivileged: 1
```

#### CT 104 - Nginx-Proxy

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: nginx-proxy
memory: 1024
net0: name=eth0,bridge=vmbr0,firewall=1,hwaddr=BC:24:11:F6:DB:42,ip=dhcp,type=veth
ostype: debian
rootfs: local-lvm:vm-104-disk-0,size=8G
swap: 1024
unprivileged: 1
```

---

## Dienste und Zugangsdaten

> ⚠️ **WICHTIG:** Trage hier deine echten Passwörter ein und bewahre diese Datei sicher auf!

### Proxmox VE

| Parameter | Wert |
|-----------|------|
| **URL** | https://192.168.2.120:8006 |
| **Benutzer** | root@pam |
| **Passwort** | `___________________` |

### Pi-hole

| Parameter | Wert |
|-----------|------|
| **URL** | http://192.168.2.122/admin |
| **Passwort** | `___________________` |
| **DNS-Port** | 53 (TCP/UDP) |

### Samba/NAS

| Parameter | Wert |
|-----------|------|
| **Windows-Zugriff** | `\\192.168.2.121\shared` |
| **Linux-Zugriff** | `smb://192.168.2.121/shared` |
| **Benutzer** | `___________________` |
| **Passwort** | `___________________` |

### WireGuard VPN

| Parameter | Wert |
|-----------|------|
| **VPN-Port** | 51820/UDP |
| **Web-UI (wg-easy)** | http://192.168.2.123:51821 |
| **UI-Passwort** | `___________________` |
| **WG-Tunnel-Netz** | 10.8.1.0/24 |

### Vaultwarden

| Parameter | Wert |
|-----------|------|
| **URL** | https://vault.DEINE-DOMAIN (via Nginx) |
| **Direkt (intern)** | http://192.168.2.124 |
| **Admin-Token** | `___________________` |

### Nginx Proxy Manager

| Parameter | Wert |
|-----------|------|
| **Admin-URL** | http://192.168.2.125:81 |
| **E-Mail** | `___________________` |
| **Passwort** | `___________________` |

---

## Firewall-Konfiguration

### Status

| Ebene | Status |
|-------|--------|
| Datacenter | ⬜ Konfiguriert (aktivieren mit Script) |
| Container | ⬜ Konfiguriert (aktivieren mit Script) |

### Firewall-Regeln Übersicht

| Container | Port | Protokoll | Quelle | Beschreibung |
|-----------|------|-----------|--------|--------------|
| **Host** | 8006 | TCP | 192.168.2.0/24 | Proxmox Web-UI |
| **Host** | 22 | TCP | 192.168.2.0/24 | SSH |
| **CT 100** | 445 | TCP | 192.168.2.0/24 | Samba/SMB |
| **CT 100** | 139 | TCP | 192.168.2.0/24 | Samba/NetBIOS |
| **CT 100** | 137-138 | UDP | 192.168.2.0/24 | Samba/NetBIOS |
| **CT 101** | 53 | TCP/UDP | 192.168.2.0/24 | DNS |
| **CT 101** | 80 | TCP | 192.168.2.0/24 | Pi-hole Web |
| **CT 102** | 51820 | UDP | 0.0.0.0/0 | WireGuard VPN |
| **CT 102** | 51821 | TCP | 192.168.2.0/24 | WG-Easy Web-UI |
| **CT 103** | 80 | TCP | 192.168.2.125 | Vaultwarden (nur Nginx) |
| **CT 103** | 3012 | TCP | 192.168.2.125 | Vaultwarden Websocket |
| **CT 104** | 80 | TCP | 0.0.0.0/0 | HTTP |
| **CT 104** | 443 | TCP | 0.0.0.0/0 | HTTPS |
| **CT 104** | 81 | TCP | 192.168.2.0/24 | NPM Admin |

### Firewall aktivieren

```bash
# Script ausführen (siehe firewall-setup.sh)
bash /root/firewall-setup.sh

# Oder manuell:
pve-firewall restart
pve-firewall status
```

### Notfall: Firewall deaktivieren

```bash
pve-firewall stop
```

---

## SMART-Monitoring

### Status

| Dienst | Status |
|--------|--------|
| smartmontools | ✅ Installiert (7.4-pve1) |
| smartd | ✅ Aktiv (smartmontools.service) |

### Disks überwacht

| Disk | Modell | Seriennummer | Status |
|------|--------|--------------|--------|
| `/dev/sda` | Samsung SSD 860 EVO 500GB | S4CNNX0N806119L | ✅ PASSED |
| `/dev/nvme0n1` | Kingston SA2000M8 500GB | 50026B7683BC92D3 | ✅ PASSED |

### SMART-Befehle

```bash
# Gesundheitsstatus prüfen
smartctl -H /dev/sda
smartctl -H /dev/nvme0n1

# Vollständiger Report
smartctl -a /dev/sda
smartctl -a /dev/nvme0n1

# Dienst-Status
systemctl status smartmontools.service
```

---

## Backup-Strategie

### Aktueller Status

| Komponente | Status |
|------------|--------|
| Backup-SSD | ⬜ Noch nicht eingebunden |
| Backup-Schedule | ⬜ Noch nicht konfiguriert |
| Offsite-Backup | ⬜ Nicht vorhanden |

### TODO: Backup einrichten

1. Backup-SSD einbinden unter `/mnt/backups`
2. Proxmox Backup-Job erstellen (Datacenter → Backup)
3. Retention konfigurieren (keep-last=7, keep-weekly=4)

### 3-2-1 Regel (Ziel)

| Kopie | Medium | Ort | Status |
|-------|--------|-----|--------|
| Original | Storage-SSD | Server | ✅ |
| Backup 1 | Backup-SSD | Server | ⬜ |
| Backup 2 | Cloud/Extern | Außer Haus | ⬜ |

---

## Wichtige Befehle

### Proxmox / Host

```bash
# System-Updates
apt update && apt full-upgrade -y

# Container auflisten
pct list

# Container starten/stoppen/neustarten
pct start 100
pct stop 100
pct restart 100

# Container-Konsole öffnen
pct enter 100

# Container-Config anzeigen
pct config 100

# Alle Container-Configs
for i in $(pct list | awk 'NR>1 {print $1}'); do
  echo "=== CT $i ==="
  pct config $i
done

# Alle Container-IPs
for i in $(pct list | awk 'NR>1 {print $1}'); do
  echo -n "CT $i: "
  pct exec $i -- hostname -I 2>/dev/null || echo "nicht erreichbar"
done
```

### Storage

```bash
# Storage-Status
pvesm status
df -h
lsblk

# Speicherverbrauch
du -sh /var/lib/vz/*
lvs
```

### Netzwerk

```bash
# Netzwerk-Status
ip addr
cat /etc/network/interfaces

# Firewall
pve-firewall status
pve-firewall restart
```

### SMART / Festplatten

```bash
# Gesundheit prüfen
smartctl -H /dev/sda
smartctl -H /dev/nvme0n1

# Vollständiger Report
smartctl -a /dev/sda
```

### Backup

```bash
# Manuelles Backup eines Containers
vzdump 100 --storage local --compress zstd --mode snapshot

# Backup wiederherstellen
pct restore 999 /var/lib/vz/dump/vzdump-lxc-100-*.tar.zst --storage local-lvm
```

### Logs

```bash
# System-Logs
journalctl -xe
tail -f /var/log/syslog

# Fehler der letzten Boot-Session
journalctl -p err -b

# Proxmox-Dienste
systemctl status pvedaemon pveproxy
```

---

## Wartung und Updates

### Monatliche Routine

1. **Host updaten**
   ```bash
   apt update && apt full-upgrade -y
   ```

2. **Container updaten**
   ```bash
   for i in $(pct list | awk 'NR>1 {print $1}'); do
     echo "=== Updating CT $i ==="
     pct exec $i -- apt update
     pct exec $i -- apt upgrade -y
   done
   ```

3. **SMART prüfen**
   ```bash
   smartctl -H /dev/sda && smartctl -H /dev/nvme0n1
   ```

4. **Backup-Integrität prüfen**

5. **Logs auf Fehler prüfen**
   ```bash
   journalctl -p err -b
   ```

### Vor größeren Updates

1. Snapshot/Backup aller Container erstellen
2. Release Notes lesen
3. Update durchführen
4. Alle Dienste testen

---

## Troubleshooting

### Proxmox Web-UI nicht erreichbar

```bash
# Auf Host prüfen:
systemctl status pveproxy
journalctl -u pveproxy

# Firewall deaktivieren (falls aktiv)
pve-firewall stop
```

### Container startet nicht

```bash
# Logs prüfen
journalctl -xe

# Config prüfen
pct config 100

# Manuell mit Debug starten
lxc-start -n 100 -F -l DEBUG
```

### Mountpoint Permission Denied

```bash
# Bei unprivileged Containern: UIDs werden gemappt (100000+)
chown -R 100000:100000 /mnt/storage/shared
```

### Netzwerk-Probleme im Container

```bash
# Im Container:
ip addr
ip route
cat /etc/resolv.conf
ping 8.8.8.8
```

### Storage voll

```bash
df -h
du -sh /var/lib/vz/*
lvs -a | grep pve
```

---

## Anhang

### Nützliche Links

- Proxmox Wiki: https://pve.proxmox.com/wiki/
- Proxmox Forum: https://forum.proxmox.com/
- Pi-hole Docs: https://docs.pi-hole.net/
- Vaultwarden Wiki: https://github.com/dani-garcia/vaultwarden/wiki
- WireGuard: https://www.wireguard.com/

### Änderungshistorie

| Datum | Änderung |
|-------|----------|
| 2025-01-26 | Initiale Dokumentation |
| 2025-01-26 | IPs aktualisiert, SMART-Status hinzugefügt |
| 2025-01-26 | Firewall-Regeln dokumentiert |

---

*Dokumentation für Server rxfsys | Letzte Aktualisierung: 2025-01-26*
