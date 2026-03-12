# Alerts und Benachrichtigungen

## Proxmox Benachrichtigungen

### E-Mail-Konfiguration

Proxmox kann bei folgenden Ereignissen benachrichtigen:
- Backup erfolgreich / fehlgeschlagen
- HA-Ereignisse
- Disk-Fehler (SMART)

Konfiguration: Datacenter -> Notifications

### SMTP-Einstellungen

```
# /etc/pve/notifications.cfg (Beispiel)
smtp: mail-to-admin
    mailto root@localhost
    # Fuer externen SMTP:
    # server smtp.example.com
    # port 587
    # username user@example.com
    # from-address proxmox@example.com
```

## Grafana Alerting

### Alert-Regeln (Beispiele)

| Alert | Bedingung | Schwere |
|-------|-----------|---------|
| Disk > 85% | `disk_used_percent > 85` | Warning |
| Disk > 95% | `disk_used_percent > 95` | Critical |
| RAM > 90% | `memory_used_percent > 90` | Warning |
| CPU > 90% (5min) | `cpu_usage_avg_5m > 90` | Warning |
| Container Down | `up == 0` | Critical |

### Benachrichtigungs-Kanaele

| Kanal | Typ | Beschreibung |
|-------|-----|--------------|
| E-Mail | Email | Admin-Benachrichtigung |
| <!-- Telegram --> | <!-- Bot --> | <!-- Optional --> |
| <!-- Discord --> | <!-- Webhook --> | <!-- Optional --> |

### Grafana Alert einrichten

1. Dashboard oeffnen
2. Panel bearbeiten -> Alert Tab
3. Bedingung definieren
4. Benachrichtigungskanal auswaehlen
5. Speichern

## Manuelle Ueberwachung

```bash
# Schneller Health-Check
pct list                           # Container-Status
df -h                              # Disk-Belegung
free -h                            # RAM-Nutzung
uptime                             # Load Average
smartctl -H /dev/sda               # Disk-Health
journalctl -p err --since today    # Heutige Fehler
```
