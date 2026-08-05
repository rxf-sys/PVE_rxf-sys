# Checklisten

## Wöchentlich

- [ ] `apt list --upgradable` auf Host + allen Guests prüfen
- [ ] `systemctl --failed` auf Host + Guests
- [ ] `dmesg --since '7 days ago' | grep -iE 'error|fail' | head` durchgehen
- [ ] Uptime-Kuma-Status auf https://monitor.rxf-sys.de prüfen
- [ ] PBS-UI: GC + Prune + Verify Last-Run grün?
- [ ] Freier Platz: `df -hT` (Host), `pvesm status`

## Monatlich

- [ ] SMART Long-Self-Test: `smartctl -t long /dev/nvme0n1` (4-5 h)
- [ ] SMART Long-Self-Test: `smartctl -t long /dev/sda`
- [ ] In PBS-VM: SMART `smartctl -H /dev/sda` (= sdb passthrough)
- [ ] Notification-Funktionalität: Test-Mail aus PVE+PBS UI
- [ ] Backups verifizieren: `pvesm list pbs | wc -l` (~148+ Snapshots erwartet)
- [ ] Probe-Restore eines kleinen CTs als VMID 999 (siehe [../06-backup/restore-procedures.md](../06-backup/restore-procedures.md))
- [ ] Disk-Trim: `fstrim -av` (sollte automatisch von systemd-fstrim.timer laufen)
- [ ] Audit-Script ausführen + Bericht ablegen: `doc-audit.sh` (siehe unten)

## Jährlich / nach größeren Änderungen

- [ ] PVE Major-Upgrade prüfen (z.B. 9.x → 10.x)
- [ ] Strato-Passwort rotieren
- [ ] Cloudflare-Tunnel-Token rotieren (siehe [../03-netzwerk/cloudflare-tunnel.md](../03-netzwerk/cloudflare-tunnel.md))
- [ ] PVE+PBS-Tokens rotieren
- [ ] Doku updaten (`/root/audit-$(date +%F).md` + dieses Repo)

## Ad-hoc Diagnose

```bash
# Aktueller Snapshot des Systems
pveversion
pct list && qm list
pvesm status
systemctl --failed
free -h && df -hT
pct config <id>
qm config <id>
pve-firewall status
journalctl -p err --since '24 hours ago' | tail -30
```

## Skripte

| Skript                                          | Zweck                                                     |
|-------------------------------------------------|-----------------------------------------------------------|
| [`health-check.sh`](../scripts/health-check.sh) | Kurzer Health-Report (wöchentlich, ~10 s)                 |
| [`doc-audit.sh`](../scripts/doc-audit.sh)       | Vollaudit + Doku-Abgleich (monatlich / nach Änderungen)   |

### Doku-Abgleich (monatlich oder nach größeren Änderungen)

```bash
# Auf dem Host als root
/usr/local/sbin/doc-audit.sh
# → /root/audit-<datum>.md (Passwörter/Tokens sind maskiert)
```

Der Report enthält oben eine Best-Practice-Tabelle (`PASS`/`WARN`/`FAIL`/`INFO`)
und darunter den vollständigen Ist-Zustand, gegliedert wie dieses Repo (01–10).

**Ablauf:**

1. Report erzeugen und einmal selbst durchsehen (Redaktion prüfen).
2. Alle `FAIL` abarbeiten, `WARN` bewerten — bewusste Abweichungen (z.B. SSH
   PasswordAuth im LAN) gehören dokumentiert in [../08-sicherheit/](../08-sicherheit/).
3. Report an Claude geben mit der Bitte, ihn gegen dieses Repo abzugleichen und
   die Abweichungen einzupflegen.
4. Report archivieren. `/root/*.md` liegt **nicht** im Host-Config-Backup
   (das sichert `/etc`, `/var/lib/pve-cluster`, `/root/.ssh` usw.) — also
   entweder nach `/mnt/storage/` kopieren oder ins Repo übernehmen.

Weicht ein Endpunkt im Abschnitt "Erreichbarkeit" ab, ist entweder der Dienst
weg oder die Tabelle in [../README.md](../README.md) veraltet — beide Fälle
gehören geprüft.
