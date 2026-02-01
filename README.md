# 🖥️ Home-Server rxfsys

> Proxmox VE Home-Server mit 11 LXC-Containern für NAS, DNS/DHCP, VPN, Passwort-Manager, Media-Server, Monitoring, Backup und Smart Home

---

## 📋 Schnellübersicht

| | |
|---|---|
| **Hostname** | rxfsys |
| **OS** | Proxmox VE 9.1.4 |
| **Kernel** | Linux 6.17.2-1-pve (EFI Secure Boot) |
| **CPU** | Intel Core i5-9500T (6 Cores @ 2.20GHz) |
| **RAM** | 32 GB DDR4 |
| **Storage** | 500GB NVMe (System) + 500GB SSD (Daten) + 480GB SSD (Backup/USB) |
| **Netzwerk** | 192.168.2.0/24 |

---

## 🌐 Netzwerk-Architektur

```
┌──────────────────────────────────────────────────────────────────────┐
│                    HEIMNETZWERK 192.168.2.0/24                       │
│                                                                      │
│   🌐 Router (Speedport Smart 4)                                      │
│   192.168.2.1  │  DHCP: Deaktiviert (Pi-hole übernimmt)              │
│                │                                                     │
│   ─────────────┴─────────────────────────────────────────────────    │
│                                                                      │
│   🖥️ PROXMOX HOST (rxfsys)                                           │
│   192.168.2.120  │  https://192.168.2.120:8006                       │
│                  │                                                   │
│   ┌──────────────┴────────────────────────────────────────────┐      │
│   │                    LXC CONTAINER                          │      │
│   ├───────────────────────────────────────────────────────────┤      │
│   │  📁 CT 100 - Samba         192.168.2.121  :445            │      │
│   │  🛡️ CT 101 - Pi-hole       192.168.2.122  :53/:80/:67     │      │
│   │  🔐 CT 102 - WireGuard     192.168.2.123  :51820/:51821   │      │
│   │  🔑 CT 103 - Vaultwarden   192.168.2.124  :8081           │      │
│   │  🌐 CT 104 - Nginx-Proxy   192.168.2.125  :80/:443/:81    │      │
│   │  🎬 CT 105 - Jellyfin      192.168.2.126  :8096           │      │
│   │  📊 CT 106 - Prometheus    192.168.2.127  :9090           │      │
│   │  📈 CT 107 - Grafana       192.168.2.128  :3000           │      │
│   │  💾 CT 108 - PBS           192.168.2.129  :8007           │      │
│   │  🏠 CT 109 - Home Assistant 192.168.2.130 :8123           │      │
│   │  📄 CT 110 - Paperless     192.168.2.131  :8000           │      │
│   └───────────────────────────────────────────────────────────┘      │
│                                                                      │
│   📊 IP-Bereiche:                                                    │
│   • Server (statisch): 192.168.2.120-131                             │
│   • Clients (DHCP):    192.168.2.30-119 (via Pi-hole)                │
│   • Reserviert:        192.168.2.2-29, 192.168.2.132-254             │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 🔗 Wichtige URLs

### Interne Dienste

| Dienst | URL | Beschreibung |
|--------|-----|--------------|
| **Proxmox** | https://192.168.2.120:8006 | Server-Verwaltung |
| **Pi-hole** | http://pihole.home/admin | DNS & Werbeblocker |
| **WireGuard** | http://vpn.home:51821 | VPN-Verwaltung |
| **Nginx PM** | http://proxy.home:81 | Reverse Proxy Admin |
| **Jellyfin** | http://jellyfin.home:8096 | Media Server |
| **Prometheus** | http://prometheus.home:9090 | Metriken |
| **Grafana** | http://grafana.home:3000 | Dashboards |
| **PBS** | https://pbs.home:8007 | Backup Server |
| **Home Assistant** | http://homeassistant.home:8123 | Smart Home |
| **Paperless** | http://paperless.home:8000 | Dokumentenverwaltung |
| **NAS (Windows)** | `\\samba.home\shared` | Dateifreigabe |
| **NAS (Mac/Linux)** | `smb://samba.home/shared` | Dateifreigabe |

### Externe Dienste (via DuckDNS)

