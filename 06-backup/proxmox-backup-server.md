# Proxmox Backup Server (CT 108)

## Uebersicht

| Parameter | Wert |
|-----------|------|
| **CT-ID** | 108 |
| **IP** | 192.168.2.129 |
| **Port** | 8007 (HTTPS) |
| **URL** | https://pbs.home:8007 |
| **Datastore** | /mnt/backups/proxmox |

## Datastore

| Name | Pfad | Disk | Groesse |
|------|------|------|---------|
| backups | /mnt/backups/proxmox | Lexar 480GB (USB) | ~447 GB |

## PBS mit Proxmox verbinden

1. PBS als Storage in Proxmox hinzufuegen:
   - Datacenter -> Storage -> Add -> Proxmox Backup Server
   - Server: 192.168.2.129
   - Datastore: backups
   - Fingerprint: (aus PBS Web-UI kopieren)

2. Backup-Jobs in Proxmox auf PBS-Storage umstellen

## Retention (Pruning)

| Parameter | Wert |
|-----------|------|
| keep-last | 3 |
| keep-daily | 7 |
| keep-weekly | 4 |
| keep-monthly | 3 |

```bash
# Prune-Job manuell ausfuehren (in PBS)
proxmox-backup-manager prune-job run <JOB-ID>

# Garbage Collection
proxmox-backup-manager garbage-collection run backups
```

## Verify-Jobs

Regelmaessige Integritaetspruefung der Backups:

```bash
# Verify-Job erstellen (in PBS Web-UI)
# Administration -> Verify Jobs -> Add

# Manuell verifizieren
proxmox-backup-manager verify backups
```

## Pruefbefehle

```bash
# Datastore-Status
proxmox-backup-manager datastore list

# Backup-Inhalt anzeigen
proxmox-backup-client list --repository 192.168.2.129:backups

# Speicherplatz
df -h /mnt/backups
```
