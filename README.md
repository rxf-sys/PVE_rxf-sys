# 🖥️ Home-Server rxfsys

> Proxmox VE Home-Server mit NAS, Pi-hole, WireGuard VPN, Vaultwarden, Nginx Reverse Proxy und Jellyfin Media Server

---

## 📋 Schnellübersicht

| | |
|---|---|
| **Hostname** | rxfsys |
| **OS** | Proxmox VE 9.1.1 |
| **Kernel** | Linux 6.17.2-1-pve (EFI Secure Boot) |
| **CPU** | Intel Core i5-9500T (6 Cores @ 2.20GHz) |
| **RAM** | 32 GB DDR4 |
| **Storage** | 500GB NVMe (System) + 500GB SSD (Daten) + 500GB SSD (Backup) |
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
│   │  📁 CT 100 - NAS           192.168.2.121  :445            │      │
│   │  🛡️ CT 101 - Pi-hole       192.168.2.122  :53/:80/:67     │      │
│   │  🔐 CT 102 - WireGuard     192.168.2.123  :51820/:51821   │      │
│   │  🔑 CT 103 - Vaultwarden   192.168.2.124  :8081           │      │
│   │  🌐 CT 104 - Nginx-Proxy   192.168.2.125  :80/:443/:81    │      │
│   │  🎬 CT 105 - Jellyfin      192.168.2.126  :8096           │      │
│   └───────────────────────────────────────────────────────────┘      │
│                                                                      │
│   📊 IP-Bereiche:                                                    │
│   • Server (statisch): 192.168.2.120-126                             │
│   • Clients (DHCP):    192.168.2.30-119 (via Pi-hole)                │
│   • Reserviert:        192.168.2.2-29, 192.168.2.127-254             │
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
| **NAS (Windows)** | `\\nas.home\shared` | Dateifreigabe |
| **NAS (Mac/Linux)** | `smb://nas.home/shared` | Dateifreigabe |

### Externe Dienste (via DuckDNS)

| Dienst | URL | Beschreibung |
|--------|-----|--------------|
| **Vaultwarden** | https://vault-rxfsys.duckdns.org | Passwort-Manager |
| **WireGuard** | rxfsys.duckdns.org:51820 | VPN-Verbindung |

### Lokale DNS-Namen (.home)

| Name | IP | Dienst |
|------|-----|--------|
| proxmox.home | 192.168.2.120 | Proxmox Host |
| nas.home | 192.168.2.121 | Samba NAS |
| pihole.home | 192.168.2.122 | Pi-hole DNS/DHCP |
| vpn.home | 192.168.2.123 | WireGuard VPN |
| vault.home | 192.168.2.124 | Vaultwarden |
| proxy.home | 192.168.2.125 | Nginx Proxy |
| jellyfin.home | 192.168.2.126 | Jellyfin Media |

---

## 📦 Container-Übersicht

| ID | Name | IP | RAM | CPU | Disk | Funktion | Dokumentation |
|----|------|-----|-----|-----|------|----------|---------------|
| 100 | nas | .121 | 1 GB | 1 | 15 GB | Samba Dateiserver | [CT100-NAS.md](./CT100-NAS.md) |
| 101 | pi-hole | .122 | 1 GB | 1 | 8 GB | DNS + DHCP + Werbeblocker | [CT101-PIHOLE.md](./CT101-PIHOLE.md) |
| 102 | wireguard | .123 | 1 GB | 1 | 8 GB | VPN Server (wg-easy) | [CT102-WIREGUARD.md](./CT102-WIREGUARD.md) |
| 103 | vaultwarden | .124 | 2 GB | 1 | 8 GB | Passwort-Manager | [CT103-VAULTWARDEN.md](./CT103-VAULTWARDEN.md) |
| 104 | nginx-proxy | .125 | 1 GB | 1 | 8 GB | Reverse Proxy + SSL | [CT104-NGINX.md](./CT104-NGINX.md) |
| 105 | jellyfin | .126 | 2 GB | 2 | 10 GB | Media Server | [CT105-JELLYFIN.md](./CT105-JELLYFIN.md) |

**Gesamt-Ressourcen:** ~8 GB RAM, 6 CPU Cores, ~57 GB Disk

---

## 💾 Storage

### Disks

