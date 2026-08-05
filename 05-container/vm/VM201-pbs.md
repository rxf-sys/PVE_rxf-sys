# VM 201 — pbs (Proxmox Backup Server)

PBS läuft als VM mit Disk-Passthrough auf die Lexar SSD (sdb).

## Spec

| Spec        | Wert                                                           |
|-------------|----------------------------------------------------------------|
| Name        | pbs                                                            |
| IP          | 192.168.2.209/24                                               |
| RAM         | 6144 MB                                                        |
| CPU         | 2 Cores (cputype=host)                                         |
| Sockets     | 1                                                              |
| scsi0       | local-lvm:vm-201-disk-0, 32 GB SSD, discard, iothread (rootfs) |
| **scsi1**   | `/dev/disk/by-id/ata-Lexar_480GB_SSD_J36482R000574`, **backup=0**, iothread, 468 GB (Disk-Passthrough für PBS-Datastore) |
| scsihw      | virtio-scsi-single                                             |
| net0        | virtio, vmbr0, firewall=1                                      |
| MAC         | BC:24:11:F4:D4:B3                                              |
| boot        | order=scsi0                                                    |
| ide2        | none, media=cdrom (CDROM detached nach Setup)                  |
| onboot      | 1                                                              |
| **startup** | **order=1** (PBS muss vor 02:00-Backup-Job verfügbar sein!)    |
| agent       | 1 (qemu-guest-agent installiert)                               |

## OS

- Proxmox Backup Server 4.2 auf Debian 13
- Kernel: 7.0.2-6-pve (Stand Mai 2026 — beim nächsten Audit in der VM prüfen)
- Repos: `pbs-no-subscription` (Enterprise disabled)

## Datastore

Siehe [../../06-backup/pbs-setup.md](../../06-backup/pbs-setup.md).

- Name: `backups`
- Path: `/mnt/backups` (sdb1 ext4)
- Größe: 460 GB
- Aktuell ~31 GB belegt von 460 GB (6,99 %), 174 Snapshots

## Services (intern in der VM)

| Service                  | Port |
|--------------------------|------|
| proxmox-backup-proxy     | 8007 (Web-UI + API) |
| proxmox-backup-daily-update.timer | (daily 05:40) |
| pve-firewall (PVE-FW über VM-Config) | gesteuert von Host |
| qemu-guest-agent         | (intern via socket) |

## URLs

- LAN: https://192.168.2.209:8007
- Public: https://pbs.rxf-sys.de

## Token-Verwaltung

- `root@pam!pve-host` — DatastoreAdmin auf `/datastore/backups` (für vzdump vom PVE-Host)
- `dashboard@pbs!dashboard` — DatastoreReader auf `/datastore/backups` (für Admin-Dashboard)
- User `dashboard@pbs` braucht **gleiche ACL** wegen Privilege-Separation

Token-Secret auf Host: `/etc/pve/priv/storage/pbs.pw`

## Notifications

SMTP-Endpoint `strato` (analog Host), Matcher `to-strato`:

```bash
qm guest exec 201 -- proxmox-backup-manager notification endpoint smtp list
qm guest exec 201 -- proxmox-backup-manager notification matcher list
```

## Wartung

```bash
# Updates in PBS-VM
qm guest exec 201 -- bash -c 'apt update && apt -y dist-upgrade'

# Datastore-Status
qm guest exec 201 -- proxmox-backup-manager garbage-collection list
qm guest exec 201 -- proxmox-backup-manager prune list
qm guest exec 201 -- df -h /mnt/backups

# Reboot (PBS-Storage ~30s nicht verfügbar)
qm reboot 201

# Notruf direkt in VM
ssh root@192.168.2.209
```

## Backup VON PBS-VM selbst?

Aktuell: **NEIN** — `exclude 201` im vzdump-Job (logisch, PBS sichert die anderen, nicht sich selbst).

Bei totalem Verlust der VM müssten neue PBS-VM mit selbem Datastore (`--reuse-datastore` Option) erstellt werden — sdb mit allen Daten ist Disk-Passthrough, also separat von der VM-Disk.
