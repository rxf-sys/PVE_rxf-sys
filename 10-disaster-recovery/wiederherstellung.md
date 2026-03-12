# Wiederherstellungs-Prozeduren

## Einzelnen Container wiederherstellen

### Schnell-Restore aus vzdump

```bash
# 1. Verfuegbare Backups auflisten
ls -la /var/lib/vz/dump/ | grep lxc-<ID>

# 2. Container stoppen (falls noch laufend)
pct stop <ID>

# 3. Container wiederherstellen
pct restore <ID> /var/lib/vz/dump/vzdump-lxc-<ID>-<DATUM>.tar.zst --force

# 4. Container starten
pct start <ID>

# 5. Dienst pruefen
pct exec <ID> -- systemctl status <DIENST>
```

### Restore aus PBS

```bash
pct restore <ID> pbs:backup/ct/<ID>/<BACKUP-ID> --force
pct start <ID>
```

## Prioritaets-Reihenfolge bei Ausfall

Bei einem Totalausfall die Container in dieser Reihenfolge wiederherstellen:

| Prio | CT | Dienst | Grund |
|------|----|--------|-------|
| 1 | 101 | Pi-hole | DNS + DHCP fuer gesamtes Netzwerk |
| 2 | 104 | Nginx Proxy | Externer Zugang (SSL) |
| 3 | 103 | Vaultwarden | Passwoerter fuer alle Dienste |
| 4 | 102 | WireGuard | Externer VPN-Zugang |
| 5 | 100 | Samba | Dateifreigabe |
| 6 | 108 | PBS | Backup-Server |
| 7 | 105 | Jellyfin | Media |
| 8 | 109 | Home Assistant | Smart Home |
| 9 | 110 | Paperless | Dokumente |
| 10 | 106 | Prometheus | Monitoring |
| 11 | 107 | Grafana | Dashboards |

## Netzwerk-Notfall

### Kein DNS?

```bash
# Temporaer Google DNS verwenden
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Pi-hole Container pruefen
pct status 101
pct start 101
pct exec 101 -- pihole status
```

### Kein DHCP?

```bash
# Geraete bekommen keine IP?
# Pi-hole Container pruefen
pct exec 101 -- systemctl status pihole-FTL

# Notfall: DHCP im Router temporaer aktivieren
# Router -> DHCP -> Aktivieren
```

### Kein Internet?

```bash
# Am Host pruefen
ping -c 3 8.8.8.8           # Internet-Konnektivitaet
ping -c 3 192.168.2.1       # Gateway erreichbar?
ip route                     # Default-Route vorhanden?
```