| Disk | Modell | Mount | Größe | Verwendung | SMART |
|------|--------|-------|-------|------------|-------|
| NVMe | Kingston SA2000M8 | `/` | 500 GB | Proxmox + LVM | ✅ PASSED |
| SSD | Samsung 860 EVO | `/mnt/storage` | 500 GB | Daten, Medien | ✅ PASSED |
| SSD | (noch nicht eingebunden) | `/mnt/backups` | 500 GB | Backups | - |

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
```

### LVM-Thin Pool

```
/dev/pve/data (337 GB)
├── vm-100-disk-0    15 GB   NAS rootfs
├── vm-101-disk-0     8 GB   Pi-hole rootfs
├── vm-102-disk-0     8 GB   WireGuard rootfs
├── vm-103-disk-0     8 GB   Vaultwarden rootfs
├── vm-104-disk-0     8 GB   Nginx rootfs
└── vm-105-disk-0    10 GB   Jellyfin rootfs
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

# Container-Config anzeigen
pct config 100
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
```

### Storage & Health

```bash
# Storage-Status
df -h
pvesm status

# SMART-Status
smartctl -H /dev/sda
smartctl -H /dev/nvme0n1

# LVM-Status
lvs
```

### Backup

```bash
# Container sichern
vzdump 100 --storage local --compress zstd --mode snapshot

# Alle Container sichern
for i in $(pct list | awk 'NR>1 {print $1}'); do
  vzdump $i --storage local --compress zstd --mode snapshot
done

# Backup wiederherstellen
pct restore 999 /var/lib/vz/dump/vzdump-lxc-100-*.tar.zst --storage local-lvm
```

### Firewall

```bash
# Status
pve-firewall status

# Neustart
pve-firewall restart

# Notfall: Deaktivieren
pve-firewall stop
```

### Logs

```bash
# System-Logs
journalctl -xe

# Fehler der letzten Boot-Session
journalctl -p err -b

# Container-Logs
pct exec 100 -- journalctl -xe
```

---

## 🛠️ Wartung

### Wöchentliche Routine

- [ ] SMART-Status prüfen
- [ ] Logs auf Fehler checken
- [ ] Backup-Integrität prüfen

### Monatliche Routine

- [ ] Host updaten: `apt update && apt full-upgrade`
- [ ] Alle Container updaten
- [ ] Docker-Images aktualisieren (CT 102, 103, 104, 105)
- [ ] SSL-Zertifikate prüfen (Nginx PM)
- [ ] Pi-hole Blocklisten aktualisieren

### Vor größeren Updates

1. Snapshot/Backup aller Container erstellen
2. Release Notes lesen
3. Update durchführen
4. Alle Dienste testen

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
lxc-start -n 100 -F -l DEBUG  # Debug-Modus
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

### Durch Firewall ausgesperrt?

```bash
# Am Server direkt:
pve-firewall stop
# Dann Regeln korrigieren und wieder aktivieren
```

### DHCP funktioniert nicht?

```bash
# Pi-hole DHCP prüfen
pct exec 101 -- cat /etc/pihole/dhcp.leases
pct exec 101 -- pihole restartdns
```

---

## 📚 Dokumentation

| Datei | Beschreibung |
|-------|--------------|
| [README.md](./README.md) | Diese Übersicht |
| [HAUPTDOKUMENTATION.md](./HAUPTDOKUMENTATION.md) | Ausführliche technische Dokumentation |
| [CT100-NAS.md](./CT100-NAS.md) | NAS/Samba Container |
| [CT101-PIHOLE.md](./CT101-PIHOLE.md) | Pi-hole DNS/DHCP |
| [CT102-WIREGUARD.md](./CT102-WIREGUARD.md) | WireGuard VPN |
| [CT103-VAULTWARDEN.md](./CT103-VAULTWARDEN.md) | Vaultwarden Passwort-Manager |
| [CT104-NGINX.md](./CT104-NGINX.md) | Nginx Proxy Manager |
| [CT105-JELLYFIN.md](./CT105-JELLYFIN.md) | Jellyfin Media Server |

---

## 🔗 Externe Ressourcen

- [Proxmox Wiki](https://pve.proxmox.com/wiki/)
- [Proxmox Forum](https://forum.proxmox.com/)
- [Pi-hole Docs](https://docs.pi-hole.net/)
- [WireGuard](https://www.wireguard.com/)
- [wg-easy GitHub](https://github.com/wg-easy/wg-easy)
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [Nginx Proxy Manager](https://nginxproxymanager.com/)
- [Jellyfin Docs](https://jellyfin.org/docs/)

---

*Server: rxfsys | Letzte Aktualisierung: Januar 2026*
