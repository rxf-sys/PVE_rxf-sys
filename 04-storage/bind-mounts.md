# Bind-Mounts (CT → /mnt/storage)

## Quelle: /mnt/storage

```
/mnt/storage/
├── shared/             # general purpose share (Samba)
├── media/              # Movies, Series, Music (Jellyfin + Samba)
├── backups/            # User-Backups (Samba)
├── games/              # Game-Saves (Samba)
├── immich/             # Immich-Datenverzeichnis (Photos)
├── extra-backups/      # manuelle Ablage
├── host-configs/       # /usr/local/sbin/backup-host-config.sh dest
└── lost+found/
```

## Mount-Tabelle pro CT

| Quelle (Host)               | Ziel im Container          | CTs              |
|-----------------------------|----------------------------|------------------|
| /mnt/storage/shared         | /srv/shared                | 100              |
| /mnt/storage/media          | /srv/media                 | 100              |
| /mnt/storage/media          | /media                     | 106 (Jellyfin)   |
| /mnt/storage/backups        | /srv/backups               | 100              |
| /mnt/storage/games          | /srv/games                 | 100              |
| /mnt/storage/immich         | /srv/immich-data           | 104              |

CT-Configs einsehen via:
```bash
for id in 100 101 102 103 104 106 107 108 109; do
  echo "==== CT $id ===="
  pct config $id | grep -E '^mp[0-9]+:'
done
```

## Wichtig: Bind-Mount mit unprivileged CTs

Alle CTs laufen `unprivileged: 1`. Linux-UID-Mapping:
- Host-UID 100000-165535 ↔ CT-UID 0-65535
- D.h. `chown 100033:100033 /mnt/storage/xxx` auf Host = `chown 33:33 (www-data)` aus Sicht des Containers

Wenn `chmod`/`chown` von außen nötig, IMMER über Host-Side-IDs (100000 + container-uid).

## Hot-Detach: Bind-Mount entfernen

```bash
# Config aus pct entfernen (Container läuft weiter mit aktivem Mount):
pct set <vmid> --delete mpX

# Container muss REBOOTET werden damit der Mount tatsächlich verschwindet:
pct reboot <vmid>

# Erst danach kann Quelle entfernt werden:
rm -rf /mnt/storage/<pfad>
```

Vorsicht: `pct restart` existiert NICHT, korrekt ist `pct reboot`.
