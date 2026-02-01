# CT 103 - Vaultwarden (Passwort-Manager)

## Übersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 103 |
| **Hostname** | vaultwarden |
| **IP-Adresse** | 192.168.2.124 |
| **RAM** | 2048 MB |
| **CPU** | 1 Core |
| **Disk** | 8 GB |
| **OS** | Debian Trixie |
| **Dienst** | Vaultwarden (Docker) |

---

## Funktion

Vaultwarden ist eine selbst-gehostete, leichtgewichtige Bitwarden-kompatible Passwort-Manager-Implementierung. Der Zugriff erfolgt über HTTPS via Nginx Proxy Manager.

---

## Zugriff

| Dienst | URL |
|--------|-----|
| Extern (HTTPS) | https://vault-rxfsys.duckdns.org |
| Intern (HTTP) | http://192.168.2.124:8081 |
| Admin-Panel | https://vault-rxfsys.duckdns.org/admin |

### Zugangsdaten

| Parameter | Wert |
|-----------|------|
| Admin-Token | `___________________` |

### SSL-Zertifikat

| Domain | Gültig bis |
|--------|------------|
| vault-rxfsys.duckdns.org | 27. April 2026 |

---

## Container-Konfiguration

**Datei:** `/etc/pve/lxc/103.conf`

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: vaultwarden
memory: 2048
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,hwaddr=BC:24:11:C6:9B:7C,ip=192.168.2.124/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-103-disk-0,size=8G
swap: 2048
unprivileged: 1
```

---

## Docker-Konfiguration

**Datei (im Container):** `/srv/appdata/vaultwarden/docker-compose.yml`

```yaml
version: "3.8"
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    environment:
      - WEBSOCKET_ENABLED=true
      - SIGNUPS_ALLOWED=false
      - ADMIN_TOKEN=DEIN_ADMIN_TOKEN
    volumes:
      - /srv/appdata/vaultwarden:/data
    ports:
      - "8081:80"
      - "3012:3012"
    restart: unless-stopped
```

---

## Admin-Token sichern (empfohlen)

Der Admin-Token sollte als Argon2-Hash gespeichert werden:

```bash
# Hash generieren
pct exec 103 -- docker exec -it vaultwarden /vaultwarden hash

# Interaktiv mit Passwort
pct exec 103 -- docker exec -it vaultwarden sh -c "echo 'DEIN_ADMIN_PASSWORT' | /vaultwarden hash"

# Dann in docker-compose.yml:
# ADMIN_TOKEN='$argon2id$v=19$m=65540,t=3,p=4$...'
```

---

## Nginx Proxy Manager Konfiguration

Der externe Zugriff erfolgt über Nginx Proxy Manager (CT 104):

| Parameter | Wert |
|-----------|------|
| Domain | vault-rxfsys.duckdns.org |
| Scheme | http |
| Forward IP | 192.168.2.124 |
| Forward Port | 8081 |
| SSL | Let's Encrypt (DNS Challenge) |
| Websockets | ✅ Aktiviert |
| Force SSL | ✅ Aktiviert |

---

## Clients einrichten

### Browser-Erweiterungen

1. Bitwarden-Erweiterung installieren
2. Einstellungen → Self-hosted
3. Server-URL: `https://vault-rxfsys.duckdns.org`

### Mobile Apps (iOS/Android)

1. Bitwarden App installieren
2. Anmelden → Self-hosted
3. Server-URL: `https://vault-rxfsys.duckdns.org`

---

## Verwaltung

```bash
# Status
pct exec 103 -- docker ps

# Logs
pct exec 103 -- docker logs vaultwarden --tail 50

# Neustarten
pct exec 103 -- docker restart vaultwarden

# Aktualisieren
pct exec 103 -- bash -c 'cd /srv/appdata/vaultwarden && docker compose pull && docker compose up -d'
```

---

## Firewall

**Datei:** `/etc/pve/firewall/103.fw`

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Web (nur von Nginx-Proxy)
IN ACCEPT -source 192.168.2.125 -p tcp -dport 8081 -log nolog
IN ACCEPT -source 192.168.2.125 -p tcp -dport 3012 -log nolog
IN ACCEPT -p icmp
```

---

## Backup

### 🔴 KRITISCH: Datenbank regelmäßig sichern!

```bash
# Manuelles Backup
pct exec 103 -- sqlite3 /srv/appdata/vaultwarden/db.sqlite3 ".backup /srv/appdata/vaultwarden/backup_$(date +%Y%m%d).sqlite3"

# Container-Backup
vzdump 103 --storage local --compress zstd --mode snapshot
```

### Wichtige Dateien

| Datei | Beschreibung | Priorität |
|-------|--------------|-----------|
| `/srv/appdata/vaultwarden/db.sqlite3` | Passwort-Datenbank | 🔴 Kritisch |
| `/srv/appdata/vaultwarden/config.json` | Konfiguration | 🟡 Wichtig |
| `/srv/appdata/vaultwarden/attachments/` | Datei-Anhänge | 🟡 Wichtig |
| `/srv/appdata/vaultwarden/rsa_key*` | RSA-Schlüssel | 🔴 Kritisch |

---

## Sicherheits-Hinweise

| Einstellung | Empfehlung |
|-------------|------------|
| SIGNUPS_ALLOWED | `false` (nach Registrierung) |
| ADMIN_TOKEN | Argon2-Hash verwenden |
| HTTPS | ✅ Immer über Nginx PM |
| 2FA | Für alle Benutzer aktivieren |

---

*CT 103 - Vaultwarden | Server rxfsys*