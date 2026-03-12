# Monatliche Wartungs-Checkliste

## Updates

- [ ] **Proxmox Host** updaten
  ```bash
  apt update && apt full-upgrade -y
  ```

- [ ] **Alle Container** updaten
  ```bash
  for i in $(pct list | awk 'NR>1 {print $1}'); do
    echo "=== CT $i ===" && pct exec $i -- apt update && pct exec $i -- apt upgrade -y
  done
  ```

- [ ] **Docker-Images** aktualisieren (CT 102, 103, 104)
  ```bash
  for ct in 102 103 104; do
    pct exec $ct -- bash -c 'cd /srv/appdata/* && docker compose pull && docker compose up -d'
  done
  ```

## Sicherheit

- [ ] **SSL-Zertifikate** pruefen (Nginx PM)
  ```bash
  echo | openssl s_client -connect vault-rxfsys.duckdns.org:443 2>/dev/null | openssl x509 -noout -dates
  ```

- [ ] **Fail2Ban** Status pruefen
  ```bash
  fail2ban-client status 2>/dev/null || echo "Fail2Ban nicht installiert"
  ```

- [ ] **SSH-Logins** pruefen
  ```bash
  last -20
  ```

## Backup

- [ ] **Backup-Integritaet** pruefen
  ```bash
  # Stichproben-Restore testen
  ls -la /var/lib/vz/dump/
  ```

- [ ] **Backup-Speicherplatz** pruefen
  ```bash
  df -h /mnt/backups
  du -sh /var/lib/vz/dump/
  ```

- [ ] **PBS Prune** durchfuehren (falls nicht automatisch)

## Monitoring

- [ ] **Pi-hole Blocklisten** aktualisieren
  ```bash
  pct exec 101 -- pihole -g
  ```

- [ ] **Grafana Dashboards** pruefen - Daten aktuell?

- [ ] **Prometheus Targets** pruefen - Alle UP?

## Storage

- [ ] **LVM Thin Pool** Belegung pruefen
  ```bash
  lvs -a pve/data
  ```

- [ ] **SMART Extended Test** durchfuehren
  ```bash
  smartctl -t long /dev/sda
  smartctl -t long /dev/nvme0n1
  # Ergebnis nach ~1h pruefen:
  # smartctl -a /dev/sda | grep -A 5 "Self-test"
  ```

## Dokumentation

- [ ] CHANGELOG.md aktualisieren (falls Aenderungen)
- [ ] Neue Container/Dienste dokumentieren
- [ ] IP-Schema auf Aktualitaet pruefen
