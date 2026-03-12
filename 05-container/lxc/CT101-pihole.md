# CT 101 - Pi-hole (DNS + DHCP)

## Übersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 101 |
| **Hostname** | pi-hole |
| **IP-Adresse** | 192.168.2.122 |
| **RAM** | 2048 MB |
| **CPU** | 2 Cores |
| **Disk** | 8 GB |
| **OS** | Debian Trixie |
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
cores: 2
features: nesting=1
hostname: pi-hole
memory: 2048
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,hwaddr=BC:24:11:44:B6:42,ip=192.168.2.122/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-101-disk-0,size=8G
swap: 2048
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
192.168.2.120 server.home
192.168.2.121 samba.home
192.168.2.122 pihole.home
192.168.2.122 dns.home
192.168.2.123 vpn.home
192.168.2.123 wg.home
192.168.2.123 wireguard.home
192.168.2.124 vault.home
192.168.2.124 vaultwarden.home
192.168.2.124 bitwarden.home
192.168.2.125 proxy.home
192.168.2.125 nginx.home
192.168.2.126 jellyfin.home
192.168.2.127 prometheus.home
192.168.2.128 grafana.home
192.168.2.129 pbs.home
192.168.2.130 homeassistant.home
192.168.2.131 paperless.home
```

---

## Verwaltung

```bash
# Status prüfen
pct exec 101 -- pihole status

# Blocklisten aktualisieren
pct exec 101 -- pihole -g

# DNS-Dienst neustarten
pct exec 101 -- pihole restartdns

# Passwort ändern
pct exec 101 -- pihole -a -p

# Lokalen DNS-Eintrag hinzufügen
pct exec 101 -- bash -c 'echo "192.168.2.132 neuerhost.home" >> /etc/pihole/custom.list'
pct exec 101 -- pihole restartdns

# Logs prüfen
pct exec 101 -- tail -100 /var/log/pihole/pihole.log

# DNS-Test
pct exec 101 -- dig @127.0.0.1 google.com +short
pct exec 101 -- dig @127.0.0.1 jellyfin.home +short
```

---

## Pi-hole v6 Besonderheiten

Pi-hole v6 verwendet eine neue Konfigurationsstruktur:

| Alt (v5) | Neu (v6) |
|----------|----------|
| `/etc/pihole/setupVars.conf` | `/etc/pihole/pihole.toml` |
| `/etc/pihole/dhcp.leases` | Integriert in FTL-Datenbank |

### DHCP-Leases anzeigen (v6)

```bash
pct exec 101 -- pihole-FTL --dhcp-leases
# Oder im Web-UI: Settings → DHCP
```

---

## Blocklisten

Pi-hole blockiert Werbung und Tracking anhand von Blocklisten. Empfohlene zusätzliche Listen:

```
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://adaway.org/hosts.txt
https://v.firebog.net/hosts/Easyprivacy.txt
https://v.firebog.net/hosts/AdguardDNS.txt
```

Hinzufügen: **Web-UI** → **Adlists** → **Add**

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
nslookup jellyfin.home 192.168.2.122
```

### Gerät bekommt keine IP

1. Prüfen ob Router-DHCP wirklich deaktiviert ist
2. Gerät neu verbinden (WLAN aus/ein)
3. Pi-hole neustarten: `pct restart 101`

### Webseite wird fälschlicherweise blockiert

```bash
# Per Whitelist
pct exec 101 -- pihole -w beispiel.de

# Oder im Web-UI: Query Log → Whitelist
```

---

## Backup

### Wichtige Dateien

| Datei | Beschreibung |
|-------|--------------|
| `/etc/pihole/pihole.toml` | Hauptkonfiguration (v6) |
| `/etc/pihole/custom.list` | Lokale DNS-Einträge |
| `/etc/pihole/gravity.db` | Blocklisten-Datenbank |

### Teleporter-Backup (empfohlen)

1. **Web-UI** → **Settings** → **Teleporter**
2. **Backup** klicken
3. ZIP-Datei herunterladen

### Container-Backup

```bash
vzdump 101 --storage local --compress zstd --mode snapshot
```

---

*CT 101 - Pi-hole | Server rxfsys*