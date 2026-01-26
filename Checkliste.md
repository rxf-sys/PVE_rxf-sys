GRUNDKONFIGURATION
──────────────────────────────────────────────────────────
[ ] Proxmox Updates eingespielt (apt update && apt full-upgrade)
[ ] No-Subscription Repository konfiguriert
[ ] Root-Passwort sicher (>12 Zeichen, komplex)
[ ] Netzwerk: Bridge vmbr0 funktioniert
[ ] Host hat statische IP (192.168.2.120)

STORAGE
──────────────────────────────────────────────────────────
[ ] Storage-SSD (/dev/sda) korrekt gemountet unter /mnt/storage
[ ] fstab-Eintrag vorhanden (UUID-basiert)
[ ] Backup-SSD eingebunden
[ ] Ordnerstruktur angelegt (/mnt/storage/shared, /media, /backups)
[ ] Berechtigungen korrekt gesetzt

CONTAINER - NAS (CT 100)
──────────────────────────────────────────────────────────
[ ] Mountpoint zeigt auf /mnt/storage/shared (nicht LVM!)
[ ] Samba installiert und konfiguriert
[ ] Samba-User angelegt
[ ] Freigabe von Windows/Mac erreichbar
[ ] Berechtigungen (UID/GID) stimmen

CONTAINER - Pi-hole (CT 101)
──────────────────────────────────────────────────────────
[ ] Statische IP: 192.168.2.122 ✓
[ ] Pi-hole Web-UI erreichbar (http://192.168.2.122/admin)
[ ] Upstream-DNS konfiguriert
[ ] Router nutzt Pi-hole als DNS
[ ] Blocklisten aktiv

CONTAINER - WireGuard (CT 102)
──────────────────────────────────────────────────────────
[ ] Statische IP vergeben
[ ] WireGuard/wg-easy installiert
[ ] Server-Keys generiert
[ ] Client-Config erstellt
[ ] Port 51820/UDP im Router freigegeben
[ ] VPN-Verbindung von extern getestet

CONTAINER - Vaultwarden (CT 103)
──────────────────────────────────────────────────────────
[ ] Statische IP vergeben
[ ] HTTPS konfiguriert (via Nginx-Proxy)
[ ] Admin-Token gesetzt
[ ] Backup der SQLite-DB eingerichtet
[ ] Von extern nur via VPN oder HTTPS erreichbar

CONTAINER - Nginx-Proxy (CT 104)
──────────────────────────────────────────────────────────
[ ] Statische IP vergeben
[ ] SSL-Zertifikate konfiguriert
[ ] Reverse-Proxy-Regeln für Services
[ ] Fail2Ban oder Rate-Limiting aktiv

BACKUPS
──────────────────────────────────────────────────────────
[ ] Backup-Storage in Proxmox angelegt
[ ] Backup-Schedule konfiguriert (Datacenter → Backup)
[ ] Retention/Prune-Regeln definiert
[ ] Test-Restore durchgeführt
[ ] Offsite-Backup geplant (3-2-1 Regel)

SICHERHEIT
──────────────────────────────────────────────────────────
[ ] Proxmox nur im LAN erreichbar (nicht ins Internet)
[ ] Firewall-Regeln geprüft
[ ] SSH-Keys statt Passwort (optional)
[ ] Fail2Ban auf Host (optional)
[ ] 2FA für Proxmox aktiviert (optional)

MONITORING
──────────────────────────────────────────────────────────
[ ] SMART-Tools installiert (smartmontools)
[ ] E-Mail-Benachrichtigung bei Problemen (optional)
[ ] Regelmäßige Update-Routine geplant
