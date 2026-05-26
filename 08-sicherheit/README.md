# 08 — Sicherheit

| Bereich            | Status / Tool                                        |
|--------------------|------------------------------------------------------|
| PVE-Firewall       | enabled (cluster + host + per-CT), siehe [firewall.md](firewall.md) |
| fail2ban           | aktiv (jail sshd), siehe [fail2ban.md](fail2ban.md) |
| SSH                | PermitRootLogin yes + PasswordAuth yes (LAN-only, Single-User, mit Konsolen-Zugriff) |
| Tokens             | dediziert pro Service, dokumentiert in [tokens.md](tokens.md) |
| Subscription-Nag   | gepatcht via dpkg-Hook                               |
| Updates            | regelmäßig (siehe [../09-wartung/](../09-wartung/)) |
| Notifications      | Strato SMTP für Backup-Failures                      |
| External Access    | nur via Cloudflare Tunnel (Zero Trust)               |

## Annahmen

- Heim-LAN, vertrauenswürdige Geräte
- Konsolen-Zugriff am Host (für Lockout-Recovery)
- Single-Admin-Setup
