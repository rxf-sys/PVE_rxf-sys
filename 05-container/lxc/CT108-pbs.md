# CT 108 - Proxmox Backup Server

## Übersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 108 |
| **Hostname** | pbs |
| **IP-Adresse** | 192.168.2.129 |
| **RAM** | 2048 MB |
| **CPU** | 2 Cores |
| **Disk** | 20 GB |
| **OS** | Debian Trixie |
| **Dienst** | Proxmox Backup Server |

---

## Funktion

Proxmox Backup Server (PBS) bietet inkrementelle, deduplizierte Backups für Proxmox VE. Deutlich effizienter als vzdump für regelmäßige Backups.

---

## Zugriff

| Dienst | URL |
|--------|-----|
| Web-Interface | https://192.168.2.129:8007 |
| Mit lokalem DNS | https://pbs.home:8007 |

### Zugangsdaten

| Parameter | Wert |
|-----------|------|
| Benutzer | `root@pam` |
| Passwort | `___________________` |

---

## Container-Konfiguration

**Datei:** `/etc/pve/lxc/108.conf`

```ini
arch: amd64
cores: 2
features: nesting=1
hostname: pbs
memory: 2048
mp0: /mnt/backups,mp=/mnt/datastore
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,ip=192.168.2.129/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-108-disk-0,size=20G
swap: 2048
unprivileged: 1
```

---

## Datastore einrichten

### Im PBS Web-UI

1. **Administration** → **Storage / Disks**
2. **Directory** → **Create: Directory**
3. Pfad: `/mnt/datastore/backups`
4. Name: `backups`

### Oder per CLI

```bash
pct exec 108 -- proxmox-backup-manager datastore create backups /mnt/datastore/backups
```

---

## Proxmox VE Anbindung

### Storage in Proxmox hinzufügen

1. **Datacenter** → **Storage** → **Add** → **Proxmox Backup Server**
2. **ID:** `pbs`
3. **Server:** `192.168.2.129`
4. **Username:** `root@pam`
5. **Password:** (PBS-Passwort)
6. **Datastore:** `backups`
7. **Fingerprint:** (aus PBS kopieren)

### Fingerprint ermitteln

```bash
pct exec 108 -- proxmox-backup-manager cert info | grep Fingerprint
```

---

## Backup-Jobs einrichten

### In Proxmox VE

1. **Datacenter** → **Backup**
2. **Add** → Neuer Backup-Job
3. **Storage:** `pbs`
4. **Schedule:** z.B. `03:00` täglich
5. **Selection mode:** All / Include / Exclude
6. **Mode:** Snapshot

---

## Verwaltung

```bash
# Service-Status
pct exec 108 -- systemctl status proxmox-backup-proxy
pct exec 108 -- systemctl status proxmox-backup

# Dienste neustarten
pct exec 108 -- systemctl restart proxmox-backup-proxy proxmox-backup

# Datastore-Status
pct exec 108 -- proxmox-backup-manager datastore list

# Garbage Collection (alte Chunks entfernen)
pct exec 108 -- proxmox-backup-manager garbage-collection run backups

# Verification (Integrität prüfen)
pct exec 108 -- proxmox-backup-manager verify backups
```

---

## Retention (Aufbewahrung)

### Im PBS Web-UI

**Datastore** → **backups** → **Prune & GC** → **Prune Options**

Empfohlene Einstellungen:

| Parameter | Wert | Beschreibung |
|-----------|------|--------------|
| keep-last | 3 | Letzte 3 Backups |
| keep-daily | 7 | 7 Tage |
| keep-weekly | 4 | 4 Wochen |
| keep-monthly | 6 | 6 Monate |

### Per CLI

```bash
pct exec 108 -- proxmox-backup-manager prune-job create daily-prune \
    --datastore backups \
    --schedule "daily" \
    --keep-last 3 \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6
```

---

## Firewall

**Datei:** `/etc/pve/firewall/108.fw`

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# PBS Web-UI + API (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 8007 -log nolog

# ICMP/Ping
IN ACCEPT -p icmp
```

---

## Wichtige Pfade

| Pfad | Beschreibung |
|------|--------------|
| `/etc/proxmox-backup/` | PBS-Konfiguration |
| `/mnt/datastore/backups/` | Backup-Datastore |
| `/var/log/proxmox-backup/` | Logs |

---

## Speicherplatz-Effizienz

PBS nutzt Deduplizierung - identische Datenblöcke werden nur einmal gespeichert:

```bash
# Datastore-Statistiken
pct exec 108 -- proxmox-backup-manager datastore show backups

# Deduplizierungsrate anzeigen
# Im Web-UI: Datastore → backups → Summary
```

---

## Restore

### Einzelne Dateien (File-Level)

1. **PBS Web-UI** → **Datastore** → **backups**
2. Backup auswählen → **Browse**
3. Dateien navigieren und herunterladen

### Kompletter Container

In **Proxmox VE**:
1. **Storage** → **pbs** → Backup auswählen
2. **Restore**
3. Ziel-VMID und Optionen wählen

---

## Backup

```bash
# PBS-Konfiguration sichern (nicht die Backup-Daten!)
pct exec 108 -- tar -czf /root/pbs-config.tar.gz /etc/proxmox-backup/

# Container-Backup (Meta)
vzdump 108 --storage local --compress zstd --mode snapshot
```

---

*CT 108 - Proxmox Backup Server | Server rxfsys*