# CT 110 - Paperless-ngx (Dokumentenverwaltung)

## Übersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 110 |
| **Hostname** | paperless |
| **IP-Adresse** | 192.168.2.131 |
| **RAM** | 2048 MB |
| **CPU** | 2 Cores |
| **Disk** | 10 GB |
| **OS** | Debian Trixie |
| **Dienst** | Paperless-ngx (Docker) |

---

## Funktion

Paperless-ngx ist ein Dokumentenmanagementsystem, das physische Dokumente in ein durchsuchbares Online-Archiv verwandelt. Automatische OCR-Texterkennung, Tagging und Volltextsuche.

---

## Zugriff

| Dienst | URL |
|--------|-----|
| Web-Interface | http://192.168.2.131:8000 |
| Mit lokalem DNS | http://paperless.home:8000 |

### Zugangsdaten

| Parameter | Wert |
|-----------|------|
| Admin-Benutzer | `___________________` |
| Passwort | `___________________` |

---

## Container-Konfiguration

**Datei:** `/etc/pve/lxc/110.conf`

```ini
arch: amd64
cores: 2
features: nesting=1
hostname: paperless
memory: 2048
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,ip=192.168.2.131/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-110-disk-0,size=10G
swap: 2048
unprivileged: 1
```

---

## Docker-Konfiguration

**Datei (im Container):** `/srv/appdata/paperless/docker-compose.yml`

```yaml
version: "3.8"

services:
  broker:
    image: redis:7
    container_name: paperless-redis
    restart: unless-stopped
    volumes:
      - redisdata:/data

  db:
    image: postgres:15
    container_name: paperless-db
    restart: unless-stopped
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: paperless
      POSTGRES_USER: paperless
      POSTGRES_PASSWORD: paperless

  webserver:
    image: ghcr.io/paperless-ngx/paperless-ngx:latest
    container_name: paperless
    restart: unless-stopped
    depends_on:
      - db
      - broker
    ports:
      - "8000:8000"
    volumes:
      - data:/usr/src/paperless/data
      - media:/usr/src/paperless/media
      - ./export:/usr/src/paperless/export
      - ./consume:/usr/src/paperless/consume
    environment:
      PAPERLESS_REDIS: redis://broker:6379
      PAPERLESS_DBHOST: db
      PAPERLESS_DBUSER: paperless
      PAPERLESS_DBPASS: paperless
      PAPERLESS_DBNAME: paperless
      PAPERLESS_OCR_LANGUAGE: deu+eng
      PAPERLESS_TIME_ZONE: Europe/Berlin
      PAPERLESS_SECRET_KEY: CHANGE_ME_TO_RANDOM_STRING
      PAPERLESS_ADMIN_USER: admin
      PAPERLESS_ADMIN_PASSWORD: CHANGE_ME
      USERMAP_UID: 1000
      USERMAP_GID: 1000

volumes:
  data:
  media:
  pgdata:
  redisdata:
```

---

## Dokumente hinzufügen

### Web-Upload

1. Web-Interface öffnen
2. **Documents** → **Upload** oder Drag & Drop

### Consume-Ordner

Dokumente in `/srv/appdata/paperless/consume/` ablegen - werden automatisch verarbeitet.

### E-Mail-Import (optional)

In `docker-compose.yml` hinzufügen:

```yaml
environment:
  PAPERLESS_EMAIL_HOST: imap.example.com
  PAPERLESS_EMAIL_PORT: 993
  PAPERLESS_EMAIL_USERNAME: user@example.com
  PAPERLESS_EMAIL_PASSWORD: password
  PAPERLESS_EMAIL_FROM: user@example.com
```

---

## Verwaltung

```bash
# Container-Status
pct exec 110 -- docker ps

# Logs anzeigen
pct exec 110 -- docker logs paperless --tail 50

# Neustarten
pct exec 110 -- bash -c 'cd /srv/appdata/paperless && docker compose restart'

# Aktualisieren
pct exec 110 -- bash -c 'cd /srv/appdata/paperless && docker compose pull && docker compose up -d'

# Superuser erstellen
pct exec 110 -- docker exec -it paperless python3 manage.py createsuperuser
```

---

## OCR-Sprachen

Standard: Deutsch + Englisch (`deu+eng`)

Weitere Sprachen hinzufügen in `docker-compose.yml`:

```yaml
environment:
  PAPERLESS_OCR_LANGUAGE: deu+eng+fra+ita
```

---

## Tags & Korrespondenten

### Automatische Zuordnung

Paperless lernt aus manuellen Zuordnungen und schlägt automatisch Tags vor.

### Matching-Regeln

1. **Tags** → **Add Tag**
2. Name und Matching-Regel definieren:
   - **Match:** Text im Dokument
   - **Matching Algorithm:** Auto, Fuzzy, Regex, Exact

---

## Firewall

**Datei:** `/etc/pve/firewall/110.fw`

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Paperless Web-UI (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 8000 -log nolog

# ICMP/Ping
IN ACCEPT -p icmp
```

---

## Wichtige Pfade

| Pfad | Beschreibung |
|------|--------------|
| `/srv/appdata/paperless/` | Docker-Compose & Configs |
| `/srv/appdata/paperless/consume/` | Auto-Import-Ordner |
| `/srv/appdata/paperless/export/` | Export-Verzeichnis |
| Docker Volume `media` | Originaldokumente |
| Docker Volume `data` | Thumbnails, Index |
| Docker Volume `pgdata` | PostgreSQL-Datenbank |

---

## Backup

### Wichtig: Datenbank + Medien sichern!

```bash
# Paperless Export-Funktion nutzen (empfohlen)
pct exec 110 -- docker exec paperless document_exporter ../export

# Container-Backup
vzdump 110 --storage local --compress zstd --mode snapshot

# Docker Volumes sichern
pct exec 110 -- bash -c 'cd /srv/appdata/paperless && docker compose down'
pct exec 110 -- tar -czf /root/paperless-backup.tar.gz /var/lib/docker/volumes/paperless_*
pct exec 110 -- bash -c 'cd /srv/appdata/paperless && docker compose up -d'
```

---

## Speicherplatz

Paperless speichert:
- **Originale** (Scans/PDFs)
- **Archiv-Version** (PDF/A mit OCR-Text)
- **Thumbnails**
- **Suchindex**

Bei vielen Dokumenten: Disk-Größe auf 20-50 GB erweitern:

```bash
# Am Host
pct resize 110 rootfs +10G
pct exec 110 -- resize2fs /dev/sda
```

---

## Scanner-Integration

### Netzwerk-Scanner

Consume-Ordner per Samba/NFS freigeben und Scanner dorthin scannen lassen.

### SANE (Linux)

```bash
scanimage --format=pdf --output-file=/path/to/consume/scan.pdf
```

---

## Troubleshooting

### OCR funktioniert nicht

```bash
# Tesseract-Sprachen prüfen
pct exec 110 -- docker exec paperless tesseract --list-langs

# Logs prüfen
pct exec 110 -- docker logs paperless 2>&1 | grep -i "ocr\|error"
```

### Dokument wird nicht verarbeitet

```bash
# Consumer-Logs
pct exec 110 -- docker logs paperless 2>&1 | grep -i "consume"

# Berechtigungen im Consume-Ordner
pct exec 110 -- ls -la /srv/appdata/paperless/consume/
```

---

*CT 110 - Paperless-ngx | Server rxfsys*