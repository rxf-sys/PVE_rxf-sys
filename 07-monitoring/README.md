# 07 — Monitoring

## Komponenten

1. **Uptime Kuma** (CT 103) — externe Health-Checks, https://monitor.rxf-sys.de — siehe [uptime-kuma.md](uptime-kuma.md)
2. **Notifications via Strato SMTP** — alle PVE+PBS-Notifications → info@rxf-sys.de — siehe [notifications.md](notifications.md)
3. **Admin-Dashboard** (CT 101) — selbstgebautes Dashboard für PVE/PBS/UniFi/Cloudflare Status — siehe [admin-dashboard.md](admin-dashboard.md)

## Was wird beobachtet

| Bereich          | Tool                | Cadenz       |
|------------------|---------------------|--------------|
| Backup-Erfolg    | vzdump → PBS-Mail   | tägliche Mail bei Fehler |
| GC/Prune/Verify  | PBS-Notifications   | bei Failure  |
| Service-Ports    | Uptime Kuma         | jede Minute  |
| Public-URLs      | Uptime Kuma         | jede Minute  |
| Host-Metriken    | PVE-UI (RRD)        | live         |
| SMART            | manuell (siehe [../09-wartung/](../09-wartung/)) | monatlich |
| dmesg-Errors     | manuell             | wöchentlich  |
