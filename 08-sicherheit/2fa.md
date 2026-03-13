# Zwei-Faktor-Authentifizierung (2FA)

## Proxmox Web-UI

### TOTP einrichten

1. Proxmox Web-UI oeffnen: https://192.168.2.120:8006
2. Datacenter -> Permissions -> Two Factor
3. "Add" -> "TOTP"
4. QR-Code mit Authenticator-App scannen (z.B. Bitwarden, Google Authenticator)
5. Verifizierungscode eingeben
6. Speichern

### Recovery Keys

Nach der 2FA-Einrichtung **unbedingt Recovery Keys erstellen**:

1. Datacenter -> Permissions -> Two Factor
2. "Add" -> "Recovery Keys"
3. Keys sicher speichern (z.B. in Vaultwarden)

> **Wichtig:** Recovery Keys sind der einzige Weg zurueck, wenn die Authenticator-App nicht verfuegbar ist!

## Vaultwarden

Vaultwarden unterstuetzt 2FA fuer Benutzer-Accounts:

1. Vaultwarden Web-UI oeffnen
2. Einstellungen -> Sicherheit -> Zwei-Faktor-Authentifizierung
3. Authenticator-App aktivieren

## Status

| Dienst | 2FA | Status |
|--------|-----|--------|
| Proxmox Web-UI | TOTP | Aktiv (13.03.2026) |
| Vaultwarden | TOTP | Empfohlen |
| SSH | Key-basiert (kein Passwort) | Aktiv (13.03.2026) |
