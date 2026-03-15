# CT 111 - Finanzguru / Orynthia (Finanzverwaltung)

## Uebersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 111 |
| **Hostname** | finance |
| **IP-Adresse** | 192.168.2.132 |
| **RAM** | 3072 MB |
| **CPU** | 2 Cores |
| **Disk** | 10 GB |
| **OS** | Debian Trixie |
| **Dienst** | Finanzguru (Docker) |

---

## Funktion

Eigene Finanzmanagement-Anwendung (Monorepo "Orynthia"):
- **Backend:** NestJS (Node.js) mit Prisma ORM
- **Frontend:** React + Vite
- **Datenbank:** PostgreSQL 16
- **Cache:** Redis 7
- **Reverse Proxy:** Nginx (intern)
- **Build-System:** Turbo (Monorepo)

---

## Zugriff

| Dienst | URL |
|--------|-----|
| Web-Interface | http://192.168.2.132:8080 |
| Mit lokalem DNS | http://finance.home:8080 |
| Backend API | http://192.168.2.132:3000/api (intern) |

---

## Container-Konfiguration

**Datei:** `/etc/pve/lxc/111.conf`

```ini
arch: amd64
cores: 2
features: nesting=1,keyctl=1
hostname: finance
memory: 3072
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,ip=192.168.2.132/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-111-disk-0,size=10G
swap: 0
unprivileged: 1
cpulimit: 2
```

---

## Docker-Konfiguration

**Verzeichnis:** `/srv/appdata/Orynthia/`

### Struktur

```
/srv/appdata/Orynthia/
├── .env                    # Umgebungsvariablen (Passwoerter!)
├── docker-compose.yml      # Entwicklung
├── docker-compose.prod.yml # Produktion
├── nginx/
│   └── nginx.conf          # Reverse Proxy Config
├── packages/
│   ├── backend/            # NestJS Backend
│   │   └── Dockerfile
│   └── frontend/           # React Frontend
│       └── Dockerfile
├── package.json
├── pnpm-workspace.yaml
└── turbo.json
```

### Docker Services

| Service | Image | Port (intern) | Port (extern) |
|---------|-------|---------------|----------------|
| postgres | postgres:16-alpine | 5432 | - (nur intern) |
| redis | redis:7-alpine | 6379 | - (nur intern) |
| backend | Custom (NestJS) | 3000 | 3000 |
| frontend | Custom (React) | 5173 | 5173 |
| nginx | nginx:alpine | 80 | 8080 |

### Starten

```bash
# Entwicklung
pct exec 111 -- bash -c 'cd /srv/appdata/Orynthia && docker compose up --build -d'

# Produktion
pct exec 111 -- bash -c 'cd /srv/appdata/Orynthia && docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d'
```

### Umgebungsvariablen (.env)

```bash
# Datenbank
POSTGRES_USER=finanzguru
POSTGRES_PASSWORD=DEIN_DB_PASSWORT
POSTGRES_DB=finanzguru

# Redis
REDIS_PASSWORD=DEIN_REDIS_PASSWORT

# Backend
JWT_SECRET=DEIN_JWT_SECRET
```

---

## Verwaltung

```bash
# Status pruefen
pct exec 111 -- docker ps

# Logs anzeigen
pct exec 111 -- docker logs finanzguru-backend --tail 50
pct exec 111 -- docker logs finanzguru-nginx --tail 50

# Neustarten
pct exec 111 -- bash -c 'cd /srv/appdata/Orynthia && docker compose restart'

# Aktualisieren (aus Git)
pct exec 111 -- bash -c 'cd /srv/appdata/Orynthia && git pull && docker compose up --build -d'

# Datenbank-Migrationen
pct exec 111 -- docker exec finanzguru-backend npx prisma migrate deploy

# Datenbank-Shell
pct exec 111 -- docker exec -it finanzguru-postgres psql -U finanzguru
```

---

## Firewall

**Datei:** `/etc/pve/firewall/111.fw`

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Nginx Web-UI (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 8080 -log nolog

# Node-Exporter (Monitoring)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 9100 -log nolog

# ICMP/Ping
IN ACCEPT -p icmp
```

---

## Wichtige Pfade

| Pfad | Beschreibung |
|------|--------------|
| `/srv/appdata/Orynthia/` | Anwendungs-Root (Git-Repo) |
| `/srv/appdata/Orynthia/.env` | Umgebungsvariablen |
| `/srv/appdata/Orynthia/packages/backend/` | NestJS Backend |
| `/srv/appdata/Orynthia/packages/frontend/` | React Frontend |
| Docker Volume `postgres_data` | PostgreSQL-Datenbank |
| Docker Volume `redis_data` | Redis-Cache |

---

## Backup

```bash
# Container-Backup (inkl. Docker Volumes)
vzdump 111 --storage backup-ssd --compress zstd --mode snapshot

# Nur Datenbank sichern
pct exec 111 -- docker exec finanzguru-postgres pg_dump -U finanzguru finanzguru > /root/finanzguru-db.sql

# Nur App-Daten sichern
pct exec 111 -- tar -czf /root/finanzguru-backup.tar.gz /srv/appdata/Orynthia/.env
```

---

*CT 111 - Finanzguru | Server rxfsys*
