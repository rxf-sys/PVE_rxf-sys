# Home-Server Dokumentation

**Server:** rxfsys  
**Erstellt:** 2025-01-26  
**Proxmox Version:** 9.1.1  
**Kernel:** Linux 6.17.2-1-pve  

---

## Inhaltsverzeichnis

1. [Hardware-Übersicht](#hardware-übersicht)
2. [Netzwerk-Konfiguration](#netzwerk-konfiguration)
3. [Storage-Konfiguration](#storage-konfiguration)
4. [Container-Übersicht](#container-übersicht)
5. [Dienste und Zugangsdaten](#dienste-und-zugangsdaten)
6. [Wichtige Befehle](#wichtige-befehle)
7. [Backup-Strategie](#backup-strategie)
8. [Wartung und Updates](#wartung-und-updates)
9. [Troubleshooting](#troubleshooting)

---

## Hardware-Übersicht

| Komponente | Spezifikation |
|------------|---------------|
| **CPU** | Intel Core i5-9500T @ 2.20GHz (6 Cores) |
| **RAM** | 32 GB DDR4 |
| **System-Disk** | 500 GB NVMe SSD (`/dev/nvme0n1`) |
| **Storage-Disk** | 500 GB SATA SSD (`/dev/sda`) → `/mnt/storage` |
| **Backup-Disk** | 500 GB SSD (noch nicht eingebunden) |
| **Boot-Mode** | EFI (Secure Boot) |

### Ressourcen-Auslastung (Richtwerte)

```
Gesamt RAM:     32 GB
Zugewiesen:     ~6.5 GB (Container)
Verfügbar:      ~25 GB

Gesamt Storage: ~465 GB (NVMe) + 465 GB (Storage-SSD)
LVM-Thin Pool:  337 GB (für Container-Disks)
Genutzt:        ~10 GB
```

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

### IP-Adressen der Dienste

| Dienst | Container | IP-Adresse | Port(s) |
|--------|-----------|------------|---------|
| **Proxmox Web-UI** | Host | 192.168.2.120 | 8006 (HTTPS) |
| **NAS (Samba)** | CT 100 | DHCP (TODO: statisch) | 445 |
| **Pi-hole** | CT 101 | 192.168.2.122 | 80 (Web), 53 (DNS) |
| **WireGuard** | CT 102 | DHCP (TODO: statisch) | 51820/UDP |
| **Vaultwarden** | CT 103 | DHCP (TODO: statisch) | 80/443 |
| **Nginx-Proxy** | CT 104 | DHCP (TODO: statisch) | 80, 443 |

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
    ├── pve-swap     8G      [SWAP]
    ├── pve-root     96G     / (ext4)
    └── pve-data     337G    LVM-Thin Pool

/dev/sda (500 GB SATA SSD - Storage)
└── sda          458G    /mnt/storage (ext4)
```

### fstab-Eintrag prüfen

```bash
# Aktuellen Mount prüfen
cat /etc/fstab | grep storage

# Falls nicht vorhanden, UUID ermitteln und eintragen:
blkid /dev/sda
# Dann in /etc/fstab:
# UUID=DEINE-UUID /mnt/storage ext4 defaults,noatime 0 2
```

### Ordnerstruktur (empfohlen)

```
/mnt/storage/
├── shared/       # Samba-Freigaben (NAS)
├── media/        # Filme, Musik, Fotos (Jellyfin)
├── backups/      # Daten-Backups
└── appdata/      # Container-Anwendungsdaten
```

---

## Container-Übersicht

### Alle Container

| VMID | Name | Status | OS | RAM | CPU | Disk | IP |
|------|------|--------|-----|-----|-----|------|-----|
| 100 | nas | running | Debian | 1024 MB | 1 | 15 GB + 8 GB | DHCP |
| 101 | pi-hole | running | Debian | 1024 MB | 1 | 8 GB | 192.168.2.122 |
| 102 | wireguard | running | Debian | 1024 MB | 1 | 8 GB | DHCP |
| 103 | vaultwarden | running | Debian | 2048 MB | 1 | 8 GB | DHCP |
| 104 | nginx-proxy | running | Debian | 1024 MB | 1 | 8 GB | DHCP |

### Detaillierte Container-Konfigurationen

#### CT 100 - NAS (Samba)

```ini
# /etc/pve/lxc/100.conf
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

**Hinweis:** Mountpoint zeigt auf LVM (8GB), nicht auf Storage-SSD!

**TODO:** Ändern zu:
```ini
mp0: /mnt/storage/shared,mp=/srv/shared,backup=0
```

#### CT 101 - Pi-hole

```ini
# /etc/pve/lxc/101.conf
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

**Web-UI:** http://192.168.2.122/admin

#### CT 102 - WireGuard

```ini
# /etc/pve/lxc/102.conf
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

**TODO:** Statische IP vergeben, Port 51820/UDP im Router freigeben

#### CT 103 - Vaultwarden

```ini
# /etc/pve/lxc/103.conf
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

**Wichtig:** Benötigt HTTPS! Über Nginx-Proxy oder direkt konfigurieren.

#### CT 104 - Nginx-Proxy

```ini
# /etc/pve/lxc/104.conf
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

### Proxmox VE

| Parameter | Wert |
|-----------|------|
| **URL** | https://192.168.2.120:8006 |
| **Benutzer** | root@pam |
| **Passwort** | [HIER EINTRAGEN] |

### Pi-hole

| Parameter | Wert |
|-----------|------|
| **URL** | http://192.168.2.122/admin |
| **Passwort** | [HIER EINTRAGEN] |
| **DNS-Port** | 53 |

### Samba/NAS

| Parameter | Wert |
|-----------|------|
| **Zugriff** | `\\[NAS-IP]\shared` |
| **Benutzer** | [HIER EINTRAGEN] |
| **Passwort** | [HIER EINTRAGEN] |

### WireGuard VPN

| Parameter | Wert |
|-----------|------|
| **Server-Port** | 51820/UDP |
| **Web-UI (wg-easy)** | http://[WIREGUARD-IP]:51821 |
| **Passwort** | [HIER EINTRAGEN] |

### Vaultwarden

| Parameter | Wert |
|-----------|------|
| **URL** | https://[VAULTWARDEN-IP] (via Nginx) |
| **Admin-Token** | [HIER EINTRAGEN] |

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
for i in $(pct list | awk 'NR>1 {print $1}'); do echo "=== CT $i ==="; pct config $i; done

# Storage-Status
pvesm status
df -h
lsblk

# Festplatten-Gesundheit
smartctl -a /dev/sda
smartctl -a /dev/nvme0n1

# Netzwerk-Status
ip addr
cat /etc/network/interfaces

# Logs
journalctl -xe
tail -f /var/log/syslog

# Proxmox-Dienste neustarten
systemctl restart pvedaemon pveproxy
```

### Container-Verwaltung

```bash
# Backup eines Containers erstellen
vzdump 100 --storage local --mode snapshot

# Container aus Backup wiederherstellen
pct restore 100 /var/lib/vz/dump/vzdump-lxc-100-*.tar.zst

# Mountpoint hinzufügen (Container muss gestoppt sein)
pct set 100 -mp0 /mnt/storage/shared,mp=/srv/shared

# Ressourcen ändern
pct set 100 -memory 2048
pct set 100 -cores 2

# Statische IP setzen
pct set 100 -net0 name=eth0,bridge=vmbr0,ip=192.168.2.130/24,gw=192.168.2.1
```

### In den Containern

```bash
# Updates (Debian/Ubuntu)
apt update && apt upgrade -y

# Dienst-Status prüfen
systemctl status <dienst>

# Logs eines Dienstes
journalctl -u <dienst> -f

# Netzwerk testen
ip addr
ping 192.168.2.1
ping 8.8.8.8
```

---

## Backup-Strategie

### Aktuelle Situation

- ❌ Backup-SSD noch nicht eingebunden
- ❌ Kein automatischer Backup-Schedule
- ⚠️ Keine Offsite-Backups

### Empfohlene Konfiguration

#### 1. Backup-SSD einbinden

```bash
# SSD identifizieren
lsblk

# Formatieren (ACHTUNG: Löscht alle Daten!)
mkfs.ext4 -L backups /dev/sdX

# Mountpoint erstellen
mkdir -p /mnt/backups

# UUID ermitteln
blkid /dev/sdX

# In fstab eintragen
echo 'UUID=DEINE-UUID /mnt/backups ext4 defaults,noatime 0 2' >> /etc/fstab

# Mounten
mount -a
```

#### 2. Backup-Storage in Proxmox anlegen

Datacenter → Storage → Add → Directory:
- **ID:** backup-local
- **Directory:** /mnt/backups
- **Content:** VZDump backup file

#### 3. Backup-Schedule einrichten

Datacenter → Backup → Add:
- **Storage:** backup-local
- **Schedule:** Täglich 03:00
- **Selection mode:** All
- **Mode:** Snapshot
- **Compression:** ZSTD
- **Retention:** keep-last=7, keep-weekly=4

### 3-2-1 Regel

| Kopie | Medium | Ort |
|-------|--------|-----|
| 1 (Original) | Storage-SSD | Server |
| 2 (Backup) | Backup-SSD | Server |
| 3 (Offsite) | Cloud/externe HDD | Außer Haus |

---

## Wartung und Updates

### Monatliche Routine

1. **Proxmox-Host updaten**
   ```bash
   apt update && apt full-upgrade -y
   ```

2. **Container updaten**
   ```bash
   for i in $(pct list | awk 'NR>1 {print $1}'); do
     echo "Updating CT $i..."
     pct exec $i -- apt update
     pct exec $i -- apt upgrade -y
   done
   ```

3. **Festplatten-Gesundheit prüfen**
   ```bash
   smartctl -H /dev/sda
   smartctl -H /dev/nvme0n1
   ```

4. **Backup-Integrität prüfen**
   - Stichprobenartig Restore testen

5. **Logs auf Fehler prüfen**
   ```bash
   journalctl -p err -b
   ```

### Vor größeren Updates

1. Snapshot/Backup aller Container erstellen
2. Proxmox Release Notes lesen
3. Update durchführen
4. Funktionstest aller Dienste

---

## Troubleshooting

### Proxmox Web-UI nicht erreichbar

```bash
# Auf Host prüfen:
ping 192.168.2.120
systemctl status pveproxy
journalctl -u pveproxy

# Firewall prüfen
iptables -L -n
```

### Container startet nicht

```bash
# Logs prüfen
pct start 100
journalctl -xe

# Config prüfen
pct config 100

# Manuell starten mit Debug
lxc-start -n 100 -F -l DEBUG
```

### Mountpoint Permission Denied

Bei unprivileged Containern werden UIDs/GIDs gemappt (100000+).

```bash
# Auf Host: Berechtigungen für Container setzen
chown -R 100000:100000 /mnt/storage/shared

# Oder im Container passende User anlegen
```

### Netzwerk-Probleme im Container

```bash
# Im Container:
ip addr
ip route
cat /etc/resolv.conf

# DNS testen
ping 8.8.8.8
nslookup google.com
```

### Storage voll

```bash
# Speicherverbrauch analysieren
df -h
du -sh /var/lib/vz/*
lvs

# Alte Backups löschen
ls -la /var/lib/vz/dump/

# LVM-Thin-Pool prüfen
lvs -a | grep pve-data
```

---

## Anhang

### Nützliche Links

- Proxmox Wiki: https://pve.proxmox.com/wiki/
- Proxmox Forum: https://forum.proxmox.com/
- Pi-hole Docs: https://docs.pi-hole.net/
- Vaultwarden Wiki: https://github.com/dani-garcia/vaultwarden/wiki
- WireGuard Docs: https://www.wireguard.com/quickstart/

### Änderungshistorie

| Datum | Änderung |
|-------|----------|
| 2025-01-26 | Initiale Dokumentation erstellt |

---

*Dokumentation generiert am 2025-01-26 für Server rxfsys*
