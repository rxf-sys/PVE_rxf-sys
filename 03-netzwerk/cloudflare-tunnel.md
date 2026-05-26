# Cloudflare Tunnel

## Setup

- Tunnel-Name: `rxf-sys-home`
- Tunnel-ID: `ef369228-8ad4-47f9-85bf-5b3dbaf4be26`
- Cloudflared läuft als Docker-Container in **CT 104** (`docker-host`)
- Token aus ENV-Var `CF_TUNNEL_TOKEN`
- Compose-File: `/var/lib/docker/volumes/portainer_data/_data/compose/7/docker-compose.yml`

```yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CF_TUNNEL_TOKEN}
    environment:
      - TZ=Europe/Berlin
    networks:
      - tunnel
```

## Public Hostnames (12)

| #  | Hostname                  | Origin                                  | Notiz                                |
|----|---------------------------|-----------------------------------------|--------------------------------------|
| 1  | admin.rxf-sys.de          | http://192.168.2.202:80                 | Admin-Dashboard (CT 101 frontend)    |
| 2  | ha.rxf-sys.de             | http://192.168.2.208:8123               | **HTTP Host Header: ha.rxf-sys.de** + HA `trusted_proxies` |
| 3  | media.rxf-sys.de          | http://192.168.2.207:8096               | Jellyfin (CT 106)                    |
| 4  | photos.rxf-sys.de         | http://192.168.2.205:2283               | Immich (CT 104 docker)               |
| 5  | monitor.rxf-sys.de        | http://192.168.2.204:3001               | Uptime Kuma (CT 103)                 |
| 6  | vault.rxf-sys.de          | http://192.168.2.203:8081               | Vaultwarden (CT 102)                 |
| 7  | pbs.rxf-sys.de            | https://192.168.2.209:8007              | PBS (VM 201), TLS-Verify off (self-signed) |
| 8  | portfolio.rxf-sys.de      | http://192.168.2.210:80                 | Portfolio Caddy (CT 107)             |
| 9  | pve.rxf-sys.de            | https://192.168.2.200:8006              | PVE-UI, TLS-Verify off               |
| 10 | www.rxf-sys.de            | http://192.168.2.211:80                 | Welcome-Page (CT 108)                |
| 11 | orynthia.rxf-sys.de       | http://192.168.2.212:80                 | Orynthia (CT 109 nginx)              |
| 12 | hooks.rxf-sys.de          | http://192.168.2.211:9000               | Webhooks-Endpoint (CT 108)           |

Catch-all: `http_status:404`

## HA-spezifische Konfiguration

Damit `ha.rxf-sys.de` funktioniert, in HA `configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.2.205    # CT 104 cloudflared
    - 172.16.0.0/12
    - 172.17.0.0/16
```

Cloudflare-Route-Settings:
- HTTP Host Header: `ha.rxf-sys.de`

## Cloudflare API-Token (für Admin-Dashboard)

Token `CF_API_TOKEN` in CT 101 `.env`. Permissions:
- Account → Cloudflare Tunnel: Read
- Account → Access: Apps and Policies: Read
- Account → Account Audit Logs: Read (für Access-Audit-Log-Tile)
- Zone → DNS: Read
- Zone → SSL and Certificates: Read

## Tunnel-Token rotieren (falls nötig)

1. Im Cloudflare-Dashboard: Networks → Tunnels → Tunnel öffnen
2. Configure → Refresh Token (falls Button verfügbar)
3. Falls nicht: Tunnel löschen + neu anlegen (verliert alle Routes)
4. Neuer Token in CT 104:
   ```bash
   nano /var/lib/docker/volumes/portainer_data/_data/compose/7/stack.env
   # CF_TUNNEL_TOKEN=<neu>
   cd /var/lib/docker/volumes/portainer_data/_data/compose/7/
   docker compose up -d --force-recreate cloudflared
   ```

## Tests

```bash
for h in admin ha media photos monitor vault pbs portfolio pve www orynthia hooks; do
  printf "%-25s " "$h.rxf-sys.de"
  curl -k -sS --max-time 5 -o /dev/null -w "HTTP %{http_code}\n" https://$h.rxf-sys.de/
done
```
