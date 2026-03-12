# CT 105 - Jellyfin (Media Server)

## Übersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 105 |
| **Hostname** | jellyfin |
| **IP-Adresse** | 192.168.2.126 |
| **RAM** | 8192 MB |
| **CPU** | 4 Cores |
| **Disk** | 32 GB |
| **OS** | Debian Trixie |
| **Dienst** | Jellyfin |

---

## Funktion

Jellyfin ist ein selbst-gehosteter Media Server für Filme, Serien, Musik und Fotos. Er ermöglicht Streaming auf verschiedene Geräte im Netzwerk.

---

## Zugriff

| Dienst | URL |
|--------|-----|
| Web-Interface | http://192.168.2.126:8096 |
| Mit lokalem DNS | http://jellyfin.home:8096 |

### Zugangsdaten

| Parameter | Wert |
|-----------|------|
| Admin-Benutzer | `___________________` |
| Passwort | `___________________` |

---

## Container-Konfiguration

**Datei:** `/etc/pve/lxc/105.conf`

```ini
arch: amd64
cores: 4
features: nesting=1
hostname: jellyfin
memory: 8192
mp0: /mnt/storage/media,mp=/media
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,ip=192.168.2.126/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-105-disk-0,size=32G
swap: 2048
unprivileged: 1
```

---

## Media-Mount

| Host-Pfad | Container-Pfad | Beschreibung |
|-----------|----------------|--------------|
| /mnt/storage/media | /media | Alle Medien |

### Ordnerstruktur

```
/media/
├── movies/       # Filme (aktuell: 3)
├── music/        # Musik
└── photos/       # Fotos
```

### Berechtigungen

```bash
# Auf dem Proxmox-Host:
chown -R 101000:101000 /mnt/storage/media/
chmod -R 755 /mnt/storage/media/
```

**Hinweis:** Bei unprivileged Containern werden UIDs um 100000 verschoben. UID 1000 im Container = UID 101000 auf dem Host.

---

## Bibliotheken einrichten

### In Jellyfin Web-UI:

1. **Dashboard** → **Libraries** → **Add Media Library**

2. **Filme:**
   - Content type: Movies
   - Folders: `/media/movies`

3. **Musik:**
   - Content type: Music
   - Folders: `/media/music`

4. **Fotos:**
   - Content type: Photos
   - Folders: `/media/photos`

---

## Clients

### Web-Browser

Einfach `http://jellyfin.home:8096` öffnen.

### Mobile Apps

| Plattform | App |
|-----------|-----|
| iOS | Jellyfin (App Store) |
| Android | Jellyfin (Play Store) |
| Android TV | Jellyfin (Play Store) |

### Desktop & Smart TV

| Gerät | App |
|-------|-----|
| Windows/macOS/Linux | Jellyfin Media Player |
| Amazon Fire TV | Jellyfin |
| Samsung TV | Jellyfin (Tizen) |
| LG TV | Jellyfin (webOS) |
| Kodi | Jellyfin Add-on |

---

## Hardware-Beschleunigung (optional)

### Intel Quick Sync (i5-9500T)

```bash
# Container stoppen
pct stop 105

# GPU durchreichen
pct set 105 --dev0 /dev/dri/renderD128,gid=44

# Container starten
pct start 105

# Prüfen
pct exec 105 -- ls -la /dev/dri/
```

### In Jellyfin aktivieren:

1. Dashboard → Playback → Transcoding
2. Hardware acceleration: **Intel QuickSync (QSV)**
3. Aktivieren: H.264, HEVC, etc.
4. Save

---

## Verwaltung

```bash
# Status prüfen
pct exec 105 -- systemctl status jellyfin

# Neustarten
pct exec 105 -- systemctl restart jellyfin

# Logs prüfen
pct exec 105 -- journalctl -u jellyfin -n 50

# Bibliothek neu scannen (via API)
pct exec 105 -- curl -X POST "http://localhost:8096/Library/Refresh" -H "X-Emby-Token: DEIN_API_KEY"
```

---

## Firewall

**Datei:** `/etc/pve/firewall/105.fw`

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Jellyfin Web (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 8096 -log nolog

# HTTPS (falls konfiguriert)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 8920 -log nolog

# Service Discovery (DLNA)
IN ACCEPT -source 192.168.2.0/24 -p udp -dport 1900 -log nolog
IN ACCEPT -source 192.168.2.0/24 -p udp -dport 7359 -log nolog

# ICMP/Ping
IN ACCEPT -p icmp
```

---

## Externer Zugriff

### Option A: Via VPN (empfohlen)

Mit WireGuard verbinden → Jellyfin ist unter `192.168.2.126:8096` erreichbar.

### Option B: Via Nginx Proxy Manager

1. Neue DuckDNS-Subdomain erstellen (z.B. `media-rxfsys.duckdns.org`)
2. In Nginx PM neuen Proxy Host erstellen:
   - Domain: `media-rxfsys.duckdns.org`
   - Forward: `192.168.2.126:8096`
   - SSL aktivieren

---

## Troubleshooting

### Medien werden nicht gefunden

```bash
# Mount prüfen
pct exec 105 -- df -h /media
pct exec 105 -- ls -la /media/

# Berechtigungen prüfen (auf Host)
ls -la /mnt/storage/media/
# Muss 101000:101000 sein
```

### Transcoding funktioniert nicht

```bash
# Hardware-Zugriff prüfen
pct exec 105 -- ls -la /dev/dri/

# Software-Transcoding als Fallback testen
```

### Web-UI nicht erreichbar

```bash
pct exec 105 -- systemctl status jellyfin
pct exec 105 -- ss -tlnp | grep 8096
pct exec 105 -- systemctl restart jellyfin
```

---

## Backup

### Wichtige Verzeichnisse

| Pfad | Beschreibung |
|------|--------------|
| `/var/lib/jellyfin/` | Konfiguration + Datenbank |
| `/var/lib/jellyfin/data/` | Metadaten, Bilder |
| `/var/lib/jellyfin/config/` | Einstellungen |

### Container-Backup

```bash
vzdump 105 --storage local --compress zstd --mode snapshot
```

---

## Performance-Tipps

1. **RAM:** 8 GB zugewiesen - ausreichend für große Bibliotheken
2. **Hardware-Transcoding:** Intel QuickSync aktivieren
3. **SSD für Metadaten:** Container auf LVM-Thin
4. **Netzwerk:** Gigabit-Ethernet für 4K-Streaming

---

*CT 105 - Jellyfin | Server rxfsys*