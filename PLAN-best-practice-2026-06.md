# Best-Practice-Plan rxf-sys — Juni 2026

> Priorisierter Maßnahmenplan auf Basis der vollständigen Doku (Stand 2026-05-25).
> Das Setup ist bereits solide (PVE-Firewall, fail2ban, PBS mit GC/Prune/Verify,
> Notifications, Host-Config-Backup, unprivileged CTs, dedizierte Tokens).
> Dieser Plan schließt die verbleibenden Lücken — sortiert nach Risiko.

**Legende:** 🔴 P0 kritisch · 🟠 P1 hoch · 🟡 P2 mittel · ⚪ P3 langfristig

---

## Phase 1 — 🔴 P0: Datenverlust-Risiken & öffentliche Angriffsfläche

### 1.1 Off-Site-Backup für den PBS-Datastore (3-2-1-Regel)

**Problem:** Originale (NVMe), Daten (sda) und ALLE Backups (sdb) stecken im selben
Gehäuse. Brand, Diebstahl, Überspannung oder ein sdb-Defekt = Totalverlust aller
Snapshots. Die Doku nennt das selbst als „B9 offen" und die Recovery vom 21.05.
hat gezeigt, wie knapp das schon einmal war.

**Maßnahme (empfohlen):** Zweite PBS-Instanz off-site + Remote-Sync-Job.

| Option | Kosten | Bewertung |
|--------|--------|-----------|
| **Tuxis PBS (kostenlos, 150 GB, NL)** | 0 € | Schnellster Einstieg, reicht bei ~21 GB Datastore locker (Empfehlung) |
| Eigene PBS-Box bei Familie/Freunden (z. B. Mini-PC + alte SSD, via WireGuard/Tailscale) | einmalig ~100–150 € | Volle Kontrolle, beliebig groß |
| USB-Wechseldatenträger als Removable Datastore (PBS 4.x nativ) + außer Haus lagern | ~40 € | Manuell, aber besser als nichts |

**Schritte:**
1. Remote-PBS einrichten (Account/Box), Fingerprint notieren
2. In VM 201: Remote anlegen → `Datastore → backups → Sync Jobs` → Push-Sync täglich (z. B. 06:00, nach GC/Prune)
3. **Vorher Client-Encryption aktivieren** (siehe 1.4) — Off-Site-Daten nie unverschlüsselt
4. Erste Synchronisation prüfen, danach in Uptime-Kuma/Checkliste aufnehmen
5. Doku: `06-backup/` um `offsite-sync.md` ergänzen, B9 in allen Dateien schließen

### 1.2 /mnt/storage sichern (Immich-Fotos!)

**Problem:** Die Bind-Mount-Quellen auf sda (`immich/`, `shared/`, `backups/`,
`games/`, `media/`) sind in KEINEM Backup. vzdump sichert Bind-Mounts prinzipiell
nicht. Die Immich-Fotos sind unwiederbringlich — das ist aktuell das größte
einzelne Datenverlust-Risiko.

**Maßnahme:** `proxmox-backup-client` direkt vom Host als host-Backup nach PBS
(dedupliziert, inkrementell — gleiche Mechanik wie das bestehende
`backup-host-config-pbs.sh`).

**Schritte:**
1. Kapazität prüfen: `du -sh /mnt/storage/*` — entscheiden, was nach PBS geht.
   Vorschlag: `immich/`, `shared/`, `backups/`, `games/`, `host-configs/` sichern;
   `media/` nur wenn Platz auf sdb (447 GB) reicht, sonst als „wiederbeschaffbar" deklarieren
2. Skript `/usr/local/sbin/backup-storage-pbs.sh` analog zu `backup-host-config-pbs.sh`:
   ```bash
   proxmox-backup-client backup \
     immich.pxar:/mnt/storage/immich \
     shared.pxar:/mnt/storage/shared \
     backups.pxar:/mnt/storage/backups \
     games.pxar:/mnt/storage/games \
     --backup-type host --backup-id rxf-sys-storage
   ```
3. systemd-Timer täglich (z. B. 01:00, vor vzdump) + OnFailure-Mail (siehe 2.1)
4. Prune-Job in PBS für die Group `host/rxf-sys-storage` (z. B. keep-daily 7, keep-weekly 4)
5. Probe-Restore einzelner Dateien dokumentieren (`proxmox-backup-client restore`)

