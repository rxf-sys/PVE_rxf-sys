# CT 107 - Grafana (Dashboards)

## Übersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 107 |
| **Hostname** | grafana |
| **IP-Adresse** | 192.168.2.128 |
| **RAM** | 1024 MB |
| **CPU** | 1 Core |
| **Disk** | 8 GB |
| **OS** | Debian Trixie |
| **Dienst** | Grafana |

---

## Funktion

Grafana visualisiert Metriken aus Prometheus und anderen Datenquellen in interaktiven Dashboards. Ideal für System-Monitoring, Netzwerk-Übersicht und Alerting.

---

## Zugriff

| Dienst | URL |
|--------|-----|
| Web-Interface | http://192.168.2.128:3000 |
| Mit lokalem DNS | http://grafana.home:3000 |

### Zugangsdaten

| Parameter | Wert |
|-----------|------|
| Admin-Benutzer | `admin` |
| Passwort | `___________________` |

**Standard-Login (nach Erstinstallation):**
- Benutzer: `admin`
- Passwort: `admin` (muss beim ersten Login geändert werden)

---

## Container-Konfiguration

**Datei:** `/etc/pve/lxc/107.conf`

```ini
arch: amd64
cores: 1
features: nesting=1
hostname: grafana
memory: 1024
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,ip=192.168.2.128/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-107-disk-0,size=8G
swap: 1024
unprivileged: 1
```

---

## Datenquellen einrichten

### Prometheus hinzufügen

1. **Configuration** → **Data Sources** → **Add data source**
2. **Prometheus** auswählen
3. **URL:** `http://192.168.2.127:9090`
4. **Save & Test**

---

## Empfohlene Dashboards

### Node Exporter Dashboard

1. **Dashboards** → **Import**
2. Dashboard-ID eingeben: `1860`
3. Datenquelle: Prometheus
4. **Import**

### Weitere nützliche Dashboards

| ID | Name | Beschreibung |
|----|------|--------------|
| 1860 | Node Exporter Full | Vollständiges System-Monitoring |
| 11074 | Node Exporter for Prometheus | Kompakte Übersicht |
| 13659 | Blackbox Exporter | Uptime-Monitoring |

---

## Verwaltung

```bash
# Status prüfen
pct exec 107 -- systemctl status grafana-server

# Neustarten
pct exec 107 -- systemctl restart grafana-server

# Logs anzeigen
pct exec 107 -- journalctl -u grafana-server -n 50

# Passwort zurücksetzen
pct exec 107 -- grafana-cli admin reset-admin-password NEUES_PASSWORT
```

---

## Grafana-Konfiguration

**Datei (im Container):** `/etc/grafana/grafana.ini`

Wichtige Einstellungen:

```ini
[server]
http_addr = 0.0.0.0
http_port = 3000

[security]
admin_user = admin
# admin_password wird beim ersten Login gesetzt

[users]
allow_sign_up = false

[auth.anonymous]
enabled = false
```

---

## Firewall

**Datei:** `/etc/pve/firewall/107.fw`

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Grafana Web-UI (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 3000 -log nolog

# ICMP/Ping
IN ACCEPT -p icmp
```

---

## Wichtige Pfade

| Pfad | Beschreibung |
|------|--------------|
| `/etc/grafana/grafana.ini` | Hauptkonfiguration |
| `/var/lib/grafana/` | Datenbank, Plugins |
| `/var/lib/grafana/grafana.db` | SQLite-Datenbank |

---

## Backup

```bash
# Container-Backup
vzdump 107 --storage local --compress zstd --mode snapshot

# Nur Grafana-Daten
pct exec 107 -- tar -czf /root/grafana-backup.tar.gz /var/lib/grafana/ /etc/grafana/
```

---

## Alerting (optional)

Grafana kann bei Schwellenwert-Überschreitungen Benachrichtigungen senden:

1. **Alerting** → **Notification channels**
2. Kanal hinzufügen (E-Mail, Telegram, Slack, etc.)
3. In Dashboard-Panels Alert-Regeln definieren

---

*CT 107 - Grafana | Server rxfsys*