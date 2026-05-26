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

## Installation

```bash
# Skripte kopieren
sudo cp scripts/backup-host-config.sh /usr/local/sbin/
sudo cp scripts/backup-host-config-pbs.sh /usr/local/sbin/
sudo cp scripts/repatch-no-nag.sh /usr/local/sbin/
sudo cp scripts/health-check.sh /usr/local/sbin/
sudo chmod +x /usr/local/sbin/backup-host-config*.sh /usr/local/sbin/repatch-no-nag.sh /usr/local/sbin/health-check.sh

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
```
