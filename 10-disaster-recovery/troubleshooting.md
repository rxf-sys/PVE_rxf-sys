# Troubleshooting

Haeufige Probleme und Loesungen.

## Proxmox nicht erreichbar

```bash
# Am Server direkt (Monitor/Tastatur):
systemctl status pveproxy
systemctl restart pveproxy

# Falls Firewall blockiert
pve-firewall stop

# Netzwerk pruefen
ip addr show vmbr0
ping 192.168.2.1
```

## Container startet nicht

```bash
# Fehlermeldung anzeigen
journalctl -xe | tail -50

# Container-Konfiguration pruefen
pct config <ID>

# Debug-Modus starten
lxc-start -n <ID> -F -l DEBUG

# Haeufige Ursachen:
# - Nicht genuegend RAM
# - Disk voll (LVM Thin Pool)
# - Mount-Point nicht verfuegbar
# - Netzwerk-Konflikt (IP bereits vergeben)
```

## Kein Internet im Container

```bash
pct exec <ID> -- bash -c '
  echo "=== IP ==="
  ip addr show eth0
  echo "=== Route ==="
  ip route
  echo "=== DNS ==="
  cat /etc/resolv.conf
  echo "=== Ping Gateway ==="
  ping -c 3 192.168.2.1
  echo "=== Ping Internet ==="
  ping -c 3 8.8.8.8
  echo "=== DNS Test ==="
  dig google.com +short
'
```

### Loesungen

| Problem | Loesung |
|---------|---------|
| Keine IP | `pct config <ID>` -> net0 pruefen |
| Kein Gateway | Route pruefen: `ip route add default via 192.168.2.1` |
| DNS geht nicht | `/etc/resolv.conf` -> `nameserver 192.168.2.122` |
| Ping geht, DNS nicht | Pi-hole (CT 101) pruefen |

## DuckDNS IP stimmt nicht

```bash
# Aktuelle externe IP
curl -s ifconfig.me

# Manuell aktualisieren
curl "https://www.duckdns.org/update?domains=rxfsys,vault-rxfsys&token=DEIN_TOKEN&ip="

# Cronjob pruefen
crontab -l | grep duckdns
```

## LVM Thin Pool voll

```bash
# Belegung pruefen
lvs -a pve/data

# Alte Snapshots loeschen
lvremove pve/snap_*

# Thin Pool vergroessern (falls moeglich)
lvextend -L +50G pve/data

# Container-Disks verkleinern
# (nur ueber Backup/Restore mit kleinerer Disk)
```

## Docker-Container in LXC startet nicht

```bash
# Docker-Status pruefen
pct exec <ID> -- systemctl status docker

# Docker neu starten
pct exec <ID> -- systemctl restart docker

# Docker-Logs
pct exec <ID> -- docker logs <CONTAINER_NAME>

# Nesting aktiviert?
pct config <ID> | grep features
# Muss enthalten: nesting=1
```

## Samba-Freigabe nicht erreichbar

```bash
# Samba-Status
pct exec 100 -- systemctl status smbd

# Samba-Freigaben anzeigen
pct exec 100 -- smbclient -L localhost -N

# Mount-Points pruefen
pct exec 100 -- df -h

# Berechtigungen pruefen
ls -la /mnt/storage/shared/

# Samba-Benutzer pruefen
pct exec 100 -- pdbedit -L
```

## Backup fehlgeschlagen

```bash
# Backup-Log pruefen
cat /var/log/vzdump/*.log | tail -50

# Speicherplatz pruefen
df -h /var/lib/vz/dump/
df -h /mnt/backups/

# Manuell testen
vzdump 100 --storage local --compress zstd --mode snapshot
```

## Allgemeine Diagnose

```bash
# System-Diagnose Script
./scripts/rxfsys-diagnostics.sh

# Oder manuell:
echo "=== Uptime ===" && uptime
echo "=== RAM ===" && free -h
echo "=== Disk ===" && df -h
echo "=== Container ===" && pct list
echo "=== Fehler ===" && journalctl -p err --since today --no-pager | tail -20
echo "=== SMART ===" && smartctl -H /dev/sda 2>/dev/null | grep result
echo "=== LVM ===" && lvs
```
