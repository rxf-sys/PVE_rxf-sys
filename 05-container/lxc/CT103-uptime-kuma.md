# CT 103 — uptime-kuma

## Spec

| Spec       | Wert                            |
|------------|---------------------------------|
| Hostname   | uptime-kuma                     |
| IP         | 192.168.2.204/24                |
| RAM        | 512 MB                          |
| CPU        | 1 Core                          |
| rootfs     | local-lvm:vm-103-disk-0, 4 GB   |
| OS         | Debian 13                       |
| Features   | nesting=1, keyctl=1             |
| MAC        | BC:24:11:A8:34:5D               |

## Services (Docker)

| Container    | Image                       | Port |
|--------------|-----------------------------|------|
| uptime-kuma  | louislam/uptime-kuma:latest | 3001 |

## Ports / Firewall

| Port | Protocol | Source-Restriction |
|------|----------|--------------------|
| 3001 | TCP      | 192.168.2.0/24    |

## URLs

- LAN: http://192.168.2.204:3001
- Public: https://monitor.rxf-sys.de

## Empfohlene Monitors

| Name             | Type       | URL                                 | Keyword                    |
|------------------|------------|-------------------------------------|----------------------------|
| PVE-UI           | HTTPS/Keyw | https://192.168.2.200:8006          | Proxmox                    |
| PBS-UI           | HTTPS/Keyw | https://192.168.2.209:8007          | Proxmox Backup Server      |
| Vaultwarden      | HTTPS      | https://vault.rxf-sys.de            | (Status 200)               |
| Admin-Dashboard  | HTTPS      | https://admin.rxf-sys.de            | (Status 200 / 302)         |
| HA               | HTTPS      | https://ha.rxf-sys.de               | (Status 200 / 302)         |
| Immich           | HTTPS      | https://photos.rxf-sys.de           | (Status 200)               |
| Jellyfin         | HTTPS      | https://media.rxf-sys.de            | (Status 200)               |

Tip: "Ignore TLS/SSL error" für interne IPs anhaken (self-signed).
