# CT 102 — vaultwarden

## Spec

| Spec       | Wert                            |
|------------|---------------------------------|
| Hostname   | vaultwarden                     |
| IP         | 192.168.2.203/24                |
| RAM        | 512 MB                          |
| CPU        | 1 Core                          |
| rootfs     | local-lvm:vm-102-disk-0, 4 GB   |
| OS         | Debian 13                       |
| Features   | nesting=1, keyctl=1             |
| MAC        | BC:24:11:1E:DB:5B               |

## Services (Docker)

| Container    | Image                              | Port |
|--------------|------------------------------------|------|
| vaultwarden  | vaultwarden/server:latest          | 8081 |

## Ports / Firewall

| Port | Protocol | Source-Restriction               |
|------|----------|----------------------------------|
| 8081 | TCP      | 192.168.2.0/24 + .202 + .122    |

## URLs

- LAN: http://192.168.2.203:8081
- Public: https://vault.rxf-sys.de (Cloudflare Tunnel)

## Daten

- Vaultwarden-DB im Container-Volume — wird beim vzdump mitgesichert
- Wichtig: SECRET (admin token) gut aufbewahren — wird in .env / docker-compose definiert

## Backup

- vzdump täglich 02:00 → pbs
- Restore Test: siehe [../../06-backup/restore-procedures.md](../../06-backup/restore-procedures.md)
