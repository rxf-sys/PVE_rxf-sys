# Changelog

## 2026-08-14 — Mailserver-Migration geplant (Doku only)

Keine Änderung am laufenden System. Neues Verzeichnis
[11-mailserver/](11-mailserver/) mit der Planung für die Migration von
Strato-Mail auf einen eigenen Mailserver:

- Machbarkeitsanalyse: Direktbetrieb auf rxf-sys ist verbaut (Cloudflare Tunnel
  transportiert kein SMTP, kein setzbarer PTR am Privatanschluss, Spamhaus-PBL)
- Zielarchitektur: CT 112 `mailserver` (.215) mit docker-mailserver, davor ein
  kleiner VPS als Postfix-Relay, verbunden per WireGuard (10.9.0.0/24)
- Vorbedingung: 2 GB RAM freiräumen (Audit-Maßnahme 10)
- Runbooks für DNS (MX/SPF/DKIM/DMARC/MTA-STS), imapsync-Migration, Cutover,
  Betrieb und Rollback
- Neues Diagramm [diagramme/mail-flow.md](diagramme/mail-flow.md)
- Bewusste Festlegung: PVE-/PBS-Notifications bleiben auf externem SMTP, damit
  ein Ausfall des eigenen Mailservers noch gemeldet werden kann

## 2026-05-25 — Best-Practice-Setup + Doku-Refresh

### Neu

- Host-Config-Backup eingerichtet
  - Lokal: `/usr/local/sbin/backup-host-config.sh` daily 01:30 → `/mnt/storage/host-configs/`, 30 d retention
  - PBS: `/usr/local/sbin/backup-host-config-pbs.sh` weekly Sun 01:00 → `host/rxf-sys-config`
- fail2ban auf Host (jail sshd, 5/10min → 1 h ban, LAN ignored)
- Subscription-Nag-Patch + dpkg-Hook (auto-reapply)
- PVE-Firewall aktiviert (cluster.fw + host.fw + 201.fw mit IPSET `lan`)
- Notifications via Strato SMTP (PVE + PBS, Endpoint `strato`, Matcher `to-strato`)
- Admin-Dashboard mit dedizierten Read-Only-Tokens
  - PVE: `admin-dashboard@pve!api` (Role `DashboardRO`)
  - PBS: `dashboard@pbs!dashboard` (Role `DatastoreReader`)
- Cloudflare Tunnel mit 12 Public Hostnames

### Geändert

- vzdump-Job UUID-Name → `pbs-nightly`, notification-mode auf `notification-system`
- PBS-Datastore-Owner aller Backup-Groups → `root@pam!pve-host`
- VM 201 startup `order=1` (PBS vor Backup-Job verfügbar)
- Bind-Mount Paperless aus CT 104 entfernt (nicht mehr genutzt)

### Entfernt

- CT 105 (Nextcloud-AIO, war nie konfiguriert) + LVM-Volume + Bind-Mount
- PBS-Server-Pakete + Configs vom Host (PBS läuft als VM 201)
- USB-Rescue-Stick (sdc)

## 2026-05-21 — Disaster Recovery

- `/var` versehentlich gelöscht → Host unbrauchbar
- Frisch neu installiert PVE 9.2.2
- Alle Guests aus PBS-Snapshot vom 21.05. wiederhergestellt
- PBS-Server in VM 201 ausgelagert, Lexar-SSD (sdb) per Disk-Passthrough
- Datastore mit `--reuse-datastore` re-attached → alle Snapshots erhalten

---

*Vor 2026-05-21 siehe alte Doku-Historie.*
