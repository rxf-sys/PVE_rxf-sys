# CT 104 - Nginx Proxy Manager

## Übersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 104 |
| **Hostname** | nginx-proxy |
| **IP-Adresse** | 192.168.2.125 |
| **RAM** | 1024 MB |
| **CPU** | 1 Core |
| **Disk** | 8 GB |
| **OS** | Debian |
| **Dienst** | Nginx Proxy Manager (Docker) |

---

## Funktion

Nginx Proxy Manager dient als Reverse Proxy mit automatischer SSL-Zertifikatsverwaltung via Let's Encrypt. Er ermöglicht sicheren HTTPS-Zugriff auf interne Dienste von außen.

---

## Zugriff

| Dienst | URL |
|--------|-----|
| Admin-Panel | http://192.168.2.125:81 |
| Mit lokalem DNS | http://proxy.home:81 |
| HTTP | Port 80 |
| HTTPS | Port 443 |

### Zugangsdaten

| Parameter | Wert |
|-----------|------|
| E-Mail | `___________________` |
| Passwort | `___________________` |

**Standard-Login (nach Erstinstallation):**
- E-Mail: `admin@example.com`
- Passwort: `changeme`

---

## Container-Konfiguration

**Datei:** `/etc/pve/lxc/104.conf`

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

---

## Docker-Konfiguration

**Datei (im Container):** `/srv/appdata/nginx-proxy/docker-compose.yml`

```yaml
version: "3.8"
services:
  npm:
    image: jc21/nginx-proxy-manager:latest
    container_name: npm
    ports:
      - "80:80"
      - "443:443"
      - "81:81"
    volumes:
      - /srv/appdata/nginx-proxy/data:/data
      - /srv/appdata/nginx-proxy/letsencrypt:/etc/letsencrypt
    restart: unless-stopped
```

---

## Port-Forwarding im Router

| Extern | Protokoll | Intern | Ziel-IP |
|--------|-----------|--------|---------|
| 80 | TCP | 80 | 192.168.2.125 |
| 443 | TCP | 443 | 192.168.2.125 |

---

## Konfigurierte Proxy Hosts

### Vaultwarden

| Parameter | Wert |
|-----------|------|
| Domain | vault-rxfsys.duckdns.org |
| Scheme | http |
| Forward IP | 192.168.2.124 |
| Forward Port | 8081 |
| SSL | Let's Encrypt |
| Force SSL | ✅ |
| Websockets | ✅ |

---

## SSL-Zertifikate

### Let's Encrypt mit DuckDNS DNS-Challenge

1. **SSL Certificates** → **Add SSL Certificate** → **Let's Encrypt**
2. Domain: `vault-rxfsys.duckdns.org`
3. **Use a DNS Challenge:** ✅ Aktivieren
4. **DNS Provider:** DuckDNS
5. **Credentials:**
   ```
   dns_duckdns_token=DEIN_DUCKDNS_TOKEN
   ```
6. **Propagation Seconds:** 120
7. **Save**

### Zertifikat-Status prüfen

Im Admin-Panel unter **SSL Certificates** sind alle Zertifikate mit Ablaufdatum aufgelistet. Zertifikate werden automatisch vor Ablauf erneuert.

---

## Proxy Host erstellen

### Schritt-für-Schritt

1. **Hosts** → **Proxy Hosts** → **Add Proxy Host**

2. **Details Tab:**
   - Domain Names: `deine-domain.duckdns.org`
   - Scheme: `http` (oder `https` falls Backend HTTPS hat)
   - Forward Hostname / IP: `192.168.2.xxx`
   - Forward Port: `xxxx`
   - ✅ Websockets Support (falls benötigt)

3. **SSL Tab:**
   - SSL Certificate: Vorher erstelltes Zertifikat auswählen
   - ✅ Force SSL
   - ✅ HTTP/2 Support

4. **Save**

---

## Verwaltung

### Container-Status

```bash
pct exec 104 -- docker ps
```

### Nginx-Logs

```bash
pct exec 104 -- docker logs npm --tail 50
```

### Container neustarten

```bash
pct exec 104 -- docker restart npm
```

### NPM aktualisieren

```bash
pct exec 104 -- bash -c 'cd /srv/appdata/nginx-proxy && docker compose pull && docker compose up -d'
```

---

## Firewall

**Datei:** `/etc/pve/firewall/104.fw`

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# HTTP (extern - für Let's Encrypt und Redirect)
IN ACCEPT -p tcp -dport 80 -log nolog

# HTTPS (extern)
IN ACCEPT -p tcp -dport 443 -log nolog

# Admin-UI (nur LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 81 -log nolog

# ICMP/Ping
IN ACCEPT -p icmp
```

---

## Troubleshooting

### SSL-Zertifikat kann nicht erstellt werden

1. **Port 80 erreichbar?**
   - Port-Forwarding im Router prüfen
   - Firewall prüfen

2. **DNS-Challenge fehlgeschlagen?**
   - DuckDNS Token korrekt?
   - Propagation Seconds auf 120 erhöhen

3. **Logs prüfen:**
   ```bash
   pct exec 104 -- docker logs npm | grep -i "error\|failed"
   ```

### Proxy Host nicht erreichbar

1. **Backend erreichbar?**
   ```bash
   curl -I http://192.168.2.xxx:port
   ```

2. **SSL-Zertifikat gültig?**
   - SSL Certificates → Ablaufdatum prüfen

3. **Nginx-Config prüfen:**
   ```bash
   pct exec 104 -- docker exec npm nginx -t
   ```

### Admin-Panel nicht erreichbar

```bash
# Container läuft?
pct exec 104 -- docker ps

# Port 81 belegt?
pct exec 104 -- ss -tlnp | grep 81

# Container neustarten
pct exec 104 -- docker restart npm
```

---

## Backup

### Wichtige Dateien

| Pfad | Beschreibung |
|------|--------------|
| `/srv/appdata/nginx-proxy/data/` | NPM Konfiguration + Datenbank |
| `/srv/appdata/nginx-proxy/letsencrypt/` | SSL-Zertifikate |

### Container-Backup

```bash
vzdump 104 --storage local --compress zstd --mode snapshot
```

### Nur Konfiguration sichern

```bash
pct exec 104 -- tar -czf /root/npm-backup.tar.gz /srv/appdata/nginx-proxy/
pct pull 104 /root/npm-backup.tar.gz /mnt/storage/backups/nginx/
```

---

## Sicherheit

| Maßnahme | Status |
|----------|--------|
| Admin-Panel nur LAN | ✅ Port 81 nur intern |
| HTTPS erzwungen | ✅ Force SSL |
| Automatische Zertifikatserneuerung | ✅ Let's Encrypt |

### Passwort ändern

1. Admin-Panel öffnen
2. Oben rechts auf Benutzer klicken
3. **Edit Details**
4. Neues Passwort setzen

---

*CT 104 - Nginx Proxy Manager | Server rxfsys*
