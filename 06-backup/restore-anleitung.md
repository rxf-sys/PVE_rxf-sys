# Restore-Anleitung

## Container aus vzdump wiederherstellen

### Ueber Web-UI

1. Storage -> local -> Content -> Backups
2. Backup auswaehlen -> Restore
3. CT-ID, Storage und Einstellungen pruefen
4. Restore starten

### Ueber CLI

```bash
# Verfuegbare Backups anzeigen
ls -la /var/lib/vz/dump/

# Container wiederherstellen (gleiche ID)
pct restore 100 /var/lib/vz/dump/vzdump-lxc-100-<DATUM>.tar.zst

# Container mit neuer ID wiederherstellen
pct restore 200 /var/lib/vz/dump/vzdump-lxc-100-<DATUM>.tar.zst

# Mit bestimmten Einstellungen wiederherstellen
pct restore 100 /var/lib/vz/dump/vzdump-lxc-100-<DATUM>.tar.zst \
  --storage local-lvm \
  --rootfs local-lvm:15
```

## Container aus PBS wiederherstellen

### Ueber Web-UI

1. Storage -> pbs -> Content
2. Backup auswaehlen -> Restore
3. Einstellungen pruefen und wiederherstellen

### Ueber CLI

```bash
# PBS-Backups auflisten
pvesm list pbs

# Aus PBS wiederherstellen
pct restore 100 pbs:backup/ct/100/<BACKUP-ID>.pxar.didx
```

## Einzelne Dateien wiederherstellen

```bash
# Backup mounten
pct mount-backup /var/lib/vz/dump/vzdump-lxc-100-<DATUM>.tar.zst

# Dateien kopieren
cp /var/lib/lxc/100/rootfs/<PFAD> /tmp/

# Backup unmounten
pct unmount-backup
```

## Restore-Test Checkliste

Regelmaessig (monatlich) testen:

- [ ] Backup aus vzdump in Test-CT wiederherstellen
- [ ] Backup aus PBS in Test-CT wiederherstellen
- [ ] Dienst im Test-CT starten und pruefen
- [ ] Netzwerk-Konnektivitaet testen
- [ ] Daten-Integritaet pruefen
- [ ] Test-CT wieder loeschen

```bash
# Test-Restore (mit temporaerer ID)
pct restore 999 /var/lib/vz/dump/vzdump-lxc-103-<DATUM>.tar.zst \
  --hostname restore-test \
  --rootfs local-lvm:8

# Testen
pct start 999
pct exec 999 -- systemctl status <DIENST>

# Aufraeumen
pct stop 999
pct destroy 999
```

## Notfall: Vaultwarden-Datenbank

Die Vaultwarden-Datenbank ist das kritischste Backup-Ziel:

```bash
# Datenbank aus Container kopieren (Backup)
pct exec 103 -- cp /srv/appdata/vaultwarden/db.sqlite3 /tmp/
pct pull 103 /tmp/db.sqlite3 /mnt/backups/vaultwarden-db-$(date +%Y%m%d).sqlite3

# Datenbank wiederherstellen
pct push 103 /mnt/backups/vaultwarden-db-<DATUM>.sqlite3 /srv/appdata/vaultwarden/db.sqlite3
pct exec 103 -- docker compose -f /srv/appdata/vaultwarden/docker-compose.yml restart
```
