# Tokens & Credentials

⚠ **Diese Datei enthält keine Secrets**, nur eine Inventur aller Token-IDs und Permissions. Secrets sind in `.env`-Files mit `chmod 600` und/oder in `/etc/pve/priv/`.

## PVE — User & Tokens

```bash
pveum user list
pveum user token list <userid>
pveum acl list
pveum role list | grep -E 'Dashboard|PVEAuditor'
```

### Users

| User                  | Realm | Verwendung                        |
|-----------------------|-------|-----------------------------------|
| `root@pam`            | pam   | Administration, Web-UI            |
| `admin-dashboard@pve` | pve   | Admin-Dashboard (read + power-mgmt) |

### Tokens

| Token-ID                  | User                  | Privsep | Verwendung               |
|---------------------------|-----------------------|---------|--------------------------|
| `admin-dashboard@pve!api` | admin-dashboard@pve   | 0       | Admin-Dashboard Backend  |

### Custom Role

```bash
pveum role list 2>&1 | grep Dashboard
```
```
DashboardRO: Datastore.Audit, Pool.Audit, Sys.Audit, VM.Audit, VM.GuestAgent.Audit, VM.PowerMgmt
```

### ACL

```
/   DashboardRO   user   admin-dashboard@pve   propagate=1
```

## PBS — User & Tokens

```bash
qm guest exec 201 -- proxmox-backup-manager user list
qm guest exec 201 -- proxmox-backup-manager user list-tokens <userid>
qm guest exec 201 -- proxmox-backup-manager acl list
```

### Users

| User              | Verwendung                         |
|-------------------|------------------------------------|
| `root@pam`        | PBS-UI Admin                       |
| `dashboard@pbs`   | Admin-Dashboard read-only (User)   |

### Tokens

| Token-ID                  | User              | Role            | Verwendung                  |
|---------------------------|-------------------|-----------------|-----------------------------|
| `root@pam!pve-host`       | root@pam          | DatastoreAdmin  | vzdump vom PVE-Host         |
| `dashboard@pbs!dashboard` | dashboard@pbs     | DatastoreReader | Admin-Dashboard PBS-Anfragen|

### ACLs

```
/datastore/backups   DatastoreAdmin    root@pam!pve-host
/datastore/backups   DatastoreReader   dashboard@pbs              ← wichtig wegen Privilege Separation!
/datastore/backups   DatastoreReader   dashboard@pbs!dashboard
```

**Privilege-Separation-Trap**: bei PBS-Tokens mit `privsep=true` (Default) ist effektive Permission = intersection(User-ACL, Token-ACL). Daher muss der **User** dieselbe ACL haben wie der Token-Subject.

## Cloudflare API-Tokens

Verwaltet im Cloudflare Dashboard → Profile → API Tokens.

| Verwendung           | Permissions                                                         |
|----------------------|---------------------------------------------------------------------|
| Admin-Dashboard `CF_API_TOKEN` | Cloudflare Tunnel Read, Access Apps Read, Account Audit Logs Read, Zone DNS Read, Zone SSL Read |
| Tunnel `CF_TUNNEL_TOKEN`       | (von Cloudflare automatisch generiert mit Tunnel-Create) |

## Strato SMTP

Mailbox: `info@rxf-sys.de`
Passwort: in `/etc/pve/notifications.cfg` (PVE) und PBS-internal config.

## Wo werden Secrets gespeichert?

| Secret                           | Ort                                                                 |
|----------------------------------|---------------------------------------------------------------------|
| PVE-Token-Secret (für pbs storage) | `/etc/pve/priv/storage/pbs.pw`                                  |
| Strato SMTP Password (PVE)       | `/etc/pve/priv/notifications.cfg`                                   |
| Strato SMTP Password (PBS)       | in der PBS-VM `/etc/proxmox-backup/notifications.cfg`               |
| Admin-Dashboard ENV-Vars         | CT 101 `/opt/rxf-admin/infrastructure/.env` (chmod 600)             |
| Orynthia ENV-Vars                | CT 109 `/opt/orynthia/.env` (chmod 600)                             |

