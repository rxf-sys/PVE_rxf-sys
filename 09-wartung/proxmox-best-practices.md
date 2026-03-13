# Proxmox Best-Practice Optimierungen

> **Analyse vom 13.03.2026** - Basierend auf dem tatsaechlichen Ist-Zustand des Servers.
> Proxmox VE 9.1.6 | Kernel 6.17.13-1-pve | 12 LXC Container

---

## Uebersicht nach Prioritaet

| Prio | Massnahme | Status |
|------|-----------|--------|
| KRITISCH | Backup-Storage auf richtige Disk umstellen | Erledigt (13.03.2026) |
| KRITISCH | SSH-Haertung (Root-Login mit Passwort aktiv) | Erledigt (13.03.2026) |
| KRITISCH | Swap in allen Containern deaktivieren | Erledigt (13.03.2026) |
| HOCH | `keyctl` fuer Docker-Container aktivieren | Erledigt (13.03.2026) |
| HOCH | CPU-Limits fuer alle Container setzen | Erledigt (13.03.2026) |
| HOCH | Fehlende Firewall-Regeln (CT 105, 109, 110, 111) | Erledigt (13.03.2026) |
| HOCH | Backup-Retention erhoehen | Erledigt (13.03.2026) |
| HOCH | RAM-Zuweisung optimieren | Offen |
| MITTEL | Alte Kernel entfernen | Erledigt (13.03.2026) |
| MITTEL | Proxmox 2FA aktivieren | Erledigt (13.03.2026) |
| MITTEL | Fail2ban mit Proxmox-Jail aktivieren | Erledigt (13.03.2026) |
| MITTEL | Node-Exporter auf allen Containern | Offen |
| MITTEL | PBS-Repo Suite korrigieren (bookworm -> trixie) | Erledigt (13.03.2026) |
| NIEDRIG | Offsite-Backup einrichten (3-2-1 Regel) | Offen |

---

## Audit-Ergebnis (13.03.2026)

```
PASS:  48 / 50
WARN:   2 / 50
FAIL:   0 / 50
```

Verbleibende Warnungen:
- **Keine Backups auf backup-ssd** - Loest sich beim naechsten 03:00 Backup-Job automatisch
- **RAM 86% zugewiesen** - Nur 13% tatsaechlich genutzt, optional optimierbar

Audit-Script: `scripts/rxfsys-audit.sh`

---

## KRITISCH (Erledigt)

### 1. Backup-Storage auf Backup-SSD umstellen

**Problem:** Der Backup-Job speicherte auf `storage: local` = NVMe System-SSD.
Die Backup-SSD `/mnt/backups` (Lexar 480GB) war quasi leer.

**Fix (umgesetzt 13.03.2026):**
```bash
# Backup-Verzeichnis erstellt
mkdir -p /mnt/backups/dump

# Storage in Proxmox registriert
pvesm add dir backup-ssd --path /mnt/backups --content backup --prune-backups keep-daily=7,keep-weekly=4,keep-monthly=3

# Backup-Job auf neuen Storage umgestellt (in /etc/pve/jobs.cfg)
# storage: backup-ssd

# Alte Backups verschoben
mv /var/lib/vz/dump/vzdump-lxc-*.{vma.zst,log} /mnt/backups/dump/ 2>/dev/null
```

### 2. SSH-Haertung

**Problem:** `PermitRootLogin yes` - Root-Login mit Passwort moeglich.

**Fix (umgesetzt 13.03.2026):**
```bash
# SSH-Key war bereits hinterlegt (1 Key)
# Haertung als Drop-in Datei aktiviert:
cat > /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

sshd -t && systemctl restart sshd
```

### 3. Swap in allen Containern deaktivieren

**Problem:** 28 GB Container-Swap konfiguriert, aber nur 12 KB tatsaechlich genutzt.

**Fix (umgesetzt 13.03.2026):**
```bash
for i in 100 101 102 103 104 105 106 107 108 109 110 111; do
  pct set $i --swap 0
done
```

> **Hinweis:** Der Host-Swap (8 GB auf der NVMe) bleibt als Sicherheitsnetz bestehen.

---

## HOCH (Erledigt)

### 4. `keyctl` fuer Docker-Container aktivieren

**Problem:** CT 102, 103, 104, 110, 111 laufen Docker, hatten aber nur `nesting=1`.

**Fix (umgesetzt 13.03.2026):**
```bash
for i in 102 103 104 110 111; do
  pct set $i --features nesting=1,keyctl=1
done
```

### 5. CPU-Limits setzen

**Problem:** 21 CPU-Cores zugewiesen auf 6 physische Cores, ohne Limits.

