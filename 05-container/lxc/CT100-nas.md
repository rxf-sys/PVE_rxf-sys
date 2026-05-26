# CT 100 — nas (Samba)

## Spec

| Spec       | Wert                            |
|------------|---------------------------------|
| Hostname   | nas                             |
| IP         | 192.168.2.201/24                |
| RAM        | 1024 MB                         |
| CPU        | 1 Core                          |
| rootfs     | local-lvm:vm-100-disk-0, 8 GB   |
| OS         | Debian 13                       |
| Features   | nesting=1, unprivileged         |
| Tags       | backup                          |
| MAC        | BC:24:11:93:AE:10               |

## Bind-Mounts

| Host                          | Container          |
|-------------------------------|--------------------|
| /mnt/storage/shared           | /srv/shared        |
| /mnt/storage/media            | /srv/media         |
| /mnt/storage/backups          | /srv/backups       |
| /mnt/storage/games            | /srv/games         |

## Services

- **Samba** (smbd, nmbd) — Filesharing CIFS
- Shares: `shared`, `media`, `backups`, `games`

## Ports / Firewall

| Port    | Protocol | Service          |
|---------|----------|------------------|
| 445     | TCP      | SMB              |
| 139     | TCP      | NetBIOS Session  |
| 137-138 | UDP      | NetBIOS Name/Dgm |

`.fw` Source-Restriction: 192.168.2.0/24.

## Zugriff

```bash
# Windows
\\nas.home\shared
# Linux/macOS
smb://nas.home/shared
# CLI Mount
mount -t cifs //192.168.2.201/shared /mnt/nas -o user=USERNAME
```

## Backup

- vzdump täglich 02:00 (Job `pbs-nightly`)
- ⚠ Bind-Mount-Quellen unter /mnt/storage werden NICHT gesichert (B9 offen)

## Wartung

```bash
# Samba-Status
pct exec 100 -- systemctl status smbd nmbd

# Shares testen
pct exec 100 -- smbclient -L localhost -N
```
