# PBS-VM Setup (VM 201)

PBS läuft NICHT auf dem Host, sondern in einer eigenen VM mit Disk-Passthrough auf die Lexar-SSD (sdb).

## Warum als VM und nicht auf dem Host?

- Trennung Backup-Infrastruktur ↔ Hypervisor (PBS-Pakete wurden nach Recovery ausgelagert)
- sdb (Lexar SSD) komplett für PBS-Datastore, ohne Host-Beeinträchtigung
- VM-Snapshot-tauglich
- PBS-Updates ohne Host-Update-Risiko

## VM-Konfiguration

Siehe vollständige Config in [../05-container/vm/VM201-pbs.md](../05-container/vm/VM201-pbs.md).

Key-Punkte:
- VM 201, name `pbs`
- 2 Cores, 4 GB RAM, 32 GB rootfs (local-lvm)
- **scsi1 = Disk-Passthrough** `/dev/disk/by-id/ata-Lexar_480GB_SSD_J36482R000574` (468 GB, `backup=0` damit nicht doppelt gebackupt)
- `agent: 1` (qemu-guest-agent läuft in der VM)
- `startup: order=1` (PBS muss vor 02:00-Backup-Job verfügbar sein)
- `onboot: 1`

## Installation Schritte

1. PBS-ISO geladen, VM 201 angelegt mit:
   ```bash
   qm create 201 --name pbs --memory 4096 --cores 2 --net0 virtio,bridge=vmbr0,firewall=1 \
     --scsihw virtio-scsi-single \
     --scsi0 local-lvm:32 \
     --scsi1 /dev/disk/by-id/ata-Lexar_480GB_SSD_J36482R000574,backup=0,iothread=1 \
     --boot order=scsi0 \
     --ostype l26 --agent 1
   ```
2. PBS installiert via ISO
3. Im PBS sdb1 als ext4 formatiert (label: `backups`)
4. Mount via `/etc/fstab` in der PBS-VM: `/dev/sdb1 /mnt/backups ext4 defaults,noatime 0 2`
5. PBS-Datastore via UI: name `backups`, path `/mnt/backups`, **mit Option `--reuse-datastore`** beim Recovery (alle Snapshots aus altem Datastore wiederverwendet)

## PBS-VM-Updates

Repos aktiv: nur `pbs-no-subscription`, NICHT `pbs-enterprise` (deaktiviert).

```bash
# In der PBS-VM:
apt update && apt -y dist-upgrade
systemctl reboot  # wenn neuer Kernel
```

## qemu-guest-agent

Installiert via:
```bash
apt install -y qemu-guest-agent
systemctl start qemu-guest-agent
```

(`systemctl enable` schlägt fehl wegen statischer Unit — Service wird via udev gestartet.)

## Verbindung Host ↔ PBS-VM

Auf dem Host in `/etc/pve/storage.cfg`:
```
pbs: pbs
        datastore backups
        server 192.168.2.209
        content backup
        fingerprint 38:3c:e0:28:f0:7b:93:55:88:ee:d4:07:a0:37:56:ad:9e:ec:d9:c2:fb:99:06:a0:48:36:ba:bb:93:61:2c:a2
        username root@pam!pve-host
```

Token-Secret in `/etc/pve/priv/storage/pbs.pw`.

Siehe [../06-backup/pbs-setup.md](../06-backup/pbs-setup.md) für GC/Prune/Verify-Jobs.