**Fix (umgesetzt 13.03.2026):**
```bash
pct set 100 --cpulimit 1     # Samba
pct set 101 --cpulimit 1     # Pi-hole
pct set 102 --cpulimit 1     # WireGuard
pct set 103 --cpulimit 1     # Vaultwarden
pct set 104 --cpulimit 1     # Nginx PM
pct set 105 --cpulimit 4     # Jellyfin (Transcoding)
pct set 106 --cpulimit 1     # Prometheus
pct set 107 --cpulimit 1     # Grafana
pct set 108 --cpulimit 2     # PBS
pct set 109 --cpulimit 2     # Home Assistant
pct set 110 --cpulimit 2     # Paperless
pct set 111 --cpulimit 2     # Finance
```

### 6. Fehlende Firewall-Regeln

**Problem:** CT 105, 109, 110, 111 hatten keine Firewall-Dateien.

**Fix (umgesetzt 13.03.2026):** Firewall-Dateien erstellt fuer alle 4 Container:

| CT | Service | Ports | Datei |
|----|---------|-------|-------|
| 105 | Jellyfin | 8096/tcp, 1900/udp, 7359/udp | `/etc/pve/firewall/105.fw` |
| 109 | Home Assistant | 8123/tcp, 5353/udp | `/etc/pve/firewall/109.fw` |
| 110 | Paperless | 8000/tcp | `/etc/pve/firewall/110.fw` |
| 111 | Finance | 8080/tcp | `/etc/pve/firewall/111.fw` |

Alle mit `policy_in: DROP`, `policy_out: ACCEPT`, Zugriff nur aus LAN (192.168.2.0/24), ICMP erlaubt.

### 7. Backup-Retention erhoehen

**Problem:** Nur `keep-daily=3`.

**Fix (umgesetzt 13.03.2026):**
```
Vorher:  prune-backups keep-daily=3
Nachher: prune-backups keep-daily=7,keep-weekly=4,keep-monthly=3
```

> **Speicherbedarf:** 14 Versionen x ~20 GB = ~280 GB. Backup-SSD hat 440 GB - passt.

### 8. RAM-Zuweisung optimieren (Offen)

**Problem:** 28 GB RAM zugewiesen, 4.1 GB tatsaechlich genutzt (14%).
Die Werte sind Idle-Werte - unter Last steigt der Verbrauch.

**Empfohlene Werte (konservativ, mit Last-Puffer):**

| CT | Service | Aktuell | Empfohlen | Begruendung |
|----|---------|---------|-----------|-------------|
| 100 | Samba | 1024 MB | **512 MB** | Samba braucht wenig RAM, selbst unter Last ~100 MB |
| 101 | Pi-hole | 1024 MB | **512 MB** | DNS-Cache braucht max ~200 MB |
| 102 | WireGuard | 1024 MB | **256 MB** | VPN ist minimal, ~100 MB reichen |
| 103 | Vaultwarden | 1024 MB | **512 MB** | Leichtgewichtig, auch mit mehreren Nutzern |
| 104 | Nginx PM | 1024 MB | **512 MB** | Reverse Proxy braucht wenig |
| 105 | Jellyfin | 8192 MB | **4096 MB** | Transcoding braucht RAM, aber 4 GB reichen |
| 106 | Prometheus | 2048 MB | **1024 MB** | 15d Retention, wenige Targets |
| 107 | Grafana | 1024 MB | **512 MB** | Bei wenigen Dashboards ausreichend |
| 108 | PBS | 2048 MB | **1024 MB** | Braucht nur bei Verify/GC mehr RAM |
| 109 | Home Assistant | 4096 MB | **2048 MB** | Genuegend fuer viele Integrations |
| 110 | Paperless | 2048 MB | **2048 MB** | OCR braucht RAM - Wert passt |
| 111 | Finance | 3072 MB | **1024 MB** | Docker + App, aktuell fast leer |

**Gesamt: 28.672 MB -> 14.000 MB** (Ersparnis: ~14 GB)

```bash
pct set 100 --memory 512
pct set 101 --memory 512
pct set 102 --memory 256
pct set 103 --memory 512
pct set 104 --memory 512
pct set 105 --memory 4096
pct set 106 --memory 1024
pct set 107 --memory 512
pct set 108 --memory 1024
pct set 109 --memory 2048
# CT 110 bleibt bei 2048
pct set 111 --memory 1024
```

---

## MITTEL

### 9. Alte Kernel entfernen (Erledigt)

**Fix (umgesetzt 13.03.2026):** 3 alte Kernel entfernt, nur noch 6.17.13-1-pve installiert.

```bash
apt remove --purge \
  proxmox-kernel-6.17.2-1-pve-signed \
  proxmox-kernel-6.17.4-2-pve-signed \
  proxmox-kernel-6.17.9-1-pve-signed
apt autoremove --purge
update-grub
```

### 10. Proxmox Web-UI mit 2FA absichern (Erledigt)

