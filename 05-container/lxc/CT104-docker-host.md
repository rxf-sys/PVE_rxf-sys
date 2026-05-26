# CT 104 — docker-host

Multi-Service Docker-CT. Beherbergt die größten Stacks.

## Spec

| Spec       | Wert                            |
|------------|---------------------------------|
| Hostname   | docker-host                     |
| IP         | 192.168.2.205/24                |
| RAM        | 4096 MB                         |
| CPU        | 2 Cores                         |
| rootfs     | local-lvm:vm-104-disk-0, 20 GB  |
| OS         | Debian 13                       |
| Features   | nesting=1, keyctl=1             |
| Tags       | media, website                  |
| MAC        | BC:24:11:23:38:7B               |

## Bind-Mounts

| Host                  | Container             | Inhalt                  |
|-----------------------|-----------------------|-------------------------|
| /mnt/storage/immich   | /srv/immich-data      | Immich-Photos/Library   |

(Paperless-Mount wurde in 05/2026 entfernt — wird nicht genutzt.)

## Docker-Stacks

Verwaltet via **Portainer** (port 9000/9443).

### Stack 6 — Immich (`/var/lib/docker/volumes/portainer_data/_data/compose/6/`)

| Container                | Image                                   | Port      |
|--------------------------|-----------------------------------------|-----------|
| immich_server            | ghcr.io/immich-app/immich-server        | 2283      |
| immich_machine_learning  | ghcr.io/immich-app/immich-ml            | (intern)  |
| immich_postgres          | tensorchord/pgvecto-rs                  | 5432      |
| immich_redis             | redis:alpine                            | 6379      |

### Stack 7 — Cloudflared

| Container   | Image                          | Befehl                                          |
|-------------|--------------------------------|-------------------------------------------------|
| cloudflared | cloudflare/cloudflared:latest  | `tunnel --no-autoupdate run --token $CF_TUNNEL_TOKEN` |

Token in `stack.env` als `CF_TUNNEL_TOKEN`.

### Portainer

| Container | Image                  | Ports         |
|-----------|------------------------|---------------|
| portainer | portainer/portainer-ce | 9000 + 9443   |

## Ports / Firewall (104.fw)

| Port | Protocol | Source                  | Service             |
|------|----------|-------------------------|---------------------|
| 9000 | TCP      | 192.168.2.0/24          | Portainer HTTP      |
| 9443 | TCP      | 192.168.2.0/24          | Portainer HTTPS     |
| 2283 | TCP      | 192.168.2.0/24          | Immich              |
| 8000 | TCP      | 192.168.2.0/24          | (war Paperless, ungenutzt) |
| ALL  | TCP      | 192.168.2.202 (Admin-Dashboard) | volle Erreichbarkeit für Health-Checks |

## URLs

- Portainer: http://192.168.2.205:9000 oder https://192.168.2.205:9443
- Immich (LAN): http://192.168.2.205:2283
- Immich (Public): https://photos.rxf-sys.de
- Cloudflared (outbound only — keine eigene URL)

## Wichtige Operationen

```bash
# Status aller Container
pct exec 104 -- docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# Cloudflared-Restart (nach Token-Tausch)
pct exec 104 -- bash -c 'cd /var/lib/docker/volumes/portainer_data/_data/compose/7 && docker compose up -d --force-recreate cloudflared'

# Immich-Update
pct exec 104 -- bash -c 'cd /var/lib/docker/volumes/portainer_data/_data/compose/6 && docker compose pull && docker compose up -d'

# CT reboot (Tunnel ~10s down)
pct reboot 104
```

## Backup

- vzdump täglich 02:00 → pbs (inkl. /mnt/storage/immich? NEIN, bind-mounts sind NICHT in vzdump)
- Immich-Daten unter /mnt/storage/immich sind NICHT in PBS — siehe B9 offenes Backup
- Docker-Volumes (postgres-Data etc.) sind im CT rootfs → werden mit vzdump gesichert
