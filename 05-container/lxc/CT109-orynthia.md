# CT 109 — orynthia (Finance-App)

## Spec

| Spec       | Wert                            |
|------------|---------------------------------|
| Hostname   | orynthia                        |
| IP         | 192.168.2.212/24                |
| RAM        | 4096 MB                         |
| CPU        | 1 Core                          |
| rootfs     | local-lvm:vm-109-disk-0, 24 GB (79 % belegt) |
| OS         | Debian 13                       |
| Features   | nesting=1, keyctl=1             |
| MAC        | BC:24:11:34:DE:16               |

> **Ressourcen 08/2026 erhöht:** von 2 GB/8 GB auf 4 GB/24 GB. Die rootfs ist
> trotzdem bereits zu 79 % belegt (15 von 24 GB) — der Container hat von allen
> Guests die höchste relative Belegung. Postgres-Wachstum im Auge behalten.

## Services (Docker)

Compose-File: `/opt/orynthia/docker-compose.yml` + `docker-compose.prod.yml`
.env: `/opt/orynthia/.env`

| Container          | Image                  | Port | Service                                   |
|--------------------|------------------------|------|-------------------------------------------|
| orynthia-nginx     | nginx:alpine           | 80, 443 | Reverse Proxy                          |
| orynthia-frontend  | orynthia-frontend      | 80   | Web-UI                                    |
| orynthia-backend   | orynthia-backend       | 3000 | NestJS API (Prisma + Postgres)            |
| orynthia-postgres  | postgres:16-alpine     | 5432 | DB                                        |
| orynthia-redis     | redis:7-alpine         | 6379 | Cache/Queue                               |

## ENV-Variablen (wichtig)

| Variable                   | Wert                                                           |
|----------------------------|----------------------------------------------------------------|
| POSTGRES_USER              | orynthia                                                       |
| POSTGRES_PASSWORD          | (secret in .env)                                               |
| POSTGRES_DB                | orynthia                                                       |
| DATABASE_URL               | postgresql://orynthia:<pw>@postgres:5432/orynthia?schema=public|
| REDIS_PASSWORD             | (secret)                                                       |
| JWT_SECRET, ENCRYPTION_KEY | (secrets)                                                      |
| ENABLE_BANKING_*           | Banking-API-Credentials                                        |
| FRONTEND_URL               | https://orynthia.rxf-sys.de                                    |

## URLs

- LAN: http://192.168.2.212
- Public: https://orynthia.rxf-sys.de

## Bekannte Issues

### Backend-Restart-Loop mit Prisma P1000

Symptom: `Error: P1000: Authentication failed against database server at postgres`

Fix:
```bash
# Postgres-User-Passwort an .env angleichen
PG_PASS=$(pct exec 109 -- bash -c "grep ^POSTGRES_PASSWORD /opt/orynthia/.env | cut -d= -f2-")
pct exec 109 -- docker exec orynthia-postgres psql -U orynthia -d postgres \
  -c "ALTER USER orynthia WITH PASSWORD '$PG_PASS';"
pct exec 109 -- docker restart orynthia-backend
```

Achtung: nach `.env`-Änderungen IMMER `docker compose up -d --force-recreate backend` (nicht `restart` allein).

## Wartung

```bash
pct exec 109 -- docker compose -f /opt/orynthia/docker-compose.yml -f /opt/orynthia/docker-compose.prod.yml ps
pct exec 109 -- docker logs orynthia-backend --tail 30
```

## Backup

- vzdump täglich 02:00 → pbs
- Docker-Volumes (postgres-data, redis-data) im CT rootfs → in vzdump

## bekannte Felder im /opt/orynthia/

```
/opt/orynthia/
├── docker-compose.yml
├── docker-compose.prod.yml
├── .env
├── .env.example
└── packages/
    ├── backend/      (NestJS source)
    └── frontend/     (Vue/React source)
```
