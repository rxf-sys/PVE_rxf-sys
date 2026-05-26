# fail2ban

Installiert auf PVE-Host als Brute-Force-Schutz für SSH.

## Konfiguration

Datei: `/etc/fail2ban/jail.d/sshd-rxf-sys.local`

```ini
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 192.168.2.0/24
backend = systemd
findtime = 10m
maxretry = 5
bantime = 1h

[sshd]
enabled = true
mode    = aggressive
port    = 22
```

Bedeutung:
- Erlaubt 5 Fehlversuche in 10 Minuten
- Bei 6. Versuch: 1 Stunde Sperre
- LAN (192.168.2.0/24) ist `ignoreip` → kein Selbst-Lockout

## Status

```bash
systemctl status fail2ban
fail2ban-client status
fail2ban-client status sshd
```

Output zeigt:
- Currently failed
- Total failed
- Currently banned
- Total banned
- Banned IP list

## Ban manuell

```bash
fail2ban-client set sshd banip 1.2.3.4
fail2ban-client set sshd unbanip 1.2.3.4
```

## iptables-Chain

Beim ersten Ban wird `f2b-sshd` Chain erstellt:
```bash
iptables -L f2b-sshd -n
```

## Nicht installiert in den Guests

Nur am Host. CT/VM intern haben keine fail2ban — sind aber auch nicht extern erreichbar (außer via Cloudflare Tunnel, der nicht direkt SSH exponiert).
