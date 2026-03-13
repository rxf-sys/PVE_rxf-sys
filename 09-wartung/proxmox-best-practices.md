# Proxmox Best-Practice Optimierungen

> **Analyse vom 13.03.2026** - Basierend auf dem tatsaechlichen Ist-Zustand des Servers.
> Proxmox VE 9.1.6 | Kernel 6.17.13-1-pve | 12 LXC Container

---

## Uebersicht nach Prioritaet

| Prio | Massnahme | Status |
|------|-----------|--------|
| KRITISCH | Backup-Storage auf richtige Disk umstellen | Offen |
| KRITISCH | SSH-Haertung (Root-Login mit Passwort aktiv) | Offen |
| KRITISCH | Swap in allen Containern deaktivieren | Offen |
| HOCH | `keyctl` fuer Docker-Container aktivieren | Offen |
| HOCH | CPU-Limits fuer alle Container setzen | Offen |
| HOCH | Fehlende Firewall-Regeln (CT 105, 109, 110, 111) | Offen |
| HOCH | Backup-Retention erhoehen | Offen |
| HOCH | RAM-Zuweisung optimieren | Offen |
| MITTEL | Alte Kernel entfernen | Offen |
| MITTEL | Proxmox 2FA aktivieren | Offen |
| MITTEL | Node-Exporter auf allen Containern | Offen |
| NIEDRIG | Offsite-Backup einrichten (3-2-1 Regel) | Offen |

---

## KRITISCH

### 1. Backup-Storage auf Backup-SSD umstellen

**Problem:** Der Backup-Job speichert auf `storage: local` = NVMe System-SSD (`/dev/mapper/pve-root`).
Die Backup-SSD `/mnt/backups` (Lexar 480GB) ist quasi leer (2.1 MB benutzt).
Backups belegen unnoetig Platz auf der System-SSD.

**Ist-Zustand:**
```
/dev/mapper/pve-root   94G   40G   51G  44% /          ← Backups landen hier
/dev/sdb1             440G  2.1M  417G   1% /mnt/backups  ← Backup-SSD leer!
```

**Fix:**
```bash
# 1. Backup-Verzeichnis erstellen
mkdir -p /mnt/backups/dump

# 2. Storage in Proxmox registrieren
pvesm add dir backup-ssd --path /mnt/backups --content backup --prune-backups keep-daily=7,keep-weekly=4,keep-monthly=3

# 3. Backup-Job auf neuen Storage umstellen
#    Web-UI: Datacenter -> Backup -> Job bearbeiten -> Storage: backup-ssd
#    Oder in /etc/pve/jobs.cfg: "storage local" durch "storage backup-ssd" ersetzen

# 4. Alte Backups auf neuen Storage verschieben
mv /var/lib/vz/dump/vzdump-lxc-*.{vma.zst,log} /mnt/backups/dump/ 2>/dev/null

# 5. Testlauf ausloesen
vzdump 107 --storage backup-ssd --compress zstd --mode snapshot
```

### 2. SSH-Haertung

**Problem:** `PermitRootLogin yes` - Root-Login mit Passwort moeglich. Kein `PasswordAuthentication` gesetzt (default: yes).
Fail2ban ist installiert, schuetzt aber nur vor Brute-Force, nicht vor gestohlenen Passwoertern.

**Fix:**
```bash
# WICHTIG: Erst pruefen ob SSH-Key hinterlegt ist!
cat ~/.ssh/authorized_keys
# Falls leer: ZUERST von deinem Client aus Key kopieren:
# ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.2.120

# SSH absichern
cat > /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# Konfiguration pruefen
sshd -t

# Nur wenn Test erfolgreich: Neustart
systemctl restart sshd

# TESTEN: Neue SSH-Session oeffnen BEVOR du die alte schliesst!
```

### 3. Swap in allen Containern deaktivieren

**Problem:** 28 GB Container-Swap konfiguriert, aber nur 12 KB tatsaechlich genutzt.
CT 105 (Jellyfin) hat sogar 8 GB Swap. Swap in LXC-Containern auf SSDs verursacht
unnoetige I/O und SSD-Wear. Bei 32 GB Host-RAM und ~4 GB tatsaechlicher Nutzung
ist Container-Swap nicht noetig.

**Ist-Zustand:**
```
CT 100 (samba):         swap: 1024 MB
CT 101 (pi-hole):       swap: 1024 MB
CT 102 (wireguard):     swap: 1024 MB
CT 103 (vaultwarden):   swap: 1024 MB
CT 104 (nginx-proxy):   swap: 1024 MB
CT 105 (jellyfin):      swap: 8192 MB  ← extrem
CT 106 (prometheus):    swap: 2048 MB
CT 107 (grafana):       swap: 1024 MB
CT 108 (pbs):           swap: 2048 MB
CT 109 (homeassistant): swap: 4096 MB
CT 110 (paperless):     swap: 2048 MB
CT 111 (finance):       swap: 3072 MB
───────────────────────────────────
GESAMT:                 28.672 MB (28 GB!)
```

