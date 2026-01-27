# CT 100 - NAS (Samba)

## Übersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 100 |
| **Hostname** | nas |
| **IP-Adresse** | 192.168.2.121 |
| **RAM** | 1024 MB |
| **CPU** | 1 Core |
| **Disk** | 15 GB (rootfs) |
| **OS** | Debian |
| **Dienst** | Samba 4.x |

---

## Funktion

Der NAS-Container stellt Netzwerk-Dateifreigaben via SMB/Samba bereit. Alle Freigaben liegen auf der separaten Storage-SSD (`/mnt/storage`) und werden in den Container gemountet.

---

## Zugriff

### Windows

```
\\192.168.2.121\shared
\\192.168.2.121\media
\\192.168.2.121\backups

# Mit lokalem DNS:
\\nas.home\shared
```

### Mac/Linux

```
smb://192.168.2.121/shared
smb://nas.home/shared
```

### Zugangsdaten

| Parameter | Wert |
|-----------|------|
| Benutzer | homeserver |
| Passwort | `___________________` |
| Gruppe | smbusers |

---

## Container-Konfiguration

**Datei:** `/etc/pve/lxc/100.conf`

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: nas
memory: 1024
mp0: /mnt/storage/shared,mp=/srv/shared
mp1: /mnt/storage/media,mp=/srv/media
mp2: /mnt/storage/backups,mp=/srv/backups
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,hwaddr=BC:24:11:90:E2:A7,ip=192.168.2.121/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-100-disk-0,size=15G
swap: 1024
unprivileged: 1
```

---

## Samba-Konfiguration

**Datei (im Container):** `/etc/samba/smb.conf`

```ini
[global]
    workgroup = WORKGROUP
    server string = Home NAS
    netbios name = NAS
    server role = standalone server
    security = user
    map to guest = never
    
    # Nur SMB3 (sicher)
    server min protocol = SMB3
    
    # Nur lokales Netz
    interfaces = eth0
    bind interfaces only = yes
    hosts allow = 192.168.2.0/24 127.0.0.1
    hosts deny = 0.0.0.0/0

    # Logging
    log file = /var/log/samba/log.%m
    max log size = 1000
    logging = file

    # Performance
    socket options = TCP_NODELAY IPTOS_LOWDELAY
    use sendfile = yes

    # Keine Drucker
    load printers = no
    printing = bsd
    printcap name = /dev/null
    disable spoolss = yes

[shared]
    comment = Allgemeine Dateien
    path = /srv/shared
    browseable = yes
    read only = no
    guest ok = no
    valid users = @smbusers
    force group = smbusers
    create mask = 0664
    directory mask = 0775
    vfs objects = recycle
    recycle:repository = .recycle/%U
    recycle:keeptree = yes
    recycle:versions = yes

[media]
    comment = Medien (Filme, Musik, Fotos)
    path = /srv/media
    browseable = yes
    read only = no
    guest ok = no
    valid users = @smbusers
    force group = smbusers
    create mask = 0664
    directory mask = 0775
    vfs objects = recycle
    recycle:repository = .recycle/%U
    recycle:keeptree = yes

[backups]
    comment = Backups
    path = /srv/backups
    browseable = yes
    read only = no
    guest ok = no
    valid users = @smbusers
    force group = smbusers
    create mask = 0660
    directory mask = 0770
```

---

## Freigaben

| Freigabe | Pfad im Container | Pfad auf Host | Beschreibung |
|----------|-------------------|---------------|--------------|
| shared | /srv/shared | /mnt/storage/shared | Allgemeine Dateien |
| media | /srv/media | /mnt/storage/media | Filme, Musik, Fotos |
| backups | /srv/backups | /mnt/storage/backups | Geräte-Backups |

---

## Sicherheits-Features

| Feature | Beschreibung |
|---------|--------------|
| **Nur SMB3** | Alte unsichere Protokolle (SMB1/2) blockiert |
| **Kein Gastzugang** | Authentifizierung erforderlich |
| **Nur LAN** | Zugriff nur aus 192.168.2.0/24 |
| **Papierkorb** | Gelöschte Dateien landen in `.recycle` |

---

## Verwaltung

### Samba-Status prüfen

```bash
pct exec 100 -- systemctl status smbd
```

### Samba neustarten

```bash
pct exec 100 -- systemctl restart smbd nmbd
```

### Konfiguration testen

```bash
pct exec 100 -- testparm -s
```

### Benutzer verwalten

```bash
# Passwort ändern
pct exec 100 -- smbpasswd homeserver

# Neuen Benutzer anlegen
pct exec 100 -- useradd -G smbusers neuername
pct exec 100 -- smbpasswd -a neuername

# Benutzer auflisten
pct exec 100 -- pdbedit -L
```

### Berechtigungen reparieren

```bash
# Auf dem Proxmox-Host:
chown -R 100000:100000 /mnt/storage/shared
chown -R 100000:100000 /mnt/storage/backups
chmod -R 2770 /mnt/storage/shared
chmod -R 2770 /mnt/storage/backups
```

---

## Firewall

**Datei:** `/etc/pve/firewall/100.fw`

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Samba (nur LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 445 -log nolog
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 139 -log nolog
IN ACCEPT -source 192.168.2.0/24 -p udp -dport 137:138 -log nolog

# ICMP/Ping
IN ACCEPT -p icmp
```

---

## Troubleshooting

### Keine Verbindung möglich

```bash
# Samba-Status prüfen
pct exec 100 -- systemctl status smbd

# Logs prüfen
pct exec 100 -- tail -50 /var/log/samba/log.smbd

# Firewall prüfen
pve-firewall status
```

### Permission Denied

```bash
# Berechtigungen auf Host prüfen
ls -la /mnt/storage/shared

# Bei Problemen: Berechtigungen neu setzen
chown -R 100000:100000 /mnt/storage/shared
```

### Papierkorb leeren

```bash
pct exec 100 -- rm -rf /srv/shared/.recycle/*
pct exec 100 -- rm -rf /srv/media/.recycle/*
```

---

## Backup

### Wichtige Dateien

| Datei | Beschreibung |
|-------|--------------|
| `/etc/samba/smb.conf` | Samba-Konfiguration |
| `/var/lib/samba/private/passdb.tdb` | Benutzer-Datenbank |

### Container-Backup

```bash
vzdump 100 --storage local --compress zstd --mode snapshot
```

---

*CT 100 - NAS | Server rxfsys*