### 1.3 Admin-Oberflächen nicht ungeschützt ins Internet

**Problem:** `pve.rxf-sys.de` und `pbs.rxf-sys.de` exponieren die PVE-/PBS-Web-UI
öffentlich — nur durch das root-Passwort geschützt (kein 2FA, kein Cloudflare
Access mehr; das Dashboard nutzt laut Doku inzwischen lokale Accounts). Gleiches
gilt für `monitor.` (Kuma-Login) und `hooks.` (Webhook-Receiver).

**Maßnahme:**
1. **Cloudflare Access (Zero Trust) Policies** vor alle Admin-Hostnames legen:
   `pve.`, `pbs.`, `admin.`, `monitor.`, `hooks.` → E-Mail-OTP oder GitHub/Google-IdP,
   nur eigene E-Mail erlaubt. Kostenlos bis 50 User.
   - Alternative: `pve.` und `pbs.` ganz aus dem Tunnel entfernen (Admin nur im LAN;
     unterwegs via WireGuard/Tailscale). Sicherste Variante.
2. `hooks.rxf-sys.de`: prüfen, dass der Webhook-Receiver Signatur/HMAC validiert —
   sonst Access-Service-Token davor
3. Doku: `03-netzwerk/cloudflare-tunnel.md` um Access-Policy-Tabelle ergänzen

### 1.4 2FA + Backup-Verschlüsselung

1. **TOTP für `root@pam`** in PVE (Datacenter → Permissions → Two Factor) und in PBS.
   Recovery-Keys in Vaultwarden ablegen — Achtung Henne-Ei: zusätzlich
   einen Papier-Ausdruck offline (Vaultwarden läuft auf demselben Host!)
2. **vzdump Client-Encryption** für den PBS-Storage aktivieren
   (`pvesm set pbs --encryption-key autogen` bzw. Keyfile), **Schlüssel
   (`/etc/pve/priv/storage/pbs.enc`) extern sichern** — ohne Key sind alle
   Backups wertlos. Muss VOR dem Off-Site-Sync (1.1) passieren, sonst liegen
   die Daten unverschlüsselt remote.
   ⚠ Bestehende unverschlüsselte Snapshots bleiben lesbar; neue sind verschlüsselt.

---

## Phase 2 — 🟠 P1: Ausfälle erkennen & Single Points of Failure

### 2.1 Fehler-Alarme für die Backup-Skripte

