# Restore-Procedures

## Einzelner CT / VM aus PBS

### Variante A — selbe ID (Original ersetzen)

⚠ Aktueller CT/VM mit der ID muss gestoppt sein, sonst Konflikt.

```bash
pct stop 108
pct destroy 108 --purge     # oder pct rollback wenn Snapshot existiert
pvesm list pbs --vmid 108   # neueste Snapshot-ID merken
pct restore 108 pbs:backup/ct/108/2026-05-24T00:02:00Z --storage local-lvm
pct start 108
```

### Variante B — als Test-VM mit neuer ID (sicher)

```bash
pvesm list pbs --vmid 108 | tail -1
# z.B. pbs:backup/ct/108/2026-05-24T17:14:44Z

# Restore als VMID 999, andere MAC + IP nicht starten
pct restore 999 pbs:backup/ct/108/2026-05-24T17:14:44Z --storage local-lvm \
            --hostname test-restore-108

# Inspect
pct config 999
pct mount 999       # rootfs mounten falls Inspektion nötig
pct unmount 999

# Cleanup
pct destroy 999 --purge
```

Bei VMs analog `qm restore`.

## Datastore-Verlust (sdb defekt)

### Erstmal: Disk neu

1. Neue 480-GB-(oder größere)-SSD an sdb-Slot anschließen
2. In VM 201 formatieren:
   ```bash
   ssh root@192.168.2.209
   mkfs.ext4 -L backups /dev/sdb1
   mount /dev/sdb1 /mnt/backups
   ```
3. Neuen Datastore anlegen (PBS-Web-UI oder CLI)

→ Alle alten Snapshots sind verloren (waren auf alter sdb).

**Lösung:** B9 — Off-Site-Backup nötig (z.B. 2. SSD als Mirror, Hetzner Storage Box, etc.).

## PBS-VM-Verlust (VM 201 defekt)

PBS-VM kann verloren gehen, sdb-Daten überleben (sind Passthrough).

1. Neue PBS-VM erstellen (siehe [../02-installation/pbs-vm-setup.md](../02-installation/pbs-vm-setup.md))
2. sdb wieder per Passthrough (`scsi1: /dev/disk/by-id/ata-Lexar_480GB_SSD_J36482R000574,backup=0,iothread=1`)
3. In neuer PBS-VM: `/dev/sdb1` mounten unter `/mnt/backups`
4. Im PBS-UI: **Datastore neu anlegen** mit Option `--reuse-datastore` (oder im Web-UI "use existing")
5. Alle alten Snapshots sind sofort wieder da
6. Token neu erzeugen für `root@pam!pve-host`, Permission `DatastoreAdmin`
7. Auf PVE-Host: `pvesm set pbs --username root@pam!pve-host --password '<neu>'`
8. Verify mit `pvesm list pbs`

## PVE-Host-Verlust

→ Disaster Recovery, siehe [../10-disaster-recovery/README.md](../10-disaster-recovery/README.md).

## Verify nach Restore

```bash
# CT-/VM-Status
pct status <id>
qm status <id>

# Im CT: Services laufen?
pct exec <id> -- systemctl --failed
pct exec <id> -- docker ps           # falls Docker-CT

# In VM: Agent funktioniert?
qm guest exec <id> -- uname -r
```