**Fix:**
```bash
for i in 100 101 102 103 104 105 106 107 108 109 110 111; do
  pct set $i --swap 0
  echo "CT $i: Swap auf 0 gesetzt"
done
# Aenderung wird erst nach Neustart des jeweiligen Containers wirksam
# Container einzeln neustarten: pct reboot <ID>
```

> **Hinweis:** Der Host-Swap (8 GB auf der NVMe) bleibt als Sicherheitsnetz bestehen.

---

## HOCH

### 4. `keyctl` fuer Docker-Container aktivieren

**Problem:** CT 102, 103, 104, 110 laufen Docker, haben aber nur `nesting=1`.
Ohne `keyctl` kann Docker-Overlayfs instabil sein und Kernel-Keyring-Operationen schlagen fehl.

**Fix:**
```bash
for i in 102 103 104 110 111; do
  pct set $i --features nesting=1,keyctl=1
  echo "CT $i: keyctl aktiviert"
done
# Neustart der Container noetig
```

### 5. CPU-Limits setzen

**Problem:** 21 CPU-Cores zugewiesen auf 6 physische Cores, ohne Limits.
Ein einzelner Container mit Runaway-Prozess (z.B. OCR in Paperless, Transcoding in Jellyfin)
kann alle 6 Host-Cores beanspruchen und den gesamten Server verlangsamen.

**Fix:**
```bash
pct set 100 --cpulimit 1     # Samba
pct set 101 --cpulimit 1     # Pi-hole
pct set 102 --cpulimit 1     # WireGuard
pct set 103 --cpulimit 1     # Vaultwarden
pct set 104 --cpulimit 1     # Nginx PM
pct set 105 --cpulimit 4     # Jellyfin (Transcoding braucht Power)
pct set 106 --cpulimit 1     # Prometheus
pct set 107 --cpulimit 1     # Grafana
pct set 108 --cpulimit 2     # PBS (Verify/Garbage-Collection)
pct set 109 --cpulimit 2     # Home Assistant (Automations)
pct set 110 --cpulimit 2     # Paperless (OCR-Verarbeitung)
pct set 111 --cpulimit 2     # Finance
```

> **Hinweis:** `cpulimit` begrenzt die maximale CPU-Zeit, nicht die Anzahl sichtbarer Cores.
> Die Container sehen weiterhin die konfigurierten Cores, koennen aber nicht mehr als das Limit nutzen.
> Aenderung ist sofort wirksam, kein Neustart noetig.

### 6. Fehlende Firewall-Regeln

**Problem:** CT 105 (Jellyfin), 109 (Home Assistant), 110 (Paperless), 111 (Finance)
haben keine Firewall-Dateien. Da die Cluster-Policy `DROP` ist, sollte der Traffic
eigentlich geblockt werden - dass die Services trotzdem erreichbar sind, liegt daran,
dass die Container-Firewall nicht explizit aktiviert ist (kein `[OPTIONS] enable: 1`).

**Fix - Firewall-Dateien erstellen:**

```bash
# CT 105 - Jellyfin
cat > /etc/pve/firewall/105.fw << 'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Jellyfin Web-UI (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 8096 -log nolog
# DLNA Discovery (LAN)
IN ACCEPT -source 192.168.2.0/24 -p udp -dport 1900 -log nolog
# Client Discovery (LAN)
IN ACCEPT -source 192.168.2.0/24 -p udp -dport 7359 -log nolog
# Zugriff von Nginx (fuer externen Zugang via Reverse Proxy)
IN ACCEPT -source 192.168.2.125 -p tcp -dport 8096 -log nolog
# ICMP/Ping
IN ACCEPT -p icmp
EOF

# CT 109 - Home Assistant
cat > /etc/pve/firewall/109.fw << 'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Home Assistant Web-UI (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 8123 -log nolog
# mDNS fuer Geraeteerkennung (LAN)
IN ACCEPT -source 192.168.2.0/24 -p udp -dport 5353 -log nolog
# ICMP/Ping
IN ACCEPT -p icmp
EOF

# CT 110 - Paperless
cat > /etc/pve/firewall/110.fw << 'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Paperless Web-UI (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 8000 -log nolog
# ICMP/Ping
IN ACCEPT -p icmp
EOF

# CT 111 - Finance
cat > /etc/pve/firewall/111.fw << 'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Finance Web-UI (LAN) - Port anpassen wenn bekannt
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 8080 -log nolog
# ICMP/Ping
IN ACCEPT -p icmp
EOF
```

