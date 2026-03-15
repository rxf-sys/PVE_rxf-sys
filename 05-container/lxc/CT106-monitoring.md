# CT 106 - Monitoring (Prometheus + Grafana)

## Uebersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 106 |
| **Hostname** | monitoring |
| **IP-Adresse** | 192.168.2.127 |
| **RAM** | 2048 MB |
| **CPU** | 2 Cores |
| **Disk** | 15 GB |
| **OS** | Debian Trixie |
| **Dienste** | Prometheus + Grafana |

> **Hinweis:** Grafana wurde von CT 107 hierher migriert. CT 107 ist aufgeloest.

---

## Funktion

- **Prometheus:** Sammelt Metriken von allen Servern und Containern (Scrape alle 15s)
- **Grafana:** Visualisiert die Metriken in interaktiven Dashboards
- **Node-Exporter:** Exportiert Host-Metriken fuer Prometheus

Beide Dienste auf einem Container reduziert Latenz (Grafana greift lokal auf Prometheus zu) und spart Ressourcen.

---

## Zugriff

| Dienst | URL |
|--------|-----|
| Grafana | http://192.168.2.127:3000 |
| Prometheus | http://192.168.2.127:9090 |
| Mit lokalem DNS | http://grafana.home:3000 |
| Mit lokalem DNS | http://monitoring.home:9090 |
| Prometheus Targets | http://monitoring.home:9090/targets |

### Grafana Zugangsdaten

| Parameter | Wert |
|-----------|------|
| Admin-Benutzer | `admin` |
| Passwort | `___________________` |

---

## Container-Konfiguration

**Datei:** `/etc/pve/lxc/106.conf`

```ini
arch: amd64
cores: 2
features: nesting=1
hostname: monitoring
memory: 2048
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,ip=192.168.2.127/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-106-disk-0,size=15G
swap: 0
unprivileged: 1
cpulimit: 2
```

---

## Prometheus-Konfiguration

**Datei (im Container):** `/etc/prometheus/prometheus.yml`

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "proxmox-host"
    static_configs:
      - targets: ["192.168.2.120:9100"]
        labels:
          instance: "rxfsys-host"

  - job_name: "containers"
    static_configs:
      - targets:
          - "192.168.2.121:9100"  # CT 100 - Samba
          - "192.168.2.122:9100"  # CT 101 - Pi-hole
          - "192.168.2.123:9100"  # CT 102 - WireGuard
          - "192.168.2.124:9100"  # CT 103 - Vaultwarden
          - "192.168.2.125:9100"  # CT 104 - Nginx PM
          - "192.168.2.126:9100"  # CT 105 - Jellyfin
          - "localhost:9100"      # CT 106 - Monitoring (lokal)
          - "192.168.2.129:9100"  # CT 108 - PBS
          - "192.168.2.130:9100"  # CT 109 - Home Assistant
          - "192.168.2.131:9100"  # CT 110 - Paperless
          - "192.168.2.132:9100"  # CT 111 - Finanzguru
        labels:
          environment: "homeserver"
```

### Prometheus Service

**Datei:** `/etc/systemd/system/prometheus.service`

```ini
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --storage.tsdb.retention.time=30d

[Install]
WantedBy=multi-user.target
```

---

## Grafana-Konfiguration

**Datei (im Container):** `/etc/grafana/grafana.ini`

```ini
[server]
http_addr = 0.0.0.0
http_port = 3000

[security]
admin_user = admin

[users]
allow_sign_up = false

[auth.anonymous]
enabled = false
```

### Datasource (automatisch provisioniert)

**Datei:** `/etc/grafana/provisioning/datasources/datasources.yml`

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
```

### Empfohlene Dashboards

| ID | Name | Beschreibung |
|----|------|--------------|
| 1860 | Node Exporter Full | Vollstaendiges System-Monitoring |
| 11074 | Node Exporter for Prometheus | Kompakte Uebersicht |
| 13659 | Blackbox Exporter | Uptime-Monitoring |

---

## Verwaltung

```bash
# === Prometheus ===
pct exec 106 -- systemctl status prometheus
pct exec 106 -- systemctl restart prometheus
pct exec 106 -- journalctl -u prometheus -n 50
pct exec 106 -- promtool check config /etc/prometheus/prometheus.yml

# === Grafana ===
pct exec 106 -- systemctl status grafana-server
pct exec 106 -- systemctl restart grafana-server
pct exec 106 -- journalctl -u grafana-server -n 50

# Grafana Passwort zuruecksetzen
pct exec 106 -- grafana-cli admin reset-admin-password NEUES_PASSWORT
```

---

## Node Exporter hinzufuegen

Um einen neuen Host zu ueberwachen:

```bash
# Auf dem Ziel-Host/Container installieren
apt install prometheus-node-exporter

# Dann in prometheus.yml auf CT 106 den Target hinzufuegen
# und Prometheus neustarten
pct exec 106 -- systemctl restart prometheus
```

---

## Firewall

**Datei:** `/etc/pve/firewall/106.fw`

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Prometheus Web-UI (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 9090 -log nolog

# Grafana Web-UI (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 3000 -log nolog

# Node-Exporter (Monitoring)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 9100 -log nolog

# ICMP/Ping
IN ACCEPT -p icmp
```

---

## Wichtige Pfade

| Pfad | Beschreibung |
|------|--------------|
| `/etc/prometheus/prometheus.yml` | Prometheus Hauptkonfiguration |
| `/var/lib/prometheus/` | Prometheus Time-Series Datenbank |
| `/etc/grafana/grafana.ini` | Grafana Hauptkonfiguration |
| `/var/lib/grafana/` | Grafana Datenbank, Plugins |
| `/var/lib/grafana/grafana.db` | Grafana SQLite-Datenbank |

---

## Backup

```bash
# Container-Backup
vzdump 106 --storage backup-ssd --compress zstd --mode snapshot

# Nur Konfigurationen
pct exec 106 -- tar -czf /root/monitoring-config.tar.gz \
    /etc/prometheus/ /etc/grafana/ /var/lib/grafana/

# Grafana Dashboards exportieren (API)
curl -s http://admin:PASSWORT@192.168.2.127:3000/api/search | jq '.[].uri'
```

---

*CT 106 - Monitoring (Prometheus + Grafana) | Server rxfsys*