| Dienst | URL | Beschreibung |
|--------|-----|--------------|
| **Vaultwarden** | https://vault-rxfsys.duckdns.org | Passwort-Manager |
| **WireGuard** | rxfsys.duckdns.org:51820 | VPN-Verbindung |

### Lokale DNS-Namen (.home)

| Name | IP | Dienst |
|------|-----|--------|
| proxmox.home / server.home | 192.168.2.120 | Proxmox Host |
| samba.home | 192.168.2.121 | Samba NAS |
| pihole.home / dns.home | 192.168.2.122 | Pi-hole DNS/DHCP |
| vpn.home / wireguard.home | 192.168.2.123 | WireGuard VPN |
| vault.home / vaultwarden.home | 192.168.2.124 | Vaultwarden |
| proxy.home / nginx.home | 192.168.2.125 | Nginx Proxy |
| jellyfin.home | 192.168.2.126 | Jellyfin Media |
| prometheus.home | 192.168.2.127 | Prometheus |
| grafana.home | 192.168.2.128 | Grafana |
| pbs.home | 192.168.2.129 | Proxmox Backup Server |
| homeassistant.home | 192.168.2.130 | Home Assistant |
| paperless.home | 192.168.2.131 | Paperless-ngx |

---

## 📦 Container-Übersicht

| ID | Name | IP | RAM | CPU | Disk | Funktion | Dokumentation |
|----|------|-----|-----|-----|------|----------|---------------|
| 100 | samba | .121 | 1 GB | 1 | 15 GB | Samba Dateiserver | [CT100-SAMBA.md](./container/CT100-SAMBA.md) |
| 101 | pi-hole | .122 | 2 GB | 2 | 8 GB | DNS + DHCP + Werbeblocker | [CT101-PIHOLE.md](./container/CT101-PIHOLE.md) |
| 102 | wireguard | .123 | 1 GB | 1 | 8 GB | VPN Server (wg-easy) | [CT102-WIREGUARD.md](./container/CT102-WIREGUARD.md) |
| 103 | vaultwarden | .124 | 2 GB | 1 | 8 GB | Passwort-Manager | [CT103-VAULTWARDEN.md](./container/CT103-VAULTWARDEN.md) |
| 104 | nginx-proxy | .125 | 1 GB | 1 | 8 GB | Reverse Proxy + SSL | [CT104-NGINX.md](./container/CT104-NGINX.md) |
| 105 | jellyfin | .126 | 8 GB | 4 | 32 GB | Media Server | [CT105-JELLYFIN.md](./container/CT105-JELLYFIN.md) |
| 106 | prometheus | .127 | 2 GB | 2 | 15 GB | Metriken-Sammlung | [CT106-PROMETHEUS.md](./container/CT106-PROMETHEUS.md) |
| 107 | grafana | .128 | 1 GB | 1 | 8 GB | Monitoring-Dashboards | [CT107-GRAFANA.md](./container/CT107-GRAFANA.md) |
| 108 | pbs | .129 | 2 GB | 2 | 20 GB | Proxmox Backup Server | [CT108-PBS.md](./container/CT108-PBS.md) |
| 109 | homeassistant | .130 | 2 GB | 2 | 10 GB | Smart Home | [CT109-HOMEASSISTANT.md](./container/CT109-HOMEASSISTANT.md) |
| 110 | paperless | .131 | 2 GB | 2 | 10 GB | Dokumentenverwaltung | [CT110-PAPERLESS.md](./container/CT110-PAPERLESS.md) |

**Gesamt-Ressourcen:** ~24 GB RAM, 19 CPU Cores, ~132 GB Disk

---

## 💾 Storage

### Disks

| Disk | Modell | Schnittstelle | Größe | Mount | Verwendung | SMART |
|------|--------|---------------|-------|-------|------------|-------|
| NVMe | Kingston SA2000M8 | NVMe | 465 GB | `/` | Proxmox + LVM | ✅ PASSED |
| SSD | Samsung 860 EVO | SATA | 458 GB | `/mnt/storage` | Daten, Medien | ✅ PASSED |
| SSD | Lexar 480GB | USB | 447 GB | `/mnt/backups` | Backups | ⚠️ USB* |

*\* SMART via USB: `smartctl -d sat -H /dev/sdb`*

### Ordnerstruktur

