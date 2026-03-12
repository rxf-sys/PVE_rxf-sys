# Prometheus und Grafana

## Prometheus (CT 106)

### Scrape-Targets

Prometheus sammelt Metriken von verschiedenen Quellen:

| Target | URL | Intervall | Beschreibung |
|--------|-----|-----------|--------------|
| Proxmox Host | http://192.168.2.120:9100 | 15s | Node Exporter |
| Pi-hole | http://192.168.2.122:9617 | 30s | Pi-hole Exporter |
| Prometheus self | http://localhost:9090 | 15s | Eigene Metriken |

<!-- Weitere Targets hier eintragen -->

### prometheus.yml (Beispiel)

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'proxmox-host'
    static_configs:
      - targets: ['192.168.2.120:9100']

  # Weitere Targets hier hinzufuegen
```

### Node Exporter auf Host installieren

```bash
# Auf dem Proxmox Host
apt install prometheus-node-exporter

# Pruefen
systemctl status prometheus-node-exporter
curl http://localhost:9100/metrics | head
```

### Verwaltung

```bash
# Prometheus Status
pct exec 106 -- systemctl status prometheus

# Konfiguration neu laden
pct exec 106 -- systemctl reload prometheus

# Targets pruefen
# Web-UI: http://prometheus.home:9090/targets
```

## Grafana (CT 107)

### Datenquellen

| Name | Typ | URL |
|------|-----|-----|
| Prometheus | prometheus | http://192.168.2.127:9090 |

### Empfohlene Dashboards

| Dashboard | ID | Beschreibung |
|-----------|----|--------------|
| Node Exporter Full | 1860 | Host-Metriken |
| Proxmox Summary | - | Proxmox Uebersicht |
| Docker Monitoring | 893 | Docker-Container |
| Pi-hole | 10176 | DNS-Statistiken |

### Dashboard importieren

1. Grafana Web-UI oeffnen: http://grafana.home:3000
2. Dashboards -> Import
3. Dashboard-ID eingeben oder JSON hochladen
4. Datenquelle "Prometheus" auswaehlen
5. Import

### Verwaltung

```bash
# Grafana Status
pct exec 107 -- systemctl status grafana-server

# Grafana neu starten
pct exec 107 -- systemctl restart grafana-server

# Grafana Passwort zuruecksetzen
pct exec 107 -- grafana-cli admin reset-admin-password <NEUES_PASSWORT>
```
