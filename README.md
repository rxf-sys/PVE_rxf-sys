# Home-Server rxfsys

> Proxmox VE Home-Server mit 11 LXC-Containern fuer NAS, DNS/DHCP, VPN, Passwort-Manager, Media-Server, Monitoring, Backup und Smart Home

---

## Schnelluebersicht

| | |
|---|---|
| **Hostname** | rxfsys |
| **OS** | Proxmox VE 9.1.6 |
| **Kernel** | Linux 6.17.13-1-pve (EFI Secure Boot) |
| **CPU** | Intel Core i5-9500T (6 Cores @ 2.20GHz) |
| **RAM** | 32 GB DDR4 |
| **Storage** | 500GB NVMe (System) + 500GB SSD (Daten) + 480GB SSD (Backup/USB) |
| **Netzwerk** | 192.168.2.0/24 |

---

## Dokumentationsstruktur

| Verzeichnis | Beschreibung |
|-------------|--------------|
| [01-hardware/](01-hardware/) | Server-Hardware, Storage, Netzwerk-Verkabelung |
| [02-installation/](02-installation/) | Proxmox Installation, Post-Install, Scripts |
| [03-netzwerk/](03-netzwerk/) | Bridges, IP-Schema, Firewall, Netzwerk-Diagramme |
| [04-storage/](04-storage/) | LVM-Thin, Mount-Punkte, Berechtigungen |
| [05-container/](05-container/) | Alle LXC-Container und VM-Dokumentation |
| [06-backup/](06-backup/) | Backup-Strategie, vzdump, PBS, Restore |
| [07-monitoring/](07-monitoring/) | Prometheus, Grafana, Alerting |
| [08-sicherheit/](08-sicherheit/) | Benutzer, Zertifikate, 2FA, Haertung |
| [09-wartung/](09-wartung/) | Updates, Checklisten (woechentlich/monatlich) |
| [10-disaster-recovery/](10-disaster-recovery/) | Notfallplaene, Wiederherstellung, Troubleshooting |
| [configs/](configs/) | Anonymisierte Konfigurationsdateien |
| [scripts/](scripts/) | Automatisierungs-Scripts |
| [diagramme/](diagramme/) | Netzwerk- und Storage-Diagramme |
| [templates/](templates/) | Vorlagen fuer neue Container/Dokumentation |

---

## Netzwerk-Architektur

