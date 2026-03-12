# System-Haertung

## SSH-Hardening

### /etc/ssh/sshd_config

```bash
# Empfohlene Einstellungen
Port 22                          # Standard-Port (oder aendern)
PermitRootLogin prohibit-password  # Nur mit SSH-Key
PasswordAuthentication no        # Keine Passwort-Anmeldung
PubkeyAuthentication yes         # SSH-Keys aktiviert
MaxAuthTries 3                   # Max. Anmeldeversuche
ClientAliveInterval 300          # Timeout nach 5 Minuten
ClientAliveCountMax 2            # Max. 2 Keep-Alive
```

### SSH-Key einrichten

```bash
# Auf dem Client: Key generieren
ssh-keygen -t ed25519 -C "homelab"

# Key auf Server kopieren
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.2.120

# Testen
ssh root@192.168.2.120

# Danach Passwort-Login deaktivieren (siehe oben)
systemctl restart sshd
```

## Fail2Ban (optional)

```bash
# Installation
apt install fail2ban

# Konfiguration
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log

[proxmox]
enabled = true
port = https,http,8006
filter = proxmox
logpath = /var/log/daemon.log
maxretry = 3
bantime = 3600
EOF

# Proxmox-Filter erstellen
cat > /etc/fail2ban/filter.d/proxmox.conf << 'EOF'
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
EOF

systemctl enable fail2ban
systemctl start fail2ban
```

### Fail2Ban Befehle

```bash
# Status anzeigen
fail2ban-client status
fail2ban-client status sshd

# Gebannte IPs anzeigen
fail2ban-client status sshd | grep "Banned IP"

# IP entbannen
fail2ban-client set sshd unbanip <IP>
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

- [ ] SSH nur mit Key-Authentifizierung
- [ ] Proxmox Web-UI mit 2FA
- [ ] Fail2Ban installiert und aktiv
- [ ] Firewall-Regeln konfiguriert
- [ ] Keine Standard-Passwoerter
- [ ] Alle Passwoerter in Vaultwarden gespeichert
- [ ] Let's Encrypt fuer externe Dienste
- [ ] Regelmaessige Updates
- [ ] Port-Forwarding nur fuer WireGuard und Nginx
- [ ] Vaultwarden nur via HTTPS erreichbar
