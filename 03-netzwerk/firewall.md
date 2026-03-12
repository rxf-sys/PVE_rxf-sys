# Firewall und Ports

## Extern erreichbar (Port-Forwarding im Router)

| Dienst | Port | Protokoll | Ziel-IP | Beschreibung |
|--------|------|-----------|---------|--------------|
| WireGuard VPN | 51820 | UDP | 192.168.2.123 | VPN-Tunnel |
| HTTPS | 443 | TCP | 192.168.2.125 | Nginx (Vaultwarden) |
| HTTP | 80 | TCP | 192.168.2.125 | Nginx (Let's Encrypt) |

## Nur LAN (192.168.2.0/24)

| Dienst | Port | Container | Beschreibung |
|--------|------|-----------|--------------|
| Proxmox Web | 8006 | Host | Server-Verwaltung |
| SSH | 22 | Host | Remote-Zugang |
| Samba/SMB | 445 | CT 100 | Dateifreigabe |
| DNS | 53 | CT 101 | DNS-Aufloesung (TCP/UDP) |
| Pi-hole Web | 80 | CT 101 | Admin-Interface |
| DHCP | 67 | CT 101 | IP-Vergabe (UDP) |
| WG-Easy Web | 51821 | CT 102 | VPN-Verwaltung |
| Vaultwarden | 8081 | CT 103 | Nur via Nginx erreichbar |
| NPM Admin | 81 | CT 104 | Proxy-Verwaltung |
| Jellyfin | 8096 | CT 105 | Media Server |
| Prometheus | 9090 | CT 106 | Metriken |
| Grafana | 3000 | CT 107 | Dashboards |
| PBS | 8007 | CT 108 | Backup Server |
| Home Assistant | 8123 | CT 109 | Smart Home |
| Paperless | 8000 | CT 110 | Dokumente |

## Proxmox Firewall

### Aktivierung

```bash
# Datacenter-Firewall aktivieren
# Web-UI: Datacenter -> Firewall -> Options -> Enable: Yes

# Host-Firewall aktivieren
# Web-UI: Node -> Firewall -> Options -> Enable: Yes

# Pro Container aktivieren
# Web-UI: CT -> Firewall -> Options -> Enable: Yes
```

### Empfohlene Regeln (Datacenter-Ebene)

| Richtung | Aktion | Protokoll | Port | Quelle | Beschreibung |
|----------|--------|-----------|------|--------|--------------|
| IN | ACCEPT | TCP | 8006 | 192.168.2.0/24 | Proxmox Web |
| IN | ACCEPT | TCP | 22 | 192.168.2.0/24 | SSH |
| IN | DROP | - | - | - | Alles andere |

## Pruefbefehle

```bash
# Firewall-Status
pve-firewall status

# Aktive Regeln anzeigen
iptables -L -n -v

# Firewall-Log
journalctl -u pve-firewall

# Port-Scan (vom Client)
nmap -sT 192.168.2.120
```
