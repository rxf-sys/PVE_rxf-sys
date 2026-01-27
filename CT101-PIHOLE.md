# CT 101 - Pi-hole (DNS + DHCP)

## Übersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 101 |
| **Hostname** | pi-hole |
| **IP-Adresse** | 192.168.2.122 |
| **RAM** | 1024 MB |
| **CPU** | 1 Core |
| **Disk** | 8 GB |
| **OS** | Debian |
| **Dienst** | Pi-hole v6 |

---

## Funktion

Pi-hole dient als:
- **DNS-Server:** Filtert Werbung und Tracking auf Netzwerkebene
- **DHCP-Server:** Verteilt IP-Adressen an alle Netzwerkgeräte
- **Lokaler DNS:** Löst `.home` Domainnamen auf

---

## Zugriff

| Dienst | URL |
|--------|-----|
| Web-Interface | http://192.168.2.122/admin |
| Mit lokalem DNS | http://pihole.home/admin |

### Zugangsdaten

| Parameter | Wert |
|-----------|------|
| Web-Passwort | `___________________` |

---

## Container-Konfiguration

**Datei:** `/etc/pve/lxc/101.conf`

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: pi-hole
memory: 1024
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,hwaddr=BC:24:11:44:B6:42,ip=192.168.2.122/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-101-disk-0,size=8G
swap: 1024
unprivileged: 1
```

---

## DHCP-Konfiguration

| Parameter | Wert |
|-----------|------|
| DHCP aktiviert | Ja |
| Bereich Start | 192.168.2.30 |
| Bereich Ende | 192.168.2.119 |
| Gateway | 192.168.2.1 |
| DNS-Server | 192.168.2.122 (Pi-hole selbst) |
| Lease-Zeit | 24 Stunden |
| Domain | home |

### Router-Konfiguration

Der Speedport Smart 4 Router hat DHCP **deaktiviert**. Pi-hole übernimmt die DHCP-Funktion für das gesamte Netzwerk.

---

## DNS-Konfiguration

### Upstream DNS-Server

| Server | Adresse |
|--------|---------|
| Cloudflare | 1.1.1.1 |
| Cloudflare | 1.0.0.1 |

### Lokale DNS-Einträge

**Datei (im Container):** `/etc/pihole/custom.list`

```
192.168.2.120 proxmox.home
192.168.2.121 nas.home
192.168.2.122 pihole.home
192.168.2.123 vpn.home
192.168.2.124 vault.home
192.168.2.125 proxy.home
192.168.2.126 jellyfin.home
```

---

## Blocklisten

Pi-hole blockiert Werbung und Tracking anhand von Blocklisten. Standardmäßig sind folgende Listen aktiv:

- Steven Black's Unified Hosts
- Pi-hole Default Lists

### Empfohlene zusätzliche Listen

Über Web-UI → Adlists hinzufügen:

```
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://adaway.org/hosts.txt
https://v.firebog.net/hosts/Easyprivacy.txt
```

---

## Verwaltung

### Status prüfen

```bash
pct exec 101 -- pihole status
```

### Blocklisten aktualisieren

```bash
pct exec 101 -- pihole -g
```

### DNS-Dienst neustarten

```bash
pct exec 101 -- pihole restartdns
```

### DHCP-Leases anzeigen

```bash
pct exec 101 -- cat /etc/pihole/dhcp.leases
```

### Passwort ändern

```bash
pct exec 101 -- pihole -a -p
```

### Lokalen DNS-Eintrag hinzufügen

```bash
pct exec 101 -- bash -c 'echo "192.168.2.127 neuerhost.home" >> /etc/pihole/custom.list'
pct exec 101 -- pihole restartdns
```

### Pi-hole Logs prüfen

```bash
pct exec 101 -- tail -100 /var/log/pihole/pihole.log
```

---

## Firewall

**Datei:** `/etc/pve/firewall/101.fw`

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# DNS (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 53 -log nolog
IN ACCEPT -source 192.168.2.0/24 -p udp -dport 53 -log nolog

# Web-UI (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 80 -log nolog

# DHCP Server
IN ACCEPT -p udp -dport 67 -log nolog
IN ACCEPT -p udp -sport 68 -dport 67 -log nolog

# ICMP/Ping
IN ACCEPT -p icmp
```

---

## Troubleshooting

### DNS funktioniert nicht

```bash
# Pi-hole Status
pct exec 101 -- pihole status

# DNS-Test vom Host
nslookup google.com 192.168.2.122

# DNS-Test für lokale Namen
nslookup nas.home 192.168.2.122
```

### DHCP funktioniert nicht

```bash
# DHCP-Leases prüfen
pct exec 101 -- cat /etc/pihole/dhcp.leases

# DHCP-Status in Pi-hole prüfen
pct exec 101 -- grep DHCP /etc/pihole/pihole.toml

# Pi-hole komplett neustarten
pct restart 101
```

### Gerät bekommt keine IP

1. Prüfen ob Router-DHCP wirklich deaktiviert ist
2. Gerät neu verbinden (WLAN aus/ein)
3. DHCP-Lease auf dem Gerät erneuern

### Webseite wird fälschlicherweise blockiert

1. Web-UI öffnen → Query Log
2. Blockierte Domain finden
3. Auf "Whitelist" klicken

Oder per Kommandozeile:

```bash
pct exec 101 -- pihole -w beispiel.de
```

---

## Statistiken

Im Web-Interface verfügbar:
- Gesamtzahl blockierter Anfragen
- Top blockierte Domains
- Top Clients
- Query-Log mit Echtzeitdaten

---

## Backup

### Wichtige Dateien

| Datei | Beschreibung |
|-------|--------------|
| `/etc/pihole/pihole.toml` | Hauptkonfiguration |
| `/etc/pihole/custom.list` | Lokale DNS-Einträge |
| `/etc/pihole/gravity.db` | Blocklisten-Datenbank |
| `/etc/pihole/dhcp.leases` | DHCP-Leases |

### Teleporter-Backup (empfohlen)

1. Web-UI → Settings → Teleporter
2. "Backup" klicken
3. ZIP-Datei herunterladen

### Container-Backup

```bash
vzdump 101 --storage local --compress zstd --mode snapshot
```

---

*CT 101 - Pi-hole | Server rxfsys*