**Fix (umgesetzt 13.03.2026):** TOTP ueber Proxmox Web-UI eingerichtet.

```
Datacenter -> Permissions -> Two Factor -> Add -> TOTP
Recovery Keys in Vaultwarden gespeichert
```

### 11. Fail2ban mit Proxmox-Jail aktivieren (Erledigt)

**Fix (umgesetzt 13.03.2026):**
```bash
apt install fail2ban -y
systemctl enable --now fail2ban

# Proxmox-Jail
cat > /etc/fail2ban/jail.d/proxmox.conf << 'EOF'
[proxmox]
enabled = true
port = https,http,8006
filter = proxmox
backend = systemd
maxretry = 3
findtime = 600
bantime = 3600
EOF

cat > /etc/fail2ban/filter.d/proxmox.conf << 'EOF'
[Definition]
failregex = pvedaemon\[.*authentication (verification )?failure; rhost=<HOST>
ignoreregex =
EOF

systemctl restart fail2ban
```

### 12. PBS-Repo Suite korrigieren (Erledigt)

**Problem:** PBS-Repo nutzte `bookworm` statt `trixie` (System laeuft Debian Trixie).

**Fix (umgesetzt 13.03.2026):**
```bash
sed -i 's/bookworm/trixie/' /etc/apt/sources.list.d/pbs.list
apt update
```

> **Hinweis:** Die Grafana-Repo-Warnung "Some suites are misconfigured" ist ein False Positive.
> Grafana nutzt `stable` als Release-Kanal, nicht als Debian-Suite. `apt update` laeuft fehlerfrei.

### 13. Node-Exporter auf allen Containern (Offen)

```bash
for i in 100 101 102 103 104 105 106 107 108 109 110 111; do
  pct exec $i -- apt install -y prometheus-node-exporter 2>/dev/null
done
```

Danach in `/etc/prometheus/prometheus.yml` auf CT 106 alle Targets hinzufuegen.

### 14. Backup-SSD Mount-Ueberwachung

```bash
cat > /usr/local/bin/check-backup-mount.sh << 'SCRIPT'
#!/bin/bash
if ! mountpoint -q /mnt/backups; then
  logger -p user.err "WARNUNG: /mnt/backups ist nicht gemountet!"
  mount /mnt/backups && logger "Backup-SSD erfolgreich remountet" || \
    logger -p user.crit "FEHLER: Backup-SSD konnte nicht gemountet werden!"
fi
SCRIPT

chmod +x /usr/local/bin/check-backup-mount.sh
echo "*/30 * * * * root /usr/local/bin/check-backup-mount.sh" > /etc/cron.d/check-backup-mount
```

---

## NIEDRIG (langfristig)

### 15. Offsite-Backup (3-2-1 Regel)

Aktuell: 2 Kopien (System-SSD + Backup-SSD), beide im selben Geraet.

**Optionen:**
- **Rclone zu Backblaze B2** (~5 USD/TB/Monat) - verschluesselt
- **Externe Festplatte** - regelmaessig mitnehmen
- **Zweiter PBS** bei Familie/Freunden

### 16. CT 111 (Finance) dokumentieren

CT 111 hat Docker installiert aber keine Container. Sobald der Service
eingerichtet ist, sollte die Dokumentation nachgezogen werden:
- `05-container/lxc/CT111-finance.md` erstellen
- Pi-hole DNS-Eintrag hinzufuegen
- Firewall-Port in `111.fw` anpassen

---

## Zusammenfassung: Was ist bereits gut?

- Alle Container unprivileged mit Nesting
- Cluster-Firewall aktiv mit DROP-Policy
- Individuelle Firewall-Regeln fuer alle Container (inkl. CT 105, 109, 110, 111)
- SSH nur mit Key-Authentifizierung (PasswordAuthentication no)
- Fail2ban aktiv mit SSH- und Proxmox-Jail
- 2FA fuer Proxmox Web-UI aktiviert
- Backup-Job auf Backup-SSD mit erweiterter Retention (7 daily, 4 weekly, 3 monthly)
- Swap auf 0 fuer alle Container
- CPU-Limits auf allen Containern
- keyctl fuer alle Docker-Container aktiviert
- `onboot: 1` auf allen Containern
- `nofail` in fstab fuer Backup-SSD
- GPU-Passthrough fuer Jellyfin korrekt konfiguriert (`dev0: /dev/dri/renderD128,gid=44`)
- Storage sauber getrennt (System-NVMe / Daten-SSD / Backup-SSD)
- DuckDNS fuer externen Zugang
- Vaultwarden nur via Nginx erreichbar (Source-Beschraenkung auf 192.168.2.125)
- Nur 1 Kernel installiert (kein Ballast)
- PBS-Repo korrekt auf Trixie-Suite
