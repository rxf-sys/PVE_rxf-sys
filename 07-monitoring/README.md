# Monitoring

Ueberwachung des Proxmox Servers und aller Dienste.

| Dokument | Beschreibung |
|----------|--------------|
| [prometheus-grafana.md](prometheus-grafana.md) | Prometheus + Grafana Setup |
| [alerts.md](alerts.md) | Benachrichtigungen und Alerting |

## Monitoring-Stack

```
┌─────────────┐     ┌──────────────┐     ┌───────────┐
│  Proxmox    │     │  Container   │     │  Dienste  │
│  Host       │────►│  Metriken    │────►│  Status   │
└──────┬──────┘     └──────┬───────┘     └─────┬─────┘
       │                   │                   │
       └───────────────────┴───────────────────┘
                           │
                    ┌──────▼──────┐
                    │ CT 106      │
                    │ Prometheus  │
                    │ :9090       │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │ CT 107      │
                    │ Grafana     │
                    │ :3000       │
                    └─────────────┘
```

## Dienste

| Dienst | CT | IP | Port | URL |
|--------|-----|-----|------|-----|
| Prometheus | 106 | 192.168.2.127 | 9090 | http://prometheus.home:9090 |
| Grafana | 107 | 192.168.2.128 | 3000 | http://grafana.home:3000 |
