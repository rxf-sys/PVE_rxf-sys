# Uptime Kuma (CT 103)

## URL

- LAN: http://192.168.2.204:3001
- Public: https://monitor.rxf-sys.de

## Setup-Hinweise

- Erste-Login-Account einmalig beim Setup angelegen
- Notification-Provider: SMTP (Strato) ODER Telegram/Discord — kann zusätzlich zu PVE/PBS-Mails konfiguriert werden

## Empfohlene Monitors

| Name             | Type            | URL                            | Keyword                 | Interval |
|------------------|-----------------|--------------------------------|-------------------------|----------|
| PVE Web-UI       | HTTP(s)-Keyword | https://192.168.2.200:8006     | `Proxmox`               | 60 s     |
| PBS Web-UI       | HTTP(s)-Keyword | https://192.168.2.209:8007     | `Proxmox Backup Server` | 60 s     |
| Admin-Dashboard  | HTTP(s)         | https://admin.rxf-sys.de       | (200)                   | 60 s     |
| Home Assistant   | HTTP(s)         | https://ha.rxf-sys.de          | (200/302)               | 60 s     |
| Vaultwarden      | HTTP(s)         | https://vault.rxf-sys.de       | (200)                   | 60 s     |
| Immich           | HTTP(s)         | https://photos.rxf-sys.de      | (200)                   | 60 s     |
| Jellyfin         | HTTP(s)         | https://media.rxf-sys.de       | (200)                   | 60 s     |
| Portfolio        | HTTP(s)         | https://portfolio.rxf-sys.de   | (200)                   | 60 s     |
| Welcome-Page     | HTTP(s)         | https://www.rxf-sys.de         | (200)                   | 60 s     |
| Orynthia         | HTTP(s)         | https://orynthia.rxf-sys.de    | (200)                   | 60 s     |
| Cloudflare-Tunnel | TCP             | 192.168.2.213 (CT 110)        | -                       | 60 s     |

Für interne Self-Signed-TLS (PVE/PBS): "Ignore TLS/SSL error" aktivieren.

## Daten

DB im Docker-Volume `uptime-kuma_data`, im CT rootfs → in vzdump enthalten.
