# CT 102 - WireGuard VPN

## Übersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 102 |
| **Hostname** | wireguard |
| **IP-Adresse** | 192.168.2.123 |
| **RAM** | 1024 MB |
| **CPU** | 1 Core |
| **Disk** | 8 GB |
| **OS** | Debian |
| **Dienst** | wg-easy (Docker) |

---

## Funktion

WireGuard ermöglicht sicheren VPN-Zugang zum Heimnetzwerk von unterwegs. Die Verwaltung erfolgt über wg-easy mit Web-Interface.

---

## Zugriff

| Dienst | URL/Port |
|--------|----------|
| Web-Interface | http://192.168.2.123:51821 |
| Mit lokalem DNS | http://vpn.home:51821 |
| VPN-Port (extern) | 51820/UDP |
| DuckDNS | rxfsys.duckdns.org:51820 |

### Zugangsdaten

| Parameter | Wert |
|-----------|------|
| Web-UI Passwort | `___________________` |

---

## Container-Konfiguration

**Datei:** `/etc/pve/lxc/102.conf`

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

---

## Docker-Konfiguration (wg-easy)

**Datei (im Container):** `/srv/appdata/wireguard/docker-compose.yml`

```yaml
version: "3.8"
services:
  wg-easy:
    image: weejewel/wg-easy
    container_name: wg-easy
    environment:
      - WG_HOST=rxfsys.duckdns.org
      - PASSWORD=DEIN_PASSWORT
      - WG_PORT=51820
      - WG_DEFAULT_ADDRESS=10.8.0.x
      - WG_DEFAULT_DNS=192.168.2.122
      - WG_ALLOWED_IPS=192.168.2.0/24, 10.8.0.0/24
    volumes:
      - /etc/wireguard:/etc/wireguard
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv4.ip_forward=1
    restart: unless-stopped
```

---

## VPN-Konfiguration

| Parameter | Wert |
|-----------|------|
| VPN-Port | 51820/UDP |
| Tunnel-Netzwerk | 10.8.0.0/24 |
| DNS für Clients | 192.168.2.122 (Pi-hole) |
| Erlaubte IPs | 192.168.2.0/24, 10.8.0.0/24 |
| Endpunkt | rxfsys.duckdns.org |

---

## DuckDNS

Da sich die öffentliche IP-Adresse ändern kann, wird DuckDNS für Dynamic DNS verwendet:

| Parameter | Wert |
|-----------|------|
| Domain | rxfsys.duckdns.org |
| Token | `___________________` |

### IP-Update einrichten

```bash
# Cronjob auf dem Proxmox-Host oder in einem Container
*/5 * * * * curl -s "https://www.duckdns.org/update?domains=rxfsys&token=DEIN_TOKEN&ip=" > /dev/null
```

---

## Port-Forwarding

Im Speedport Smart 4 Router muss Port-Forwarding eingerichtet sein:

| Extern | Protokoll | Intern | Ziel-IP |
|--------|-----------|--------|---------|
| 51820 | UDP | 51820 | 192.168.2.123 |

---

## Client einrichten

### Neuen Client erstellen

1. Web-UI öffnen: http://192.168.2.123:51821
2. "New Client" klicken
3. Namen eingeben
4. QR-Code scannen oder Config herunterladen

### WireGuard App

| Plattform | App |
|-----------|-----|
| iOS | WireGuard (App Store) |
| Android | WireGuard (Play Store) |
| Windows | WireGuard (wireguard.com) |
| macOS | WireGuard (App Store) |
| Linux | `apt install wireguard` |

---

## Verwaltung

### Container-Status

```bash
pct exec 102 -- docker ps
```

### wg-easy Logs

```bash
pct exec 102 -- docker logs wg-easy --tail 50
```

### WireGuard-Status

```bash
pct exec 102 -- docker exec wg-easy wg show
```

### Aktive Verbindungen

```bash
pct exec 102 -- docker exec wg-easy wg show wg0 | grep -E "peer|latest"
```

### Container neu starten

```bash
pct exec 102 -- bash -c 'cd /srv/appdata/wireguard && docker compose restart'
```

### wg-easy aktualisieren

```bash
pct exec 102 -- bash -c 'cd /srv/appdata/wireguard && docker compose pull && docker compose up -d'
```

---

## Firewall

**Datei:** `/etc/pve/firewall/102.fw`

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# WireGuard VPN (extern!)
IN ACCEPT -p udp -dport 51820 -log nolog

# Web-UI (nur LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 51821 -log nolog

# ICMP/Ping
IN ACCEPT -p icmp
```

---

## Troubleshooting

### VPN verbindet nicht von extern

1. **Port-Forwarding prüfen:**
   - Router: Port 51820/UDP → 192.168.2.123
   
2. **DuckDNS IP prüfen:**
   ```bash
   # Aktuelle öffentliche IP
   curl -s https://api.ipify.org
   
   # DuckDNS-Auflösung
   nslookup rxfsys.duckdns.org
   ```

3. **wg-easy Logs prüfen:**
   ```bash
   pct exec 102 -- docker logs wg-easy --tail 100
   ```

### Client kann nicht auf LAN zugreifen

1. Prüfen ob `WG_ALLOWED_IPS` korrekt gesetzt ist
2. IP-Forwarding prüfen:
   ```bash
   pct exec 102 -- cat /proc/sys/net/ipv4/ip_forward
   # Sollte "1" sein
   ```

### Web-UI nicht erreichbar

```bash
# Docker-Status
pct exec 102 -- docker ps

# Container neu starten
pct exec 102 -- docker restart wg-easy
```

---

## Sicherheit

| Maßnahme | Status |
|----------|--------|
| Web-UI nur LAN | ✅ Port 51821 nur intern |
| Passwort geschützt | ✅ |
| Moderne Kryptografie | ✅ WireGuard Standard |

### Passwort ändern

1. Docker-compose.yml bearbeiten
2. `PASSWORD=NEUES_PASSWORT` setzen
3. Container neu erstellen:
   ```bash
   pct exec 102 -- bash -c 'cd /srv/appdata/wireguard && docker compose down && docker compose up -d'
   ```

---

## Backup

### Wichtige Dateien

| Datei | Beschreibung |
|-------|--------------|
| `/etc/wireguard/wg0.conf` | Server-Konfiguration + Private Key |
| `/etc/wireguard/wg0.json` | Client-Informationen |
| `/srv/appdata/wireguard/docker-compose.yml` | Docker-Konfiguration |

### Container-Backup

```bash
vzdump 102 --storage local --compress zstd --mode snapshot
```

### Nur WireGuard-Keys sichern

```bash
pct exec 102 -- tar -czf /root/wireguard-backup.tar.gz /etc/wireguard/
pct pull 102 /root/wireguard-backup.tar.gz /tmp/wireguard-backup.tar.gz
```

---

*CT 102 - WireGuard | Server rxfsys*
