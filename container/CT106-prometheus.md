# CT 106 - Prometheus (Monitoring)

## Übersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 106 |
| **Hostname** | prometheus |
| **IP-Adresse** | 192.168.2.127 |
| **RAM** | 2048 MB |
| **CPU** | 2 Cores |
| **Disk** | 15 GB |
| **OS** | Debian Trixie |
| **Dienst** | Prometheus |

---

## Funktion

Prometheus sammelt Metriken von allen Servern und Diensten im Netzwerk. Die Daten werden in einer Time-Series-Datenbank gespeichert und können über Grafana visualisiert werden.

---

## Zugriff

| Dienst | URL |
|--------|-----|
| Web-Interface | http://192.168.2.127:9090 |
| Mit lokalem DNS | http://prometheus.home:9090 |

---

## Container-Konfiguration

**Datei:** `/etc/pve/lxc/106.conf`

```ini
arch: amd64
cores: 2
features: nesting=1
hostname: prometheus
memory: 2048
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,ip=192.168.2.127/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-106-disk-0,size=15G
swap: 2048
unprivileged: 1
```

---

## Prometheus-Konfiguration

**Datei (im Container):** `/etc/prometheus/prometheus.yml`

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files: []

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node"
    static_configs:
      - targets:
        - "192.168.2.120:9100"  # Proxmox Host
        - "192.168.2.121:9100"  # Samba
        - "192.168.2.122:9100"  # Pi-hole
        # Weitere Nodes hier hinzufügen
```

---

## Service-Konfiguration

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

## Verwaltung

```bash
# Status prüfen
pct exec 106 -- systemctl status prometheus

# Neustarten
pct exec 106 -- systemctl restart prometheus

# Logs anzeigen
pct exec 106 -- journalctl -u prometheus -n 50

# Konfiguration prüfen
pct exec 106 -- promtool check config /etc/prometheus/prometheus.yml

# Targets prüfen (im Web-UI)
# http://prometheus.home:9090/targets
```

---

## Node Exporter hinzufügen

Um einen neuen Host zu überwachen:

```bash
# Auf dem Ziel-Host installieren
apt install prometheus-node-exporter

# Oder manuell
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-*.tar.gz
mv node_exporter-*/node_exporter /usr/local/bin/
```

Dann in `prometheus.yml` hinzufügen und Prometheus neustarten.

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

# ICMP/Ping
IN ACCEPT -p icmp
```

---

## Wichtige Pfade

| Pfad | Beschreibung |
|------|--------------|
| `/etc/prometheus/prometheus.yml` | Hauptkonfiguration |
| `/var/lib/prometheus/` | Time-Series Datenbank |
| `/usr/local/bin/prometheus` | Binary |

---

## Backup

```bash
# Container-Backup
vzdump 106 --storage local --compress zstd --mode snapshot

# Nur Konfiguration
pct exec 106 -- tar -czf /root/prometheus-config.tar.gz /etc/prometheus/
```

---

*CT 106 - Prometheus | Server rxfsys*