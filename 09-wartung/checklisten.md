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
- [ ] Audit-Script ausführen + Bericht ablegen

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

## Health-Check-Script

Siehe [../scripts/](../scripts/) — TODO: `health-check.sh` schreiben (im alten Repo war eines).
