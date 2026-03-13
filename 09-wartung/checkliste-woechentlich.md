# Woechentliche Wartungs-Checkliste

## Pruefungen

- [ ] **Container-Status** - Alle Container laufen?
  ```bash
  pct list
  ```

- [ ] **SMART-Status** - Festplatten gesund?
  ```bash
  smartctl -H /dev/sda
  smartctl -H /dev/nvme0n1
  smartctl -d sat -H /dev/sdb
  ```

- [ ] **Disk-Belegung** - Genuegend Platz?
  ```bash
  df -h / /mnt/storage /mnt/backups
  lvs
  ```

- [ ] **Backup-Status** - Backups erfolgreich?
  ```bash
  # Nach Umstellung auf backup-ssd:
  ls -la /mnt/backups/dump/ | tail -20
  # Pruefen ob Backup-SSD gemountet ist:
  mountpoint -q /mnt/backups && echo "OK" || echo "NICHT GEMOUNTET!"
  ```

- [ ] **Logs pruefen** - Fehler vorhanden?
  ```bash
  journalctl -p err --since "1 week ago" --no-pager | tail -50
  ```

- [ ] **RAM-Nutzung** - Kein Swapping?
  ```bash
  free -h
  ```

- [ ] **Pi-hole** - DNS funktioniert?
  ```bash
  dig google.com @192.168.2.122
  ```

## Schnell-Check (ein Befehl)

```bash
echo "=== Container ===" && pct list && \
echo "=== Disk ===" && df -h / /mnt/storage /mnt/backups && \
echo "=== Backup-Mount ===" && (mountpoint -q /mnt/backups && echo "OK" || echo "NICHT GEMOUNTET!") && \
echo "=== RAM ===" && free -h && \
echo "=== Container-RAM ===" && for i in $(pct list | awk 'NR>1 {print $1}'); do NAME=$(pct config $i | grep hostname | awk '{print $2}'); MEM=$(pct exec $i -- free -m 2>/dev/null | awk '/Mem:/{print $3}'); echo "  CT $i ($NAME): ${MEM:-offline} MB"; done && \
echo "=== SMART ===" && smartctl -H /dev/sda 2>/dev/null | grep -i result && \
echo "=== Fehler (letzte Woche) ===" && journalctl -p err --since "1 week ago" --no-pager | wc -l && echo "Fehlereintraege"
```
