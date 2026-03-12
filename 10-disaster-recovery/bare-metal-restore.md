# Bare-Metal-Restore

Anleitung fuer den kompletten Neuaufbau des Servers von Null.

## Voraussetzungen

- Proxmox VE ISO auf USB-Stick
- Zugang zu Backups (vzdump oder PBS)
- Diese Dokumentation (offline/ausgedruckt)
- Vaultwarden Emergency Sheet (Passwoerter)

## Schritt-fuer-Schritt

### 1. Proxmox installieren

Siehe [02-installation/proxmox-installation.md](../02-installation/proxmox-installation.md)

- Gleiche IP: 192.168.2.120/24
- Gleicher Hostname: rxfsys
- Gleiche Partitionierung

### 2. Post-Install

```bash
bash scripts/post-install.sh
```

Oder manuell: [02-installation/post-install.md](../02-installation/post-install.md)

### 3. Storage einrichten

```bash
# Daten-SSD mounten
mkdir -p /mnt/storage
mount /dev/sda1 /mnt/storage

# Backup-SSD mounten
mkdir -p /mnt/backups
mount /dev/sdb1 /mnt/backups

# fstab-Eintraege erstellen
blkid /dev/sda1 /dev/sdb1
# UUIDs in /etc/fstab eintragen
```

### 4. Container wiederherstellen

In der Prioritaets-Reihenfolge (siehe [wiederherstellung.md](wiederherstellung.md)):

```bash
# Aus lokalen Backups
for backup in /var/lib/vz/dump/vzdump-lxc-*.tar.zst; do
  ID=$(echo $backup | grep -oP 'lxc-\K\d+')
  echo "Restoring CT $ID..."
  pct restore $ID $backup
  pct start $ID
done

# Oder aus PBS
# PBS als Storage hinzufuegen, dann Restore ueber Web-UI
```

### 5. Netzwerk pruefen

```bash
# Alle Container-IPs pruefen
for i in $(pct list | awk 'NR>1 {print $1}'); do
  echo -n "CT $i: "; pct exec $i -- hostname -I 2>/dev/null || echo "offline"
done

# DNS pruefen
dig google.com @192.168.2.122

# Externe Erreichbarkeit pruefen
curl -s https://vault-rxfsys.duckdns.org > /dev/null && echo "OK" || echo "FEHLER"
```

### 6. DuckDNS einrichten

```bash
# Cronjob erstellen
crontab -e
# */5 * * * * curl -s "https://www.duckdns.org/update?domains=rxfsys,vault-rxfsys&token=DEIN_TOKEN&ip=" > /dev/null
```

### 7. Abschluss-Checkliste

- [ ] Alle Container laufen
- [ ] DNS funktioniert (Pi-hole)
- [ ] DHCP funktioniert
- [ ] VPN erreichbar (WireGuard)
- [ ] Vaultwarden extern erreichbar (HTTPS)
- [ ] Samba-Freigaben zugreifbar
- [ ] Jellyfin spielt Medien ab
- [ ] Monitoring laeuft (Prometheus + Grafana)
- [ ] Backups konfiguriert
- [ ] DuckDNS Cronjob aktiv
- [ ] SSH-Keys hinterlegt

## Geschaetzte Wiederherstellungszeit

| Schritt | Dauer |
|---------|-------|
| Proxmox Installation | ~15 Min |
| Post-Install | ~10 Min |
| Storage einrichten | ~5 Min |
| Container wiederherstellen | ~30 Min |
| Pruefen und Feintuning | ~30 Min |
| **Gesamt** | **~90 Min** |
