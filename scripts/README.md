# scripts/

Wartungs-Skripte für rxf-sys.

| Skript                          | Ort auf Host                                  | Zweck                                     |
|---------------------------------|-----------------------------------------------|-------------------------------------------|
| `backup-host-config.sh`         | `/usr/local/sbin/`                            | Daily local tar.zst Backup von /etc + Co. |
| `backup-host-config-pbs.sh`     | `/usr/local/sbin/`                            | Weekly PBS-Backup als `host/rxf-sys-config` |
| `repatch-no-nag.sh`             | `/usr/local/sbin/`                            | Re-apply Nag-Patch nach apt-Updates       |
| `backup-host-config.service`    | `/etc/systemd/system/`                        | systemd-Unit für daily-Skript             |
| `backup-host-config.timer`      | `/etc/systemd/system/`                        | systemd-Timer 01:30                       |
| `backup-host-config-pbs.service`| `/etc/systemd/system/`                        | systemd-Unit für PBS-Skript               |
| `backup-host-config-pbs.timer`  | `/etc/systemd/system/`                        | systemd-Timer So 01:00                    |
| `health-check.sh`               | `/usr/local/sbin/`                            | Read-only Health-Report (Markdown)        |
| `doc-audit.sh`                  | `/usr/local/sbin/`                            | Vollständiges Inventar- + Best-Practice-Audit |

## doc-audit.sh — Doku-Abgleich & Best-Practice-Audit

Erhebt **read-only** den kompletten Ist-Zustand des Hosts (Hardware, Repos,
Netzwerk, Storage, alle Guests, Backup, Monitoring, Sicherheit, Wartung, DR)
und prüft parallel ~40 Best-Practice-Regeln mit `PASS`/`WARN`/`FAIL`/`INFO`.

Ergebnis ist ein Markdown-Report, der so an Claude gegeben werden kann, um
diese Dokumentation gegen die Realität abzugleichen.

```bash
sudo /usr/local/sbin/doc-audit.sh              # → /root/audit-<datum>.md
sudo /usr/local/sbin/doc-audit.sh --stdout     # direkt auf stdout
sudo /usr/local/sbin/doc-audit.sh -o /tmp/a.md
```

| Option        | Wirkung                                                     |
|---------------|-------------------------------------------------------------|
| `--stdout`    | Report auf stdout statt in Datei                            |
| `-o PFAD`     | eigener Ausgabepfad                                         |
| `--no-net`    | keine HTTP-Checks der LAN-/Public-Endpunkte                 |
| `--no-guests` | kein `pct exec`/`qm agent` in die Guests (deutlich schneller) |
| `--help`      | Kurzhilfe                                                   |

**Eigenschaften**

- **Read-only:** kein `apt`, kein `systemctl start/stop`, keine Config-Änderung.
  Einzige Schreiboperation ist die Report-Datei (`chmod 600`).
- **Redaktion:** Passwörter, Tokens, API-Keys, JWTs (Cloudflare-Tunnel-Token),
  `PVEAPIToken`-Werte, Private Keys und Disk-Seriennummern werden vor dem
  Schreiben maskiert. Trotzdem vor dem Weitergeben einmal durchsehen.
- **Laufzeit:** ca. 1–3 Minuten.

Die geprüften Endpunkte stehen als Arrays `LAN_ENDPOINTS` / `PUBLIC_ENDPOINTS`
am Kopf des Skripts — sie spiegeln die Tabellen aus [`../README.md`](../README.md).
Ändert sich ein Dienst, hier mitpflegen; ein `unreachable` im Report heißt
entweder "Dienst weg" oder "Doku veraltet".

## Installation

```bash
# Skripte kopieren
sudo cp scripts/backup-host-config.sh /usr/local/sbin/
sudo cp scripts/backup-host-config-pbs.sh /usr/local/sbin/
sudo cp scripts/repatch-no-nag.sh /usr/local/sbin/
sudo cp scripts/health-check.sh /usr/local/sbin/
sudo cp scripts/doc-audit.sh /usr/local/sbin/
sudo chmod +x /usr/local/sbin/backup-host-config*.sh /usr/local/sbin/repatch-no-nag.sh \
              /usr/local/sbin/health-check.sh /usr/local/sbin/doc-audit.sh

# systemd-Units
sudo cp scripts/backup-host-config*.service scripts/backup-host-config*.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now backup-host-config.timer backup-host-config-pbs.timer

# dpkg-Hook
sudo cp configs/apt/80pve-no-nag /etc/apt/apt.conf.d/
```

## Manuelle Ausführung

```bash
/usr/local/sbin/backup-host-config.sh
/usr/local/sbin/backup-host-config-pbs.sh
/usr/local/sbin/health-check.sh > /tmp/health.md && cat /tmp/health.md
/usr/local/sbin/doc-audit.sh && less /root/audit-$(date +%F).md
```