> **Hinweis:** Der Port fuer CT 111 (Finance) muss angepasst werden sobald der Service eingerichtet ist.

### 7. Backup-Retention erhoehen

**Problem:** Nur `keep-daily=3`. Wenn ein Problem 4 Tage unbemerkt bleibt, sind alle
sauberen Backups bereits rotiert.

**Ist-Zustand:**
```
prune-backups keep-daily=3
```

**Empfohlen:**
```
prune-backups keep-daily=7,keep-weekly=4,keep-monthly=3
```

**Fix:**
```bash
# In /etc/pve/jobs.cfg aendern:
sed -i 's/keep-daily=3/keep-daily=7,keep-weekly=4,keep-monthly=3/' /etc/pve/jobs.cfg

# Oder ueber Web-UI: Datacenter -> Backup -> Job bearbeiten -> Retention
```

> **Speicherbedarf:** Bei 12 Containern mit ~1-3 GB pro Backup (zstd komprimiert):
> 7 daily + 4 weekly + 3 monthly = 14 Versionen × ~20 GB = ~280 GB.
> Die Backup-SSD hat 440 GB - passt.

### 8. RAM-Zuweisung optimieren

**Problem:** 28 GB RAM zugewiesen, 4.1 GB tatsaechlich genutzt (inkl. aller Container + Host).
Die Werte sind Idle-Werte - unter Last (Jellyfin-Transcoding, Paperless-OCR) steigt der
Verbrauch, daher konservative Empfehlung mit 3-5x Puffer.

**Idle-Messung (13.03.2026):**
```
CT 100 (samba):          35 MB    zugewiesen: 1024 MB
CT 101 (pi-hole):        54 MB    zugewiesen: 1024 MB
CT 102 (wireguard):      76 MB    zugewiesen: 1024 MB
CT 103 (vaultwarden):    71 MB    zugewiesen: 1024 MB
CT 104 (nginx-proxy):   126 MB    zugewiesen: 1024 MB
CT 105 (jellyfin):       132 MB    zugewiesen: 8192 MB
CT 106 (prometheus):     59 MB    zugewiesen: 2048 MB
CT 107 (grafana):        96 MB    zugewiesen: 1024 MB
CT 108 (pbs):            32 MB    zugewiesen: 2048 MB
CT 109 (homeassistant): 451 MB    zugewiesen: 4096 MB
CT 110 (paperless):      98 MB    zugewiesen: 2048 MB
CT 111 (finance):        55 MB    zugewiesen: 3072 MB
```

**Empfohlene Werte (konservativ, mit Last-Puffer):**

| CT | Service | Aktuell | Empfohlen | Begruendung |
|----|---------|---------|-----------|-------------|
| 100 | Samba | 1024 MB | **512 MB** | Samba braucht wenig RAM, selbst unter Last ~100 MB |
| 101 | Pi-hole | 1024 MB | **512 MB** | DNS-Cache braucht max ~200 MB |
| 102 | WireGuard | 1024 MB | **256 MB** | VPN ist minimal, ~100 MB reichen |
| 103 | Vaultwarden | 1024 MB | **512 MB** | Leichtgewichtig, auch mit mehreren Nutzern |
| 104 | Nginx PM | 1024 MB | **512 MB** | Reverse Proxy braucht wenig |
| 105 | Jellyfin | 8192 MB | **4096 MB** | Transcoding braucht RAM, aber 4 GB reichen. Bei Hardware-Transcoding (Quick Sync) noch weniger |
| 106 | Prometheus | 2048 MB | **1024 MB** | 15d Retention, wenige Targets |
| 107 | Grafana | 1024 MB | **512 MB** | Bei wenigen Dashboards ausreichend |
| 108 | PBS | 2048 MB | **1024 MB** | Braucht nur bei Verify/GC mehr RAM |
| 109 | Home Assistant | 4096 MB | **2048 MB** | Genuegend fuer viele Integrations |
| 110 | Paperless | 2048 MB | **2048 MB** | OCR braucht RAM - Wert passt |
| 111 | Finance | 3072 MB | **1024 MB** | Docker + App, aktuell fast leer |

**Gesamt: 28.672 MB → 14.000 MB** (Ersparnis: ~14 GB)

**Fix:**
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

> **Hinweis:** Aenderungen erfordern Container-Neustart. Wenn ein Service nach der Reduzierung
> OOM-Kills bekommt, einfach RAM wieder erhoehen: `pct set <ID> --memory <MB>`

---

## MITTEL

### 9. Alte Kernel entfernen

**Problem:** 4 Kernel-Versionen installiert, nur der neueste (6.17.13) wird genutzt.
Die alten belegen ~500 MB in `/boot` und auf der Root-Partition.