```
/mnt/storage/
├── shared/           # Samba-Freigabe: Allgemeine Dateien
│   └── .recycle/     # Papierkorb pro Benutzer
├── media/            # Samba-Freigabe + Jellyfin
│   ├── movies/       # Filme
│   ├── music/        # Musik
│   └── photos/       # Fotos
└── backups/          # Samba-Freigabe: Geräte-Backups

/mnt/backups/         # Backup-SSD (USB)
└── proxmox/          # PBS Datastore
```

### LVM-Thin Pool Status

```
LV            Size    Data%   Beschreibung
─────────────────────────────────────────────
data          337 GB  ~14%    Thin Pool
vm-100-disk-0  15 GB   9%     Samba
vm-101-disk-0   8 GB  16%     Pi-hole
vm-102-disk-0   8 GB  25%     WireGuard
vm-103-disk-0   8 GB  23%     Vaultwarden
vm-104-disk-0   8 GB  38%     Nginx PM
vm-105-disk-0  32 GB  66%     Jellyfin
vm-106-disk-0  15 GB  12%     Prometheus
vm-107-disk-0   8 GB  29%     Grafana
vm-108-disk-0  20 GB  11%     PBS
vm-109-disk-0  10 GB  47%     Home Assistant
vm-110-disk-0  10 GB  41%     Paperless
```

---

## 🔥 Firewall & Ports

### Extern erreichbar (Port-Forwarding im Router)

