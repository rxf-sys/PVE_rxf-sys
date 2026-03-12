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
| SSH | Konfiguriert | Key-basiert, Root-Login |
| Firewall | Aktiv | Proxmox Firewall |
| SSL/TLS | Aktiv | Let's Encrypt via Nginx PM |
| VPN | Aktiv | WireGuard (extern) |
| 2FA | <!-- Status --> | Proxmox Web-UI |
| Passwort-Manager | Aktiv | Vaultwarden (extern via HTTPS) |
| DNS-Filterung | Aktiv | Pi-hole Werbeblocker |
