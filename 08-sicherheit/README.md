# Sicherheit

Security-Konzept fuer den Proxmox Server und alle Dienste.

| Dokument | Beschreibung |
|----------|--------------|
| [benutzer-rollen.md](benutzer-rollen.md) | PVE Users, API Tokens, Berechtigungen |
| [zertifikate.md](zertifikate.md) | Let's Encrypt, SSL/TLS |
| [2fa.md](2fa.md) | Zwei-Faktor-Authentifizierung |
| [haertung.md](haertung.md) | SSH-Hardening, Fail2Ban, Updates |

## Sicherheits-Uebersicht

| Bereich | Status | Beschreibung |
|---------|--------|--------------|
| SSH | Gehaertet | Key-only, kein Passwort (`prohibit-password`) |
| Firewall | Aktiv | Proxmox Firewall, alle 12 Container mit Regeln |
| Fail2Ban | Aktiv | SSH-Jail + Proxmox-Jail (Port 8006) |
| SSL/TLS | Aktiv | Let's Encrypt via Nginx PM |
| VPN | Aktiv | WireGuard (extern) |
| 2FA | Aktiv | Proxmox Web-UI (TOTP) |
| Passwort-Manager | Aktiv | Vaultwarden (extern via HTTPS) |
| DNS-Filterung | Aktiv | Pi-hole Werbeblocker |
