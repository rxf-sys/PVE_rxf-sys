# System-Haertung

## SSH-Hardening

> **Status (13.03.2026):** SSH-Haertung umgesetzt. Root-Login nur mit SSH-Key, Passwort-Authentifizierung deaktiviert.

### /etc/ssh/sshd_config.d/hardening.conf

```bash
PermitRootLogin prohibit-password  # Nur mit SSH-Key
PasswordAuthentication no          # Keine Passwort-Anmeldung
PubkeyAuthentication yes           # SSH-Keys aktiviert
MaxAuthTries 3                     # Max. Anmeldeversuche
ClientAliveInterval 300            # Timeout nach 5 Minuten
ClientAliveCountMax 2              # Max. 2 Keep-Alive
```

### SSH-Key einrichten

```bash
# 1. Auf dem Client: Key generieren
ssh-keygen -t ed25519 -C "homelab"

# 2. Key auf Server kopieren
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.2.120

# 3. Testen ob Key-Login funktioniert
ssh root@192.168.2.120

# 4. Erst NACH erfolgreichem Key-Login: Haertung aktivieren
cat > /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# 5. Konfiguration pruefen (muss fehlerfrei sein!)
sshd -t

# 6. Neustart
systemctl restart sshd

# 7. WICHTIG: In einer NEUEN Session testen bevor alte geschlossen wird!
```

## Fail2Ban

> **Status (13.03.2026):** Fail2ban aktiv mit SSH-Jail und Proxmox-Jail.

### Installation und Konfiguration

```bash
apt install fail2ban -y
systemctl enable --now fail2ban
```

### Proxmox-Jail (`/etc/fail2ban/jail.d/proxmox.conf`)

```ini
[proxmox]
enabled = true
port = https,http,8006
filter = proxmox
backend = systemd
maxretry = 3
findtime = 600
bantime = 3600
```

### Proxmox-Filter (`/etc/fail2ban/filter.d/proxmox.conf`)

```ini
[Definition]
failregex = pvedaemon\[.*authentication (verification )?failure; rhost=<HOST>
ignoreregex =
```

### Fail2Ban Befehle

```bash
# Status anzeigen
fail2ban-client status
fail2ban-client status sshd
fail2ban-client status proxmox

# Gebannte IPs anzeigen
fail2ban-client status sshd | grep "Banned IP"
fail2ban-client status proxmox | grep "Banned IP"

# IP entbannen
fail2ban-client set sshd unbanip <IP>
fail2ban-client set proxmox unbanip <IP>
```

## Automatische Updates

```bash
# Unattended-Upgrades installieren
apt install unattended-upgrades

# Konfigurieren
dpkg-reconfigure unattended-upgrades
```

## Firewall

Siehe [03-netzwerk/firewall.md](../03-netzwerk/firewall.md)

## Checkliste Sicherheit

- [x] SSH nur mit Key-Authentifizierung (umgesetzt 13.03.2026)
- [x] Proxmox Web-UI mit 2FA (TOTP, umgesetzt 13.03.2026)
- [x] Fail2Ban aktiv mit SSH- und Proxmox-Jail (umgesetzt 13.03.2026)
- [x] Firewall-Regeln fuer alle Container konfiguriert (inkl. CT 105, 109, 110, 111)
- [ ] Keine Standard-Passwoerter
- [ ] Alle Passwoerter in Vaultwarden gespeichert
- [x] Let's Encrypt fuer externe Dienste
- [ ] Regelmaessige Updates
- [x] Port-Forwarding nur fuer WireGuard und Nginx
- [x] Vaultwarden nur via HTTPS erreichbar (Source-Beschraenkung auf Nginx-IP)