| Dienst | Port | Protokoll | Ziel-IP | Beschreibung |
|--------|------|-----------|---------|--------------|
| WireGuard VPN | 51820 | UDP | 192.168.2.123 | VPN-Tunnel |
| HTTPS | 443 | TCP | 192.168.2.125 | Nginx (Vaultwarden) |
| HTTP | 80 | TCP | 192.168.2.125 | Nginx (Let's Encrypt) |

### Nur LAN (192.168.2.0/24)

| Dienst | Port | Container | Beschreibung |
|--------|------|-----------|--------------|
| Proxmox Web | 8006 | Host | Server-Verwaltung |
| SSH | 22 | Host | Remote-Zugang |
| Samba | 445 | CT 100 | Dateifreigabe |
| DNS | 53 | CT 101 | DNS-Auflösung |
| Pi-hole Web | 80 | CT 101 | Admin-Interface |
| DHCP | 67 | CT 101 | IP-Vergabe |
| WG-Easy Web | 51821 | CT 102 | VPN-Verwaltung |
| Vaultwarden | 8081 | CT 103 | (nur via Nginx) |
| NPM Admin | 81 | CT 104 | Proxy-Verwaltung |
| Jellyfin | 8096 | CT 105 | Media Server |
| Prometheus | 9090 | CT 106 | Metriken |
| Grafana | 3000 | CT 107 | Dashboards |
| PBS | 8007 | CT 108 | Backup Server |
| Home Assistant | 8123 | CT 109 | Smart Home |
| Paperless | 8000 | CT 110 | Dokumente |

---

## ⚡ Schnellbefehle

### Container verwalten

```bash
# Alle Container anzeigen
pct list

# Container starten/stoppen/neustarten
pct start 100
pct stop 100
pct restart 100

# In Container einloggen
pct enter 100

# Alle Container-IPs anzeigen
for i in $(pct list | awk 'NR>1 {print $1}'); do
  echo -n "CT $i: "; pct exec $i -- hostname -I 2>/dev/null || echo "offline"
done
```

### Diagnose-Script

```bash
# Vollständige System-Diagnose
./scripts/rxfsys-diagnostics.sh
```

### System-Updates

```bash
# Host updaten
apt update && apt full-upgrade -y

# Alle Container updaten
for i in $(pct list | awk 'NR>1 {print $1}'); do
  echo "=== Updating CT $i ==="
  pct exec $i -- apt update
  pct exec $i -- apt upgrade -y
done

# Docker-Images aktualisieren (CT 102, 103, 104)
for ct in 102 103 104; do
  pct exec $ct -- bash -c 'cd /srv/appdata/* && docker compose pull && docker compose up -d'
done
```

### Storage & Health

```bash
# Storage-Status
df -h /mnt/storage /mnt/backups
pvesm status

# SMART-Status
smartctl -H /dev/sda           # Samsung SSD (SATA)
smartctl -H /dev/nvme0n1       # Kingston NVMe
smartctl -d sat -H /dev/sdb    # Lexar SSD (USB)

# LVM-Status
lvs
```

### Backup

```bash
# Container sichern (lokal)
vzdump 100 --storage local --compress zstd --mode snapshot

# Alle Container sichern
for i in $(pct list | awk 'NR>1 {print $1}'); do
  vzdump $i --storage local --compress zstd --mode snapshot
done
```

---

## 🛠️ Wartung

### Automatisierte Tasks

| Task | Zeitplan | Beschreibung |
|------|----------|--------------|
| DuckDNS Update | */5 * * * * | IP-Aktualisierung |
| Container-Backup | 03:00 täglich | vzdump aller Container |
| PBS Prune | wöchentlich | Alte Backups entfernen |

### Wöchentliche Routine

- [ ] SMART-Status prüfen
- [ ] Logs auf Fehler checken
- [ ] Backup-Integrität prüfen
- [ ] Diagnose-Script ausführen

### Monatliche Routine

- [ ] Host updaten
- [ ] Alle Container updaten
- [ ] Docker-Images aktualisieren
- [ ] SSL-Zertifikate prüfen (Nginx PM)
- [ ] Pi-hole Blocklisten aktualisieren

---

## 🆘 Notfall-Hilfe

### Proxmox nicht erreichbar?

```bash
# Am Server direkt (Tastatur/Monitor):
systemctl status pveproxy
systemctl restart pveproxy
pve-firewall stop  # Falls Firewall blockiert
```

### Container startet nicht?

```bash
journalctl -xe
pct config 100
lxc-start -n 100 -F -l DEBUG
```

### Kein Internet im Container?

```bash
pct exec 100 -- bash -c '
  ip addr
  ip route
  cat /etc/resolv.conf
  ping -c 3 8.8.8.8
'
```

### DuckDNS IP stimmt nicht?

```bash
# Manuell aktualisieren
curl "https://www.duckdns.org/update?domains=rxfsys,vault-rxfsys&token=DEIN_TOKEN&ip="

# Cronjob prüfen
crontab -l | grep duckdns
```

---

## 📚 Dokumentation

### Container-Dokumentation

| Datei | Beschreibung |
|-------|--------------|
| [container/CT100-SAMBA.md](./container/CT100-SAMBA.md) | NAS/Samba Container |
| [container/CT101-PIHOLE.md](./container/CT101-PIHOLE.md) | Pi-hole DNS/DHCP |
| [container/CT102-WIREGUARD.md](./container/CT102-WIREGUARD.md) | WireGuard VPN |
| [container/CT103-VAULTWARDEN.md](./container/CT103-VAULTWARDEN.md) | Vaultwarden |
| [container/CT104-NGINX.md](./container/CT104-NGINX.md) | Nginx Proxy Manager |
| [container/CT105-JELLYFIN.md](./container/CT105-JELLYFIN.md) | Jellyfin Media Server |
| [container/CT106-PROMETHEUS.md](./container/CT106-PROMETHEUS.md) | Prometheus |
| [container/CT107-GRAFANA.md](./container/CT107-GRAFANA.md) | Grafana |
| [container/CT108-PBS.md](./container/CT108-PBS.md) | Proxmox Backup Server |
| [container/CT109-HOMEASSISTANT.md](./container/CT109-HOMEASSISTANT.md) | Home Assistant |
| [container/CT110-PAPERLESS.md](./container/CT110-PAPERLESS.md) | Paperless-ngx |

### Scripts

| Datei | Beschreibung |
|-------|--------------|
| [scripts/rxfsys-diagnostics.sh](./scripts/rxfsys-diagnostics.sh) | System-Diagnose |

---

## 🔗 Externe Ressourcen

- [Proxmox Wiki](https://pve.proxmox.com/wiki/)
- [Pi-hole Docs](https://docs.pi-hole.net/)
- [WireGuard](https://www.wireguard.com/)
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [Nginx Proxy Manager](https://nginxproxymanager.com/)
- [Jellyfin Docs](https://jellyfin.org/docs/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)
- [Home Assistant Docs](https://www.home-assistant.io/docs/)
- [Paperless-ngx Docs](https://docs.paperless-ngx.com/)

---

*Server: rxfsys | Letzte Aktualisierung: Februar 2026*
