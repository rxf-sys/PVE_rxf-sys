# Dateisystem-Berechtigungen

## Unprivileged Container - UID/GID Mapping

Bei unprivileged Containern werden UIDs/GIDs um 100000 verschoben:
- Container-Root (UID 0) = Host-UID 100000
- Container-User (UID 1000) = Host-UID 101000

## Berechtigungen setzen

### Samba-Freigaben (CT 100)

```bash
# Shared und Backups: Container-Root als Besitzer
chown -R 100000:100000 /mnt/storage/shared
chown -R 100000:100000 /mnt/storage/backups
chmod -R 2770 /mnt/storage/shared
chmod -R 2770 /mnt/storage/backups
```

### Medien (CT 105 - Jellyfin)

```bash
# Jellyfin-User (UID 1000 im Container = 101000 auf Host)
chown -R 101000:101000 /mnt/storage/media
chmod -R 755 /mnt/storage/media
```

### Gemeinsamer Zugriff (Samba + Jellyfin auf /media)

Falls beide Container auf `/mnt/storage/media` zugreifen:

```bash
# Gruppe fuer gemeinsamen Zugriff
# In /etc/subgid ggf. anpassen
chown -R 100000:100000 /mnt/storage/media
chmod -R 2775 /mnt/storage/media
```

## ID-Mapping in Container-Config

Falls erweiterte Mappings noetig sind (`/etc/pve/lxc/<CTID>.conf`):

```ini
# Beispiel: UID 1000 im Container auf Host-UID 1000 mappen
lxc.idmap: u 0 100000 1000
lxc.idmap: g 0 100000 1000
lxc.idmap: u 1000 1000 1
lxc.idmap: g 1000 1000 1
lxc.idmap: u 1001 101001 64535
lxc.idmap: g 1001 101001 64535
```

Zusaetzlich in `/etc/subuid` und `/etc/subgid` auf dem Host:

```
root:1000:1
```

## Pruefbefehle

```bash
# Berechtigungen pruefen
ls -la /mnt/storage/
ls -la /mnt/storage/shared/
ls -la /mnt/storage/media/

# UID-Mapping eines Containers pruefen
cat /etc/pve/lxc/100.conf | grep -E 'idmap|mp'

# Im Container pruefen
pct exec 100 -- ls -la /srv/
```
