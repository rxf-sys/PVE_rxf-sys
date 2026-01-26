# 🖥️ Home-Server rxfsys

> Proxmox VE Home-Server mit NAS, Pi-hole, WireGuard VPN, Vaultwarden und Nginx Reverse Proxy

---

## 📋 Quick Info

| | |
|---|---|
| **Host** | rxfsys |
| **OS** | Proxmox VE 9.1.1 |
| **CPU** | Intel Core i5-9500T (6 Cores) |
| **RAM** | 32 GB DDR4 |
| **Storage** | 500GB NVMe (System) + 500GB SSD (Data) |

---

## 🌐 Netzwerk-Übersicht

```
┌──────────────────────────────────────────────────────────┐
│                    HEIMNETZWERK                          │
│                   192.168.2.0/24                         │
├──────────────────────────────────────────────────────────┤
│                                                          │
│   🖥️ PROXMOX HOST                                        │
│   192.168.2.120                                          │
│   https://192.168.2.120:8006                             │
│                                                          │
│   ┌────────────────────────────────────────────────┐     │
│   │ Container                                      │     │
│   ├────────────────────────────────────────────────┤     │
│   │ 📁 CT 100 - NAS          192.168.2.121        │     │
│   │ 🛡️ CT 101 - Pi-hole      192.168.2.122        │     │
│   │ 🔐 CT 102 - WireGuard    192.168.2.123        │     │
│   │ 🔑 CT 103 - Vaultwarden  192.168.2.124        │     │
│   │ 🌐 CT 104 - Nginx-Proxy  192.168.2.125        │     │
│   └────────────────────────────────────────────────┘     │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## 🔗 Wichtige URLs

| Dienst | URL | Beschreibung |
|--------|-----|--------------|
| **Proxmox** | https://192.168.2.120:8006 | Server-Verwaltung |
| **Pi-hole** | http://192.168.2.122/admin | DNS & Werbeblocker |
| **WireGuard** | http://192.168.2.123:51821 | VPN-Verwaltung |
| **Nginx PM** | http://192.168.2.125:81 | Reverse Proxy Admin |
| **NAS** | `\\192.168.2.121\shared` | Dateifreigabe |

---

## 📦 Container

| ID | Name | IP | RAM | Funktion |
|----|------|-----|-----|----------|
| 100 | nas | .121 | 1 GB | Samba Dateiserver |
| 101 | pi-hole | .122 | 1 GB | DNS + Werbeblocker |
| 102 | wireguard | .123 | 1 GB | VPN Server |
| 103 | vaultwarden | .124 | 2 GB | Passwort-Manager |
| 104 | nginx-proxy | .125 | 1 GB | Reverse Proxy |

---

## 💾 Storage

| Disk | Mount | Größe | Verwendung |
|------|-------|-------|------------|
| NVMe | `/` | 500 GB | Proxmox + Container |
| SSD | `/mnt/storage` | 500 GB | Daten, Medien |
| SSD | `/mnt/backups` | 500 GB | Backups (TODO) |

---

## 🔥 Firewall-Ports

| Container | Ports | Zugriff |
|-----------|-------|---------|
| Host | 8006, 22 | Nur LAN |
| NAS | 445, 139 | Nur LAN |
| Pi-hole | 53, 80 | Nur LAN |
| WireGuard | 51820/UDP | **Extern** (VPN) |
| WireGuard | 51821 | Nur LAN |
| Nginx | 80, 443 | **Extern** |
| Nginx | 81 | Nur LAN |
| Vaultwarden | 80 | Nur von Nginx |

---

## ⚡ Schnellbefehle

### Container verwalten

```bash
# Alle Container anzeigen
pct list

# Container starten/stoppen
pct start 100
pct stop 100

# In Container einloggen
pct enter 100

# Alle IPs anzeigen
for i in $(pct list | awk 'NR>1 {print $1}'); do
  echo -n "CT $i: "; pct exec $i -- hostname -I
done
```

### System

```bash
# Updates
apt update && apt full-upgrade -y

# Storage prüfen
df -h

# SMART-Status
smartctl -H /dev/sda
smartctl -H /dev/nvme0n1
```

### Backup

```bash
# Container sichern
vzdump 100 --storage local --compress zstd
```

### Firewall

```bash
# Status
pve-firewall status

# Notfall: Deaktivieren
pve-firewall stop
```

---

## 📁 Dateistruktur

```
/mnt/storage/
├── shared/       # Samba-Freigaben
├── media/        # Filme, Musik, Fotos
├── backups/      # Daten-Backups
└── appdata/      # Container-Daten

/etc/pve/firewall/
├── cluster.fw    # Datacenter-Regeln
├── 100.fw        # NAS
├── 101.fw        # Pi-hole
├── 102.fw        # WireGuard
├── 103.fw        # Vaultwarden
└── 104.fw        # Nginx-Proxy
```

---

## 🛠️ Wartung

### Monatlich

- [ ] `apt update && apt full-upgrade` (Host)
- [ ] Container updaten
- [ ] SMART-Status prüfen
- [ ] Backups prüfen
- [ ] Logs auf Fehler checken

### Vor Updates

- [ ] Snapshot erstellen
- [ ] Release Notes lesen

---

## 🆘 Notfall

### Proxmox nicht erreichbar?

```bash
# Am Server direkt:
systemctl status pveproxy
pve-firewall stop
```

### Container startet nicht?

```bash
journalctl -xe
pct config 100
```

### Ausgesperrt durch Firewall?

```bash
# Am Server mit Tastatur/Monitor:
pve-firewall stop
```

---

## 📚 Dokumentation

| Datei | Inhalt |
|-------|--------|
| `README.md` | Diese Übersicht |
| `homeserver-dokumentation.md` | Ausführliche Doku |
| `anleitung-kritische-verbesserungen.md` | Setup-Anleitungen |
| `anleitung-mittelfristige-verbesserungen.md` | Weitere Anleitungen |
| `firewall-setup.sh` | Firewall-Konfiguration |

---

## 📞 Support

- **Proxmox Wiki:** https://pve.proxmox.com/wiki/
- **Proxmox Forum:** https://forum.proxmox.com/

---

*Server: rxfsys | Stand: 2025-01-26*
