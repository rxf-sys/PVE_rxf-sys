# CT 101 — admin-dashboard (rxf-admin)

## Spec

| Spec       | Wert                            |
|------------|---------------------------------|
| Hostname   | admin-dashboard                 |
| IP         | 192.168.2.202/24                |
| RAM        | 2048 MB                         |
| CPU        | 1 Core                          |
| rootfs     | local-lvm:vm-101-disk-0, 16 GB  |
| OS         | Debian 13                       |
| Features   | nesting=1, unprivileged         |
| Tags       | website                         |
| MAC        | BC:24:11:CA:C5:F5               |

## Services (Docker)

| Container          | Image                          | Port | Service                   |
|--------------------|--------------------------------|------|---------------------------|
| rxf-admin-web      | rxf-sys/admin-web              | 80   | Vite/Nginx Frontend (SPA) |
| rxf-admin-backend  | rxf-sys/admin-backend          | 3000 | NestJS API                |

Stack: `/opt/rxf-admin/infrastructure/docker-compose.yml`

## Environment

Datei: `/opt/rxf-admin/infrastructure/.env`

Wichtige Variables:
| Variable                  | Beispielwert                                  |
|---------------------------|-----------------------------------------------|
| NODE_ENV                  | production                                    |
| AUTH_ENABLED              | true                                          |
| BOOTSTRAP_ADMIN_USER      | info@rxf-sys.de                               |
| PROXMOX_HOST              | 192.168.2.200                                 |
| PROXMOX_TOKEN_ID          | admin-dashboard@pve!api                       |
| PROXMOX_TOKEN_SECRET      | (secret)                                      |
| PBS_HOST                  | 192.168.2.209                                 |
| PBS_TOKEN_ID              | dashboard@pbs!dashboard                       |
| PBS_TOKEN_SECRET          | (secret)                                      |
| UNIFI_HOST                | 192.168.2.1                                   |
| UNIFI_API_KEY             | (secret)                                      |
| CF_ACCOUNT_ID             | 66464b06aae97e8cdfce53397aa03d99              |
| CF_ZONE_ID                | 7f04aeadfc70c05bf2b4823788a0969a              |
| CF_API_TOKEN              | (secret)                                      |
| CF_TUNNEL_ID              | ef369228-8ad4-47f9-85bf-5b3dbaf4be26          |
| FRONTEND_URL              | https://admin.rxf-sys.de                      |

⚠ Auth: lokale Accounts (Argon2 + SQLite-Session-Cookie), **nicht** mehr Cloudflare Access.

## Token-Permissions

Siehe [../../08-sicherheit/tokens.md](../../08-sicherheit/tokens.md).

- PVE-Token `admin-dashboard@pve!api` mit Role `DashboardRO` auf `/`:
  Datastore.Audit, Pool.Audit, Sys.Audit, VM.Audit, VM.GuestAgent.Audit, VM.PowerMgmt
- PBS-Token `dashboard@pbs!dashboard` mit Role `DatastoreReader` auf `/datastore/backups`
  (User `dashboard@pbs` braucht zusätzlich gleiche ACL wegen Privilege-Separation!)

## Ports / Firewall

- Frontend: 80 (intern, vom Cloudflare-Tunnel routed)
- Backend: 3000 (intern, vom Frontend gepollt)
- Keine `.fw`-Datei → keine guest-firewall

## URLs

- LAN: http://192.168.2.202
- Public: https://admin.rxf-sys.de (Cloudflare Tunnel)

## Wichtige Operationen

```bash
# Logs
pct exec 101 -- docker logs rxf-admin-backend --tail 50
pct exec 101 -- docker logs rxf-admin-web --tail 30

# Restart bei Config-Änderung (.env)
# IMPORTANT: 'restart' liest .env NICHT neu, nur 'up -d --force-recreate'
pct exec 101 -- bash -c 'cd /opt/rxf-admin/infrastructure && docker compose up -d --force-recreate backend'

# Status
pct exec 101 -- docker compose -f /opt/rxf-admin/infrastructure/docker-compose.yml ps
```

## Recovery

Bei Token-Verlust: siehe [../../08-sicherheit/tokens.md](../../08-sicherheit/tokens.md) — beide Tokens neu generieren, in .env updaten, `docker compose up -d --force-recreate backend`.
