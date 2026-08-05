# Bind-Mounts (CT → /mnt/storage)

## Quelle: /mnt/storage

```
/mnt/storage/
├── shared/             # general purpose share (Samba)
├── media/              # Movies, Series, Music (Jellyfin + Samba)
├── backups/            # User-Backups (Samba)
├── games/              # Game-Saves (Samba)
├── immich/             # VERWAIST — CT 104 aufgeloest, Immich entfernt
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
| /mnt/storage/immich         | (kein Mount mehr)          | ~~104~~ entfallen |

CT-Configs einsehen via:
```bash
for id in 100 101 102 103 105 106 107 108 109 110 111; do
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

## Verwaiste Daten: /mnt/storage/immich

Mit der Auflösung von CT 104 ist der Bind-Mount `/srv/immich-data` entfallen,
das Quellverzeichnis `/mnt/storage/immich` liegt aber weiter auf sda1 (Stand
05.08.2026, Verzeichnis vom 03.05.2026). Es ist an keinen Guest mehr gemountet.

Vor dem Löschen die Größe prüfen und entscheiden, ob die Fotos noch gebraucht
werden — `/mnt/storage` ist zu 58 % belegt, akuter Druck besteht also nicht:

```bash
du -sh /mnt/storage/immich
ls -la /mnt/storage/immich
```

Es gibt **kein separates Backup dieser Daten** — `/mnt/storage` ist laut
[../01-hardware/disks.md](../01-hardware/disks.md) nicht in der Backup-Kette.
Wer die Bibliothek behalten will, sichert sie vorher weg.
