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
  ls -la /var/lib/vz/dump/ | tail -20
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
echo "=== RAM ===" && free -h && \
echo "=== SMART ===" && smartctl -H /dev/sda 2>/dev/null | grep -i result && \
echo "=== Fehler (letzte Woche) ===" && journalctl -p err --since "1 week ago" --no-pager | wc -l && echo "Fehlereintraege"
```