```
┌──────────────────────────────────────────────────────────────────────┐
│                    HEIMNETZWERK 192.168.2.0/24                       │
│                                                                      │
│   Router (Speedport Smart 4)                                         │
│   192.168.2.1  │  DHCP: Deaktiviert (Pi-hole uebernimmt)            │
│                │                                                     │
│   ─────────────┴─────────────────────────────────────────────────    │
│                                                                      │
│   PROXMOX HOST (rxfsys)                                              │
│   192.168.2.120  │  https://192.168.2.120:8006                       │
│                  │                                                   │
│   ┌──────────────┴────────────────────────────────────────────┐      │
│   │                    LXC CONTAINER                          │      │
│   ├───────────────────────────────────────────────────────────┤      │
│   │  CT 100 - Samba         192.168.2.121  :445               │      │
│   │  CT 101 - Pi-hole       192.168.2.122  :53/:80/:67        │      │
│   │  CT 102 - WireGuard     192.168.2.123  :51820/:51821      │      │
│   │  CT 103 - Vaultwarden   192.168.2.124  :8081              │      │
│   │  CT 104 - Nginx-Proxy   192.168.2.125  :80/:443/:81       │      │
│   │  CT 105 - Jellyfin      192.168.2.126  :8096              │      │
│   │  CT 106 - Prometheus    192.168.2.127  :9090              │      │
│   │  CT 107 - Grafana       192.168.2.128  :3000              │      │
│   │  CT 108 - PBS           192.168.2.129  :8007              │      │
│   │  CT 109 - Home Assist.  192.168.2.130  :8123              │      │
│   │  CT 110 - Paperless     192.168.2.131  :8000              │      │
│   │  CT 111 - Finance       192.168.2.132  :8080              │      │
│   └───────────────────────────────────────────────────────────┘      │
│                                                                      │
│   IP-Bereiche:                                                       │
│   • Server (statisch): 192.168.2.120-132                             │
│   • Clients (DHCP):    192.168.2.30-119 (via Pi-hole)                │
│   • Reserviert:        192.168.2.2-29, 192.168.2.133-254             │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Container-Uebersicht

| ID | Name | IP | RAM | CPU | Disk | Funktion | Doku |
|----|------|-----|-----|-----|------|----------|------|
| 100 | samba | .121 | 1 GB | 1 | 15 GB | Dateiserver (NAS) | [Doku](05-container/lxc/CT100-samba.md) |
| 101 | pi-hole | .122 | 2 GB | 2 | 8 GB | DNS + DHCP + Werbeblocker | [Doku](05-container/lxc/CT101-pihole.md) |
| 102 | wireguard | .123 | 1 GB | 1 | 8 GB | VPN Server (wg-easy) | [Doku](05-container/lxc/CT102-wireguard.md) |
| 103 | vaultwarden | .124 | 2 GB | 1 | 8 GB | Passwort-Manager | [Doku](05-container/lxc/CT103-vaultwarden.md) |
| 104 | nginx-proxy | .125 | 1 GB | 1 | 8 GB | Reverse Proxy + SSL | [Doku](05-container/lxc/CT104-nginx.md) |
| 105 | jellyfin | .126 | 8 GB | 4 | 32 GB | Media Server | [Doku](05-container/lxc/CT105-jellyfin.md) |
| 106 | prometheus | .127 | 2 GB | 2 | 15 GB | Metriken-Sammlung | [Doku](05-container/lxc/CT106-prometheus.md) |
| 107 | grafana | .128 | 1 GB | 1 | 8 GB | Monitoring-Dashboards | [Doku](05-container/lxc/CT107-grafana.md) |
| 108 | pbs | .129 | 2 GB | 2 | 20 GB | Proxmox Backup Server | [Doku](05-container/lxc/CT108-pbs.md) |
| 109 | homeassistant | .130 | 2 GB | 2 | 10 GB | Smart Home | [Doku](05-container/lxc/CT109-homeassistant.md) |
| 110 | paperless | .131 | 2 GB | 2 | 10 GB | Dokumentenverwaltung | [Doku](05-container/lxc/CT110-paperless.md) |
| 111 | finance | .132 | 3 GB | 2 | 10 GB | Finanzverwaltung | - |

**Gesamt-Ressourcen:** ~27 GB RAM, 21 CPU Cores, ~142 GB Disk

---

## Wichtige URLs

### Interne Dienste

| Dienst | URL | Beschreibung |
|--------|-----|--------------|
| **Proxmox** | https://192.168.2.120:8006 | Server-Verwaltung |
| **Pi-hole** | http://pihole.home/admin | DNS und Werbeblocker |
| **WireGuard** | http://vpn.home:51821 | VPN-Verwaltung |
| **Nginx PM** | http://proxy.home:81 | Reverse Proxy Admin |
| **Jellyfin** | http://jellyfin.home:8096 | Media Server |
| **Prometheus** | http://prometheus.home:9090 | Metriken |
| **Grafana** | http://grafana.home:3000 | Dashboards |
| **PBS** | https://pbs.home:8007 | Backup Server |
| **Home Assistant** | http://homeassistant.home:8123 | Smart Home |
| **Paperless** | http://paperless.home:8000 | Dokumentenverwaltung |
| **Finance** | http://finance.home:8080 | Finanzverwaltung |
| **NAS (Windows)** | `\\samba.home\shared` | Dateifreigabe |
| **NAS (Mac/Linux)** | `smb://samba.home/shared` | Dateifreigabe |

### Externe Dienste (via DuckDNS)

| Dienst | URL |
|--------|-----|
| **Vaultwarden** | https://vault-rxfsys.duckdns.org |
| **WireGuard** | rxfsys.duckdns.org:51820 |

---

## Schnellbefehle

```bash
# Alle Container anzeigen
pct list

# Container verwalten
pct start|stop|restart <ID>
pct enter <ID>

# System-Diagnose
./scripts/rxfsys-diagnostics.sh

# Health-Check
./scripts/health-check.sh

# Alle Container sichern
./scripts/backup-all.sh

# Host updaten
apt update && apt full-upgrade -y
```

---

## Scripts

| Script | Beschreibung |
|--------|--------------|
| [scripts/rxfsys-diagnostics.sh](scripts/rxfsys-diagnostics.sh) | Vollstaendige System-Diagnose |
| [scripts/rxfsys-autoupdate.sh](scripts/rxfsys-autoupdate.sh) | Automatische Updates |
| [scripts/backup-all.sh](scripts/backup-all.sh) | Alle Container sichern |
| [scripts/health-check.sh](scripts/health-check.sh) | Taeglicher Health-Check |
| [scripts/vm-inventory.sh](scripts/vm-inventory.sh) | VM/CT Inventar exportieren |

---

## Externe Ressourcen

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

*Server: rxfsys | Letzte Aktualisierung: Maerz 2026*