**Fix:**
```bash
# Aktuell laufenden Kernel pruefen
uname -r
# Erwartete Ausgabe: 6.17.13-1-pve

# Alte Kernel entfernen
apt remove --purge \
  proxmox-kernel-6.17.2-1-pve-signed \
  proxmox-kernel-6.17.4-2-pve-signed \
  proxmox-kernel-6.17.9-1-pve-signed

apt autoremove --purge
update-grub
```

> **Hinweis:** Mindestens den aktuellen und einen Fallback-Kernel behalten.
> Falls der neueste Kernel Probleme macht, kann man den vorherigen im GRUB-Menue starten.
> Alternativ nur die aeltesten zwei entfernen und 6.17.9 als Fallback behalten.

### 10. Proxmox Web-UI mit 2FA absichern

```
Web-UI -> Datacenter -> Permissions -> Two Factor
-> Add -> TOTP
-> QR-Code mit Authenticator-App scannen (z.B. Bitwarden, Google Authenticator)
-> Recovery Keys generieren und in Vaultwarden speichern!
```

### 11. Node-Exporter auf allen Containern

**Problem:** Prometheus laeuft, aber ueberwacht nicht alle Container.
Fuer ein vollstaendiges Monitoring sollte auf jedem Container ein Node-Exporter laufen.

```bash
# Auf allen Containern installieren
for i in 100 101 102 103 104 105 106 107 108 109 110 111; do
  echo "=== CT $i ==="
  pct exec $i -- apt install -y prometheus-node-exporter 2>/dev/null
done
```

Danach in `/etc/prometheus/prometheus.yml` auf CT 106 alle Targets hinzufuegen:
```yaml
  - job_name: 'containers'
    static_configs:
      - targets:
        - '192.168.2.121:9100'  # Samba
        - '192.168.2.122:9100'  # Pi-hole
        - '192.168.2.123:9100'  # WireGuard
        - '192.168.2.124:9100'  # Vaultwarden
        - '192.168.2.125:9100'  # Nginx PM
        - '192.168.2.126:9100'  # Jellyfin
        - '192.168.2.128:9100'  # Grafana
        - '192.168.2.129:9100'  # PBS
        - '192.168.2.130:9100'  # Home Assistant
        - '192.168.2.131:9100'  # Paperless
        - '192.168.2.132:9100'  # Finance
```

> **Hinweis:** Node-Exporter-Port 9100 muss in den Firewall-Regeln der Container
> fuer die Prometheus-IP (192.168.2.127) freigeschaltet werden.

### 12. Backup-SSD Mount-Ueberwachung

**Problem:** Die Backup-SSD ist per USB angeschlossen. USB-Verbindungen koennen
sich loesen, der Mount kann verloren gehen. `nofail` in fstab verhindert Boot-Probleme,
aber Backups wuerden dann stillschweigend auf die Root-Partition fallen.

**Fix - Cronjob zur Mount-Pruefung:**
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

# Alle 30 Minuten pruefen
echo "*/30 * * * * root /usr/local/bin/check-backup-mount.sh" > /etc/cron.d/check-backup-mount
```

---

## NIEDRIG (langfristig)

### 13. Offsite-Backup (3-2-1 Regel)

Aktuell: 2 Kopien (System-SSD + Backup-SSD), beide im selben Geraet.
Bei Brand, Diebstahl oder Wasserschaden sind beide weg.

**Optionen:**
- **Rclone zu Backblaze B2** (~5 USD/TB/Monat) - verschluesselt
- **Externe Festplatte** - regelmaessig mitnehmen
- **Zweiter PBS** bei Familie/Freunden

### 14. CT 111 (Finance) dokumentieren

CT 111 hat Docker installiert aber keine Container. Sobald der Service
eingerichtet ist, sollte die Dokumentation nachgezogen werden:
- `05-container/lxc/CT111-finance.md` erstellen
- Pi-hole DNS-Eintrag hinzufuegen
- Firewall-Port in `111.fw` anpassen

---

## Zusammenfassung: Was ist bereits gut?

- Alle Container unprivileged mit Nesting
- Cluster-Firewall aktiv mit DROP-Policy
- Individuelle Firewall-Regeln fuer die meisten Container
- Fail2ban installiert
- Backup-Job vorhanden (taegliche Snapshots)
- `onboot: 1` auf allen Containern
- `nofail` in fstab fuer Backup-SSD
- GPU-Passthrough fuer Jellyfin korrekt konfiguriert (`dev0: /dev/dri/renderD128,gid=44`)
- Storage sauber getrennt (System-NVMe / Daten-SSD / Backup-SSD)
- DuckDNS fuer externen Zugang
- Vaultwarden nur via Nginx erreichbar (Source-Beschraenkung auf 192.168.2.125)