**Problem:** `backup-host-config.timer` & Co. schlagen still fehl — niemand merkt es
(genau das war Lesson Learned der Recovery: „Notifications waren nicht eingerichtet").

**Schritte:**
1. Generische Mail-Unit `/etc/systemd/system/notify-failure@.service`:
   ```ini
   [Service]
   Type=oneshot
   ExecStart=/bin/sh -c 'echo "Unit %i failed on rxf-sys: $(systemctl status %i | tail -20)" | proxmox-mail-forward'
   ```
   (oder `sendmail root@localhost` — landet via to-strato-Matcher? Nein: am
   einfachsten direkt `pvesh create /cluster/notifications/...` oder `mail`)
2. In allen Backup-Services: `OnFailure=notify-failure@%n.service`
3. Zusätzlich **Healthchecks.io-Ping** (kostenlos) am Skript-Ende — erkennt auch
   „Timer lief gar nicht" (Dead-Man-Switch), was OnFailure nicht abdeckt
4. `backup-host-config-pbs.timer`: `Persistent=true` ergänzen (verpasste Läufe nachholen)

### 2.2 smartd statt monatlicher Hand-Checks

```bash
# /etc/smartd.conf
DEVICESCAN -a -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -m root -M exec /usr/share/smartmontools/smartd-runner
systemctl enable --now smartd
```
→ Kurz-Test täglich, Long-Test samstags, Mail bei Fehlern/Reallocated-Sectors.
Monatliche Checkliste entsprechend kürzen.

### 2.3 PBS: Prune VOR Garbage Collection

**Problem:** Aktuell GC 03:30, Prune 04:00 — die Doku sagt selbst „GC läuft nach
Prune", der Schedule macht das Gegenteil. Folge: Chunks werden erst ~24 h später frei.

**Fix:** Prune auf 03:00, GC bleibt 03:30 (oder GC auf 04:00). Doku in
`06-backup/README.md` + `pbs-setup.md` anpassen.

### 2.4 SSH härten

Konsolen-Zugriff ist vorhanden → Lockout-Risiko gering:
1. SSH-Key auf Host + PBS-VM deployen (`ssh-copy-id`)
2. `/etc/ssh/sshd_config.d/hardening.conf`:
   ```
   PermitRootLogin prohibit-password
   PasswordAuthentication no
   ```
3. fail2ban bleibt als Defense-in-Depth; `08-sicherheit/README.md` aktualisieren

### 2.5 Zweiter Cloudflared-Connector (Tunnel-SPOF)

**Problem:** Ein CT-104-Ausfall (Reboot, Docker-Update, Defekt) nimmt alle
12 Public-Hostnames inkl. Monitoring offline.

**Fix:** Cloudflare-Tunnel unterstützt mehrere Connectors (Replicas) — zweite
cloudflared-Instanz mit demselben Token z. B. in CT 103 oder einem eigenen
Mini-CT (256 MB reichen). Cloudflare routet automatisch auf den verbleibenden
Connector. Update-Reihenfolge in `09-wartung/updates.md` entschärfen.

### 2.6 Guest-Firewalls vereinheitlichen & aufräumen

| CT/VM | Aktion |
|-------|--------|
| 101, 107, 108, 109, 200 | `.fw` ergänzen: policy DROP + benötigte Ports aus LAN (80/443/9000/8123) + ICMP — konsistent zu den übrigen |
| 104.fw | Regel Port 8000 entfernen (Paperless-Leiche) |
| 102.fw | Redundante Einzel-IP-Regeln (.122, .202) entfernen — `/24` deckt sie ab |
| cluster.fw | Optional `log_level_in: nolog` → `info` für Drop-Analyse |

### 2.7 USV anschaffen + NUT

Kein USV dokumentiert. Stromausfall mitten in vzdump/GC riskiert Datastore- und
Thin-Pool-Konsistenz. Kleine USV (z. B. APC Back-UPS 700 VA, ~80 €) + `nut` oder
`apcupsd` mit sauberem Shutdown (erst Gäste via `pvesh`, dann Host). HP-Mini +
2 SSDs ziehen <40 W → >20 min Überbrückung.

### 2.8 Monitoring von außen

**Problem:** Uptime Kuma läuft auf dem Host, den es überwacht — stirbt der Host,
kommt kein Alarm.

**Fix:** Externer Gratis-Check (UptimeRobot/Healthchecks.io) auf
`https://monitor.rxf-sys.de` (oder Kuma-Push-Monitor mit Dead-Man-Switch).
Damit ist die Kette geschlossen: extern → Kuma → Services.

---

## Phase 3 — 🟡 P2: Betrieb & Wartung verbessern

### 3.1 Unattended Security-Upgrades in den CTs
`unattended-upgrades` (nur Security-Repo) in allen 9 Debian-CTs; auf Host optional
(manuelle Kontrolle bei PVE-Paketen ist vertretbar). Wöchentliche manuelle
Update-Routine bleibt für Feature-Updates.

### 3.2 fail2ban-Jail für pveproxy
Solange PVE-UI öffentlich erreichbar ist (siehe 1.3): Jail auf
`pvedaemon`-Auth-Failures im Journal (`Filter: proxmox`). Entfällt, wenn
`pve.rxf-sys.de` aus dem Tunnel fliegt.

### 3.3 Docker-Image-Hygiene
- Kritische Images pinnen (`vaultwarden/server:1.33` statt `:latest`)
- **diun** (Docker Image Update Notifier) in CT 104 → Mail bei neuen Tags,
  Updates bleiben bewusst manuell
- cloudflared darf auf `:latest` bleiben (abwärtskompatibel, von CF empfohlen)

### 3.4 health-check.sh automatisieren
Wöchentlicher Timer (z. B. Mo 07:00), Report per Mail. Erweitern um:
- LVM-Thin-Pool-Füllstand mit Schwellwert-Warnung (`lvs` data% > 80 → WARN)
- `df /mnt/backups` via `qm guest exec 201` (Datastore-Füllstand)
- Letzter erfolgreicher Lauf aller Backup-Timer

### 3.5 VM 200 RAM-Diät
10 GB für HA OS ist großzügig (typisch 4–6 GB). Auf 6 GB + Ballooning reduzieren →
~4 GB Puffer für künftige Dienste/Off-Site-Sync-Last. Vorher 1 Woche
RAM-Nutzung in HA beobachten.

### 3.6 IPv6 klären
Doku erwähnt IPv6 nicht. Prüfen: `ip -6 a` / Router-Konfiguration. Entweder
bewusst deaktivieren (`sysctl net.ipv6.conf.all.disable_ipv6=1`) oder
Firewall-Regeln auch für v6 denken (PVE-FW policy DROP greift für beide, aber
die `lan`-IPSet ist v4-only).

### 3.7 Monatlicher vzdump der PBS-VM nach `local`
`vzdump 201 --storage local --mode snapshot` (ohne sdb, die hat `backup=0`) —
beschleunigt den VM-201-Wiederaufbau von „Neuinstallation + Doku" auf „Restore".
Die VM-Config selbst ist via Host-Config-Backup (`/etc/pve/qemu-server/201.conf`)
bereits gesichert.

---

## Phase 4 — ⚪ P3: Langfristig / bei Gelegenheit

| Thema | Notiz |
|-------|-------|
| **ZFS-Mirror** | Bei nächstem Hardware-Refresh: 2× NVMe als ZFS-Mirror (Checksumming, Snapshots, Bitrot-Schutz). Auf dem G5-Mini begrenzt (1× NVMe + 1× SATA) — eher Thema für Nachfolger-Hardware |
| **VLAN-Segmentierung** | Mit UniFi: Server-VLAN / Client-VLAN / IoT-VLAN trennen; Bridge `vmbr0` VLAN-aware machen |
| **Metriken-Historie** | InfluxDB + Grafana (PVE hat nativen InfluxDB-Export) oder netdata — nur bei Bedarf, RRD reicht aktuell |
| **Zweiter Node / Quorum** | Bewusst Single-Node bleiben — kein HA-Cluster-Overhead für Homelab |

---

## Repo-/Doku-Hygiene (nebenbei)

- [ ] `CHANGE~1.MD` → `CHANGELOG.md` umbenennen (8.3-Altlast)
- [ ] `09-wartung/checklisten.md`: stale TODO entfernen — `health-check.sh` existiert bereits
- [ ] Checkliste referenziert „Audit-Script" — fehlt in `scripts/`, nachpflegen oder Eintrag streichen
- [ ] Nach Umsetzung: alle „B9 offen"-Marker auflösen (README, 04-storage, 06-backup, CT100, CT104, CT106, 10-DR)

---

## Empfohlene Reihenfolge (Aufwand-Schätzung)

| # | Maßnahme | Aufwand | Abhängigkeit |
|---|----------|---------|--------------|
| 1 | 1.4 vzdump-Encryption + Key extern sichern | 0,5 h | — |
| 2 | 1.2 /mnt/storage → PBS (Skript + Timer + Prune) | 1–2 h | Platz-Check |
| 3 | 1.3 Cloudflare Access vor Admin-UIs | 1 h | — |
| 4 | 1.4 2FA PVE + PBS | 0,5 h | — |
| 5 | 1.1 Off-Site-Sync (Tuxis o. ä.) | 1–2 h | Nr. 1 |
| 6 | 2.1 OnFailure-Mails + Healthchecks.io | 1 h | — |
| 7 | 2.3 Prune/GC-Reihenfolge | 10 min | — |
| 8 | 2.2 smartd | 0,5 h | — |
| 9 | 2.4 SSH-Keys + Passwort-Auth aus | 0,5 h | — |
| 10 | 2.5 Zweiter Tunnel-Connector | 0,5 h | — |
| 11 | 2.6 Firewall-Cleanup | 1 h | — |
| 12 | 2.8 Externes Monitoring | 0,5 h | — |
| 13 | 2.7 USV kaufen + NUT | Hardware + 1 h | Bestellung |
| 14 | Phase 3 nach und nach | je 0,5–1 h | — |

**Quick-Wins zuerst:** Nr. 1, 2, 7 schließen das größte Datenverlust-Risiko
(Immich-Fotos) und kosten zusammen einen Abend. Nr. 3–5 schließen die
Sicherheitslücken Richtung Internet.
