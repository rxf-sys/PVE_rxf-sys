# CT 107 — portfolio

Statische Portfolio-Website über Caddy.

## Spec

| Spec       | Wert                            |
|------------|---------------------------------|
| Hostname   | portfolio                       |
| IP         | 192.168.2.210/24                |
| RAM        | 512 MB                          |
| CPU        | 1 Core                          |
| rootfs     | local-lvm:vm-107-disk-0, 8 GB   |
| OS         | Debian 13                       |
| Features   | nesting=1                       |
| Tags       | website                         |
| MAC        | BC:24:11:7E:58:D8               |

## Services

| Service | Port | Notiz                              |
|---------|------|------------------------------------|
| Caddy   | 80   | HTTP (TLS macht Cloudflare)        |

Caddy-Config: vermutlich unter `/etc/caddy/Caddyfile` — siehe in CT.

## URLs

- LAN: http://192.168.2.210
- Public: https://portfolio.rxf-sys.de

## Wartung

```bash
pct exec 107 -- systemctl status caddy
pct exec 107 -- caddy validate --config /etc/caddy/Caddyfile
pct exec 107 -- caddy reload --config /etc/caddy/Caddyfile

# Logs
pct exec 107 -- journalctl -u caddy --since '1 hour ago' | tail -20
```

## Backup

- vzdump täglich 02:00 → pbs (Caddyfile + Site-Files im rootfs sind dabei)
