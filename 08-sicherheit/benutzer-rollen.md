# Benutzer und Rollen

## Proxmox Benutzer

| Benutzer | Realm | Rolle | Beschreibung |
|----------|-------|-------|--------------|
| root@pam | PAM | Administrator | Haupt-Admin |

### Neuen Benutzer erstellen

```bash
# Linux-Benutzer erstellen (PAM)
useradd -m <username>
passwd <username>

# In Proxmox hinzufuegen
pveum useradd <username>@pam

# Rolle zuweisen
pveum aclmod / -user <username>@pam -role PVEAdmin
```

### Verfuegbare Rollen

| Rolle | Beschreibung |
|-------|--------------|
| Administrator | Voller Zugriff |
| PVEAdmin | Fast voller Zugriff (ohne User-Management) |
| PVEVMAdmin | VM/CT Verwaltung |
| PVEVMUser | VM/CT Nutzung (Start/Stop/Console) |
| PVEAuditor | Nur Lesen |

## API-Tokens

Fuer automatisierte Zugriffe (Monitoring, Skripte):

```bash
# API-Token erstellen
pveum user token add root@pam monitoring --privsep 0

# Token mit eingeschraenkten Rechten
pveum user token add root@pam backup-token --privsep 1
pveum aclmod / -token 'root@pam!backup-token' -role PVEVMAdmin
```

> **Wichtig:** API-Tokens sicher aufbewahren (Vaultwarden) und nicht im Git speichern!

## Container-Benutzer

| Container | Benutzer | Dienst |
|-----------|----------|--------|
| CT 100 (Samba) | homeserver | Samba-Freigabe |
| CT 103 (Vaultwarden) | - | Admin-Token |
| CT 104 (Nginx PM) | admin@example.com | NPM Web-UI |

## Pruefbefehle

```bash
# Alle Benutzer anzeigen
pveum user list

# Berechtigungen anzeigen
pveum acl list

# API-Tokens anzeigen
pveum user token list root@pam
```
