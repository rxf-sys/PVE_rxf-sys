# VMs und Container

Uebersicht aller virtuellen Maschinen und LXC-Container auf dem Proxmox Server.

| Dokument | Beschreibung |
|----------|--------------|
| [lxc/](lxc/) | Dokumentation aller LXC-Container |
| [vms/](vms/) | Dokumentation aller VMs (aktuell keine) |
| [templates/](templates/) | Vorlagen fuer neue Container/VMs |

## LXC-Container Uebersicht

| ID | Name | IP | RAM | CPU | Disk | Funktion | Doku |
|----|------|-----|-----|-----|------|----------|------|
| 100 | samba | .121 | 1 GB | 1 | 15 GB | Dateiserver (NAS) | [CT100](lxc/CT100-samba.md) |
| 101 | pi-hole | .122 | 2 GB | 2 | 8 GB | DNS + DHCP + Werbeblocker | [CT101](lxc/CT101-pihole.md) |
| 102 | wireguard | .123 | 1 GB | 1 | 8 GB | VPN Server (wg-easy) | [CT102](lxc/CT102-wireguard.md) |
| 103 | vaultwarden | .124 | 2 GB | 1 | 8 GB | Passwort-Manager | [CT103](lxc/CT103-vaultwarden.md) |
| 104 | nginx-proxy | .125 | 1 GB | 1 | 8 GB | Reverse Proxy + SSL | [CT104](lxc/CT104-nginx.md) |
| 105 | jellyfin | .126 | 8 GB | 4 | 32 GB | Media Server | [CT105](lxc/CT105-jellyfin.md) |
| 106 | monitoring | .127 | 2 GB | 2 | 15 GB | Prometheus + Grafana | [CT106](lxc/CT106-monitoring.md) |
| 108 | pbs | .129 | 2 GB | 2 | 20 GB | Proxmox Backup Server | [CT108](lxc/CT108-pbs.md) |
| 109 | homeassistant | .130 | 2 GB | 2 | 10 GB | Smart Home | [CT109](lxc/CT109-homeassistant.md) |
| 110 | paperless | .131 | 2 GB | 2 | 10 GB | Dokumentenverwaltung | [CT110](lxc/CT110-paperless.md) |
| 111 | finance | .132 | 3 GB | 2 | 10 GB | Finanzguru (Orynthia) | [CT111](lxc/CT111-finanzguru.md) |

**Gesamt:** ~26 GB RAM, 20 CPU Cores, ~134 GB Disk (11 Container)

> **Hinweis:** CT 107 (Grafana) wurde mit CT 106 zusammengelegt → CT 106 "monitoring"

## VMs

Aktuell werden **keine VMs** verwendet. Alle Dienste laufen als LXC-Container.

## Wichtige URLs

| Dienst | URL |
|--------|-----|
| Proxmox | https://192.168.2.120:8006 |
| Pi-hole | http://pihole.home/admin |
| WireGuard | http://vpn.home:51821 |
| Nginx PM | http://proxy.home:81 |
| Jellyfin | http://jellyfin.home:8096 |
| Grafana | http://grafana.home:3000 |
| Prometheus | http://monitoring.home:9090 |
| PBS | https://pbs.home:8007 |
| Home Assistant | http://homeassistant.home:8123 |
| Paperless | http://paperless.home:8000 |
| Finanzguru | http://finance.home:8080 |
| Vaultwarden | https://vault-rxfsys.duckdns.org |

## Schnellbefehle

```bash
# Alle Container anzeigen
pct list

# Container starten/stoppen/neustarten
pct start <ID>
pct stop <ID>
pct restart <ID>

# In Container einloggen
pct enter <ID>

# Container-Konfiguration anzeigen
pct config <ID>

# Alle Container-IPs anzeigen
for i in $(pct list | awk 'NR>1 {print $1}'); do
  echo -n "CT $i: "; pct exec $i -- hostname -I 2>/dev/null || echo "offline"
done
```
