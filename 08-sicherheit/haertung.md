# System-Haertung

## SSH-Hardening

> **Status (13.03.2026):** `PermitRootLogin yes` ist aktiv - Root-Login mit Passwort moeglich!
> SSH-Haertung ist noch nicht umgesetzt. Siehe Anleitung unten.

### /etc/ssh/sshd_config

Empfohlene Einstellungen als Drop-in Datei (`/etc/ssh/sshd_config.d/hardening.conf`):

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

> **Status (13.03.2026):** Fail2ban ist installiert (v1.1.0-8).

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

- [ ] SSH nur mit Key-Authentifizierung (**OFFEN** - aktuell Passwort erlaubt)
- [ ] Proxmox Web-UI mit 2FA (**OFFEN**)
- [x] Fail2Ban installiert und aktiv
- [x] Firewall-Regeln konfiguriert (CT 105, 109, 110, 111 fehlen noch)
- [ ] Keine Standard-Passwoerter
- [ ] Alle Passwoerter in Vaultwarden gespeichert
- [x] Let's Encrypt fuer externe Dienste
- [ ] Regelmaessige Updates
- [x] Port-Forwarding nur fuer WireGuard und Nginx
- [x] Vaultwarden nur via HTTPS erreichbar (Source-Beschraenkung auf Nginx-IP)
