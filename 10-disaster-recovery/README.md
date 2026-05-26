# 10 — Disaster Recovery

## Szenarien

| Szenario                              | Doku                                       |
|---------------------------------------|--------------------------------------------|
| `/var` versehentlich gelöscht         | siehe [recovery-2026-05-21.md](recovery-2026-05-21.md) (real passiert) |
| PVE-Host komplett unbenutzbar         | siehe [recovery-2026-05-21.md](recovery-2026-05-21.md) — Full Restore |
| Einzelner CT/VM kaputt                | siehe [../06-backup/restore-procedures.md](../06-backup/restore-procedures.md) |
| PBS-VM (201) defekt, sdb OK           | siehe [../06-backup/restore-procedures.md](../06-backup/restore-procedures.md) |
| sdb (PBS-Datastore-Disk) defekt       | Alle Snapshots verloren — Off-Site nötig (B9) |
| sda (/mnt/storage) defekt             | Bind-Mount-Daten verloren (B9 offen)       |
| NVMe (System) defekt                  | Komplettes Restore aus PBS + Host-Config-Backup |

## Notfall-Toolkit

| Asset                       | Speicherort                                                   |
|-----------------------------|---------------------------------------------------------------|
| PVE-Installer-ISO           | Externes Medium / Download                                    |
| PBS-Datastore               | sdb in VM 201 (intakt = alle Snapshots verfügbar)             |
| Host-Config (täglich)       | `/mnt/storage/host-configs/` (auf sda, 30 d retention)        |
| Host-Config (wöchentlich)   | PBS-Backup-Group `host/rxf-sys-config`                        |
| Strato/Cloudflare-Logins    | siehe Vaultwarden (CT 102)                                    |

## Disaster Recovery Plan

### Vollständiger Host-Verlust

1. PVE 9.x neu installieren (gleiche Version wenn möglich)
2. Statisches Netzwerk: 192.168.2.200/24, GW .1
3. **Wenn sdb noch existiert** (PBS-Datastore intakt):
   - PBS-VM aus altem Konfig recreaten (siehe [../02-installation/pbs-vm-setup.md](../02-installation/pbs-vm-setup.md))
   - sdb wieder per Passthrough
   - Datastore mit `--reuse-datastore` re-attached
4. PVE-Storage `pbs` re-konfigurieren (`/etc/pve/storage.cfg` siehe [../06-backup/pve-vzdump.md](../06-backup/pve-vzdump.md))
5. Token regenerieren + Owner-Fix für alle Groups
6. Restore aller CTs+VMs aus PBS:
   ```bash
   pvesm list pbs | grep -E '^pbs:backup' | sort -t/ -k3,3 -k4,4r | awk '!seen[$2$3]++ {print}'
   # → Latest Snapshot pro Group, dann restore in Schleife
   ```
7. Bind-Mount-Quellen wiederherstellen (falls sda intakt: nur mounten via fstab; falls nicht: aus externem Backup)
8. Post-Install-Schritte aus [../02-installation/post-install.md](../02-installation/post-install.md)
9. Verify: alle Guests laufen, alle Services erreichbar, Test-Backup

### PBS-Datastore verloren (sdb defekt, sda + Host OK)

1. Neue Disk an sdb-Slot
2. In VM 201 formatieren, `/mnt/backups` mounten
3. Neuen Datastore anlegen
4. Frische Backups erstellen (`vzdump` manuell)
5. Notification-Mail prüfen
6. ⚠ Alle alten Snapshots sind verloren!

→ Lehre: Off-Site-Backup zwingend, siehe B9.

### Einzelner Guest-Verlust

Siehe [../06-backup/restore-procedures.md](../06-backup/restore-procedures.md).

## Recovery-Cheatsheet beim Start

Nach Recovery diese Files prüfen/anlegen:

| Datei                                | Inhalt                                       |
|--------------------------------------|----------------------------------------------|
| `/etc/network/interfaces`            | vmbr0 mit 192.168.2.200/24                   |
| `/etc/hosts`                         | rxf-sys + pbs.home                           |
| `/etc/fstab`                         | /mnt/storage Mount                           |
| `/etc/pve/storage.cfg`               | pbs entry                                    |
| `/etc/pve/priv/storage/pbs.pw`       | Token-Secret                                 |
| `/etc/pve/jobs.cfg`                  | pbs-nightly Backup-Job                       |
| `/etc/pve/firewall/cluster.fw`       | Firewall enable + IPSET lan                  |
| `/etc/pve/nodes/rxf-sys/host.fw`     | Host-Firewall-Regeln                         |
| `/etc/pve/notifications.cfg`         | Strato SMTP                                  |
| `/etc/apt/sources.list.d/`           | pve-no-subscription, ohne Enterprise         |
| `/etc/apt/apt.conf.d/80pve-no-nag`   | dpkg-Hook für Nag-Patch                      |
| `/usr/local/sbin/repatch-no-nag.sh`  | Nag-Patch-Skript                             |
| `/usr/local/sbin/backup-host-config*.sh` | Host-Config-Backup-Skripte              |
| `/etc/fail2ban/jail.d/sshd-rxf-sys.local` | fail2ban-Config                         |

Alle Files sind im Host-Config-Backup enthalten — bei Restore das tar.zst auspacken nach `/` als Erstes.
