# Admin-Dashboard (rxf-admin)

Selbstgebautes Dashboard in CT 101.

## Stack

- Backend: NestJS (TypeScript) — Container `rxf-admin-backend` (Port 3000)
- Frontend: Vite SPA hinter nginx — Container `rxf-admin-web` (Port 80)
- Datenquelle: PVE-API + PBS-API + UniFi-API + Cloudflare-API
- Auth: lokale Accounts (Argon2 + SQLite-Session-Cookie)
- Compose: `/opt/rxf-admin/infrastructure/docker-compose.yml`
- ENV: `/opt/rxf-admin/infrastructure/.env`

## Was zeigt das Dashboard

- **System**: Host-Status, Last, RAM, Storage-Auslastung
- **Services**: CT/VM-Liste mit Status, Resource-Verbrauch
- **Tunnel**: Cloudflare-Tunnel-Connectors + Routes
- **Backups**: PBS-Datastore-Inhalt, GC/Prune/Verify-Last-Run, Snapshot-Liste
- **Network**: UniFi-Clients, Devices, WAN-IP
- **Certs**: SSL-Cert-Status der Public-Domains
- **Storage by Guest**: Heatmap der Backups pro VMID + Zeit
- **Access Audit**: Cloudflare-Access-Login-Log (benötigt Account-Audit-Logs Scope)

## Token-Anforderungen

| Token              | Wo                  | Permissions                                                 |
|--------------------|---------------------|-------------------------------------------------------------|
| `admin-dashboard@pve!api`     | PVE                  | DashboardRO Role auf `/` (privsep=0) |
| `dashboard@pbs!dashboard`     | PBS-VM (in VM 201)   | DatastoreReader auf `/datastore/backups` (User + Token!) |
| `CF_API_TOKEN`                | Cloudflare-Account   | Tunnel Read, Access Apps and Policies Read, Account Audit Logs Read, Zone DNS Read, Zone SSL Read |
| `UNIFI_API_KEY`               | UniFi UCG/UDM        | Local-Admin Read-Only                |

Detail: siehe [../08-sicherheit/tokens.md](../08-sicherheit/tokens.md).

## Wichtigste API-Endpoints (Backend → externe APIs)

```
GET https://192.168.2.200:8006/api2/json/nodes
GET https://192.168.2.200:8006/api2/json/nodes/rxf-sys/lxc
GET https://192.168.2.200:8006/api2/json/nodes/rxf-sys/qemu
GET https://192.168.2.200:8006/api2/json/nodes/rxf-sys/storage
GET https://192.168.2.200:8006/api2/json/nodes/rxf-sys/qemu/<id>/agent/network-get-interfaces
GET https://192.168.2.209:8007/api2/json/admin/datastore/backups/snapshots
GET https://192.168.2.209:8007/api2/json/status/datastore-usage
GET https://api.cloudflare.com/client/v4/accounts/<id>/cfd_tunnel/<id>
GET https://api.cloudflare.com/client/v4/accounts/<id>/access/logs/access_requests
GET https://192.168.2.1/proxy/network/integration/v1/sites
```

## Bekannte Failure-Modes

| Symptom                              | Ursache                                                         | Fix                                                   |
|--------------------------------------|-----------------------------------------------------------------|-------------------------------------------------------|
| 401 von PVE/PBS                      | Container hat ALTE ENV-Vars (compose restart greift nicht)      | `docker compose up -d --force-recreate backend`       |
| 403 von PBS `/snapshots`             | Token-User hat keine ACL (Privilege Separation)                 | User AUCH ACL `DatastoreReader` geben                 |
| 403 von PVE `/qemu/.../agent/...`    | Role fehlt `VM.GuestAgent.Audit`                                | `pveum role modify DashboardRO --privs '...,VM.GuestAgent.Audit'` |
| 403 CF `/access/logs/access_requests`| Token-Scope `Account Audit Logs Read` fehlt                     | Token im CF-Dashboard editieren                       |

## Cache-TTLs

In `.env`:
```
CACHE_TTL_SYSTEM=15
CACHE_TTL_SERVICES=30
CACHE_TTL_TUNNEL=30
CACHE_TTL_PBS=60
CACHE_TTL_UNIFI=30
CACHE_TTL_CERTS=600
```

→ Daten werden bis zu 60 s alt zwischengespeichert. Nach Config-Änderungen → backend restart oder warten.

## Logs / Status

```bash
pct exec 101 -- docker logs rxf-admin-backend --tail 50
pct exec 101 -- docker compose -f /opt/rxf-admin/infrastructure/docker-compose.yml ps
```
