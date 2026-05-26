# PBS-Datastore + Jobs

PBS läuft in VM 201 (siehe [../05-container/vm/VM201-pbs.md](../05-container/vm/VM201-pbs.md)).

## Datastore

| Name      | Path           | Disk              | Größe   |
|-----------|----------------|-------------------|---------|
| `backups` | `/mnt/backups` | sdb1 (Passthrough)| 447 GB  |

Verify mit:
```bash
qm guest exec 201 -- proxmox-backup-manager datastore list
qm guest exec 201 -- proxmox-backup-manager datastore show backups
```

## Garbage Collection

| Setting       | Wert              |
|---------------|-------------------|
| Schedule      | `03:30` daily     |
| Last run      | ~1 s              |
| Status        | OK                |

GC entfernt referenz-freie Chunks. Läuft nach Prune (welcher Refs entfernt).

```bash
qm guest exec 201 -- proxmox-backup-manager garbage-collection list
qm guest exec 201 -- proxmox-backup-manager garbage-collection status backups
qm guest exec 201 -- proxmox-backup-manager garbage-collection start backups   # manuell
```

## Prune

| Setting           | Wert                              |
|-------------------|-----------------------------------|
| Job-ID            | `daily-prune`                     |
| Schedule          | `04:00` daily                     |
| Datastore         | backups                           |
| keep-daily        | 7                                 |
| keep-weekly       | 4                                 |
| keep-monthly      | 6                                 |

```bash
qm guest exec 201 -- proxmox-backup-manager prune list
qm guest exec 201 -- proxmox-backup-manager prune show daily-prune

# Manuell für einen Guest
qm guest exec 201 -- proxmox-backup-manager prune run daily-prune
```

## Verify

Built-in Verify-Job läuft Sa 05:00. Prüft Checksums aller Chunks.

```bash
qm guest exec 201 -- proxmox-backup-manager verify-job list
```

## Statistiken (Stand 2026-05-25)

| Metric             | Wert        |
|--------------------|-------------|
| disk-bytes         | 20.4 GB     |
| disk-chunks        | 12.503      |
| index-data-bytes   | 639 GB      |
| **Dedup-Ratio**    | ~32x        |
| pending-chunks     | minimal     |
| removed-bad        | 0           |

## Tokens & ACLs

```bash
qm guest exec 201 -- proxmox-backup-manager user list
qm guest exec 201 -- proxmox-backup-manager acl list
```

Aktuell:
| Auth-ID                       | Path                  | Role            |
|-------------------------------|-----------------------|-----------------|
| `dashboard@pbs`               | `/datastore/backups`  | DatastoreReader |
| `dashboard@pbs!dashboard`     | `/datastore/backups`  | DatastoreReader |
| `root@pam!pve-host`           | `/datastore/backups`  | DatastoreAdmin  |

Wichtig: bei Privilege-Separation MUSS sowohl der User als auch der Token-Subject die Permission haben (intersection-rule).

## Notifications (in PBS-VM)

| Item                | Wert                                       |
|---------------------|--------------------------------------------|
| Endpoint            | `strato` (smtp.strato.de:465 TLS)          |
| From                | info@rxf-sys.de                            |
| Mailto              | info@rxf-sys.de                            |
| Matcher             | `to-strato` (mode all)                     |
| Default-Matcher     | disabled                                   |

```bash
qm guest exec 201 -- proxmox-backup-manager notification endpoint smtp list
qm guest exec 201 -- proxmox-backup-manager notification matcher list
```

## Restore vom Datastore

Siehe [restore-procedures.md](restore-procedures.md).
