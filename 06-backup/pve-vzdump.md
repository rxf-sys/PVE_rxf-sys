# PVE vzdump-Job

## Konfiguration

`/etc/pve/jobs.cfg`:

```ini
vzdump: pbs-nightly
        all 1
        compress zstd
        enabled 1
        exclude 201
        mode snapshot
        node rxf-sys
        notes-template {{guestname}}
        notification-mode notification-system
        schedule 02:00
        storage pbs
```

## Erklärung

| Feld                | Wert                | Bedeutung                                       |
|---------------------|---------------------|-------------------------------------------------|
| `all`               | 1                   | alle Guests sichern                             |
| `exclude`           | 201                 | außer VM 201 (PBS selbst)                       |
| `compress`          | zstd                | Kompression vor Upload                          |
| `mode`              | snapshot            | LVM-Snapshot während Backup                     |
| `notification-mode` | notification-system | über Matcher (Strato SMTP) statt sendmail       |
| `notes-template`    | `{{guestname}}`     | im PBS-Snapshot-Listing als Notiz               |
| `schedule`          | `02:00`             | täglich um 02:00                                |

## Wo landen die Backups

PBS-Datastore `backups` in VM 201, pro Guest separate Backup-Group:

```bash
pvesm list pbs | head -20
# ct/100/2026-05-24T00:00:01Z
# ct/101/2026-05-24T00:01:14Z
# ...
# vm/200/2026-05-24T00:05:33Z
```

Storage-Definition in `/etc/pve/storage.cfg`:

```ini
pbs: pbs
        datastore backups
        server 192.168.2.209
        content backup
        fingerprint 38:3c:e0:28:f0:7b:93:55:88:ee:d4:07:a0:37:56:ad:9e:ec:d9:c2:fb:99:06:a0:48:36:ba:bb:93:61:2c:a2
        username root@pam!pve-host
```

Token-Secret in `/etc/pve/priv/storage/pbs.pw`.

## Owner aller Backup-Groups

Nach Token-Rotation müssen Backup-Groups dem neuen Token zugeordnet werden:

```bash
TOKEN_USER='root@pam!pve-host'
TOKEN_SECRET=$(cat /etc/pve/priv/storage/pbs.pw)

for entry in "ct 100" "ct 101" "ct 102" "ct 103" "ct 104" "ct 106" "ct 107" "ct 108" "ct 109" "vm 200" "vm 201"; do
  type=$(echo $entry | cut -d' ' -f1)
  id=$(echo $entry | cut -d' ' -f2)
  curl -k -sS -X POST \
    -H "Authorization: PBSAPIToken=$TOKEN_USER:$TOKEN_SECRET" \
    --data-urlencode "backup-type=$type" \
    --data-urlencode "backup-id=$id" \
    --data-urlencode "new-owner=root@pam!pve-host" \
    "https://192.168.2.209:8007/api2/json/admin/datastore/backups/change-owner"
  echo
done
```

(Erwartete Antwort pro Entry: `{"data":null}`)

## Manuelles Backup

```bash
# Einzelnen Guest jetzt sichern, ohne Retention zu prunen
vzdump 108 --storage pbs --mode snapshot --compress zstd \
       --notes-template "probe-$(date +%F-%H%M)" --remove 0

# Spezifischer Job laufen lassen
pvesh create /nodes/rxf-sys/vzdump --node rxf-sys --vmid 108 --storage pbs --mode snapshot
```

## Inkremental-Verhalten

PBS arbeitet immer inkrementell (Chunk-Dedup). Typischer Snapshot eines kleinen CTs:
- Erstes Backup: voll, z.B. 850 MB
- Tägliche Backups: nur Änderungs-Chunks, z.B. 200 MB neu, 650 MB reused (76 % reused)

→ Dedup-Ratio im Datastore aktuell ~32x.

## Verifikation

```bash
# Wann lief der Job zuletzt?
pvesh get /cluster/tasks --output-format yaml | grep -A 5 vzdump | head -30

# Mail wurde verschickt? (PBS-Endpoint test)
pvesh create /cluster/notifications/targets/strato/test
```