## Token-Rotation

### PVE-Token rotieren

```bash
# 1. Alten Token löschen
pveum user token remove admin-dashboard@pve api

# 2. Neuen erzeugen, YAML-Output → grep
TMPOUT=$(mktemp)
pveum user token add admin-dashboard@pve api --privsep 0 --output-format yaml > "$TMPOUT"
PVE_SECRET=$(grep '^value:' "$TMPOUT" | awk '{print $2}')
rm -f "$TMPOUT"

# 3. In CT 101 .env eintragen + Container recreaten
echo "$PVE_SECRET" > /tmp/.tok
pct push 101 /tmp/.tok /tmp/.tok
pct exec 101 -- bash -c 'sed -i "s|^PROXMOX_TOKEN_SECRET=.*|PROXMOX_TOKEN_SECRET=$(cat /tmp/.tok)|" /opt/rxf-admin/infrastructure/.env && rm /tmp/.tok && cd /opt/rxf-admin/infrastructure && docker compose up -d --force-recreate backend'
rm /tmp/.tok
unset PVE_SECRET
```

### PBS-Token rotieren

```bash
# 1. Alten Token löschen
qm guest exec 201 -- proxmox-backup-manager user delete-token dashboard@pbs dashboard

# 2. Neuen erzeugen (Standard-Output parsen)
PBS_RAW=$(qm guest exec 201 -- proxmox-backup-manager user generate-token dashboard@pbs dashboard)
PBS_OUT=$(echo "$PBS_RAW" | jq -r '."out-data"')
PBS_JSON=$(echo "$PBS_OUT" | sed -E 's/^Result:[[:space:]]*//' | tr -d '\n')
PBS_SECRET=$(echo "$PBS_JSON" | jq -r '.value')

# 3. ACL (idempotent)
qm guest exec 201 -- proxmox-backup-manager acl update /datastore/backups DatastoreReader --auth-id 'dashboard@pbs!dashboard'

# 4. In CT 101 .env eintragen + Recreate
echo "$PBS_SECRET" > /tmp/.tok
pct push 101 /tmp/.tok /tmp/.tok
pct exec 101 -- bash -c 'sed -i "s|^PBS_TOKEN_SECRET=.*|PBS_TOKEN_SECRET=$(cat /tmp/.tok)|" /opt/rxf-admin/infrastructure/.env && rm /tmp/.tok && cd /opt/rxf-admin/infrastructure && docker compose up -d --force-recreate backend'
rm /tmp/.tok
unset PBS_SECRET
```

### Storage-Token (root@pam!pve-host) rotieren

```bash
# In PBS-Web-UI: alten Token löschen, neuen mit gleicher ACL DatastoreAdmin erzeugen, Secret kopieren

# Auf Host:
pvesm set pbs --password '<neues_secret>'
pvesm list pbs | head -3   # verify

# Owner-Fix für alle Backup-Groups (nach Token-Rotation nötig)
USER='root@pam!pve-host'
SECRET=$(cat /etc/pve/priv/storage/pbs.pw)
for entry in "ct 100" "ct 101" "ct 102" "ct 103" "ct 104" "ct 106" "ct 107" "ct 108" "ct 109" "vm 200" "vm 201"; do
  type=$(echo $entry | cut -d' ' -f1)
  id=$(echo $entry | cut -d' ' -f2)
  curl -k -sS -X POST -H "Authorization: PBSAPIToken=$USER:$SECRET" \
    --data-urlencode "backup-type=$type" --data-urlencode "backup-id=$id" \
    --data-urlencode "new-owner=$USER" \
    "https://192.168.2.209:8007/api2/json/admin/datastore/backups/change-owner"
  echo
done
```
