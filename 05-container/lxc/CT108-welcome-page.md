# CT 108 — welcome-page

Statische Welcome-Page über Caddy. Plus Webhook-Endpoint (hooks.rxf-sys.de).

## Spec

| Spec       | Wert                            |
|------------|---------------------------------|
| Hostname   | welcome-page                    |
| IP         | 192.168.2.211/24                |
| RAM        | 512 MB                          |
| CPU        | 1 Core                          |
| rootfs     | local-lvm:vm-108-disk-0, 8 GB   |
| OS         | Debian 13                       |
| Features   | nesting=1                       |
| Tags       | website                         |
| MAC        | BC:24:11:4E:FA:F0               |

## Services

| Service | Port | Verwendung                                |
|---------|------|-------------------------------------------|
| Caddy   | 80   | Welcome-Page (`www.rxf-sys.de`, Apex)     |
| Hooks   | 9000 | Webhook-Receiver (`hooks.rxf-sys.de`)     |

## URLs

- LAN: http://192.168.2.211
- Public: https://www.rxf-sys.de (Welcome-Page)
- Public Webhooks: https://hooks.rxf-sys.de

## Wartung

Analog [CT 107](CT107-portfolio.md):

```bash
pct exec 108 -- systemctl status caddy
pct exec 108 -- journalctl -u caddy --since '1 hour ago' | tail
```

## Backup

- vzdump täglich 02:00 → pbs
