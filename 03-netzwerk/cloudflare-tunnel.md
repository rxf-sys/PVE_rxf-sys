# Cloudflare Tunnel

## Setup

- Tunnel-Name: `rxf-sys-home`
- Tunnel-ID: `ef369228-8ad4-47f9-85bf-5b3dbaf4be26`
- Cloudflared läuft **nativ als systemd-Service in CT 110** (`cloudflared`, 192.168.2.213)
- Seit 08/2026. Vorher: Docker-Container in CT 104 (`docker-host`, .205) — CT 104
  existiert nicht mehr, siehe [../05-container/README.md](../05-container/README.md)

```bash
pct exec 110 -- systemctl status cloudflared
pct exec 110 -- journalctl -u cloudflared --since '1 hour ago' --no-pager
```

Der Container hat keine eingehenden Listener; der Tunnel baut ausschließlich
ausgehende QUIC-Verbindungen zur Cloudflare-Edge auf. Lokal lauschen nur
`127.0.0.1:20241` und `127.0.0.1:20242` (cloudflared-Metrics).

## Public Hostnames (12)

| #  | Hostname                  | Origin                                  | Notiz                                |
|----|---------------------------|-----------------------------------------|--------------------------------------|
| 1  | admin.rxf-sys.de          | http://192.168.2.202:80                 | Admin-Dashboard (CT 101 frontend)    |
| 2  | ha.rxf-sys.de             | http://192.168.2.208:8123               | **liefert aktuell 400** — HA `trusted_proxies` noch auf .205, siehe unten |
| 3  | media.rxf-sys.de          | http://192.168.2.207:8096               | Jellyfin (CT 106)                    |
| 4  | photos.rxf-sys.de         | http://192.168.2.205:2283               | **TOT** — Immich lief in CT 104, Origin existiert nicht mehr → 502 |
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
    - 192.168.2.213    # CT 110 cloudflared
    - 172.16.0.0/12
    - 172.17.0.0/16
```

Cloudflare-Route-Settings:
- HTTP Host Header: `ha.rxf-sys.de`

### Stand 05.08.2026: 400 statt 200

`ha.rxf-sys.de` antwortet mit **HTTP 400**. Ursache ist mit hoher
Wahrscheinlichkeit, dass in HA noch die alte Cloudflared-IP `192.168.2.205`
als `trusted_proxy` steht, während der Tunnel inzwischen aus CT 110
(`192.168.2.213`) kommt. HA weist Requests von nicht vertrauten Proxys mit 400
ab. Details und Prüfschritte:
[../05-container/vm/VM200-homeassistant.md](../05-container/vm/VM200-homeassistant.md).

## Tote Origin aufräumen: photos.rxf-sys.de

Mit CT 104 sind Immich und Portainer ersatzlos entfernt worden. Der Public
Hostname `photos.rxf-sys.de` zeigt aber weiterhin auf `192.168.2.205:2283` und
liefert deshalb **502 Bad Gateway**.

Zwei Wege:

1. **Route löschen** (wenn Immich nicht zurückkommt): Cloudflare-Dashboard →
   Networks → Tunnels → `rxf-sys-home` → Public Hostname `photos` entfernen,
   danach auch den DNS-Eintrag prüfen.
2. **Neue Origin eintragen**, falls Immich anderswo wieder aufgesetzt wird.

Solange die Route steht, ist sie zusätzlich ein Risiko: Wird `192.168.2.205`
irgendwann an einen neuen Guest vergeben, wird dieser unbeabsichtigt öffentlich
erreichbar.

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
4. Neuen Token in CT 110 hinterlegen und den Service neu starten:
   ```bash
   pct exec 110 -- systemctl status cloudflared      # aktuellen Zustand + Config-Pfad
   # Token in der cloudflared-Konfiguration ersetzen, dann:
   pct exec 110 -- systemctl restart cloudflared
   pct exec 110 -- journalctl -u cloudflared -n 30 --no-pager
   ```

## Tests

```bash
for h in admin ha media photos monitor vault pbs portfolio pve www orynthia hooks; do
  printf "%-25s " "$h.rxf-sys.de"
  curl -k -sS --max-time 5 -o /dev/null -w "HTTP %{http_code}\n" https://$h.rxf-sys.de/
done
```
