# 05 — Container & VMs

Vollständige Dokumentation aller 9 LXC-Container und 2 VMs.

## Übersicht

| ID  | Typ | Name             | IP    | RAM   | CPU | Disk  | Doku |
|-----|-----|------------------|-------|-------|-----|-------|------|
| 100 | LXC | nas              | .201  | 1 GB  | 1   | 8 GB  | [CT100-nas.md](lxc/CT100-nas.md) |
| 101 | LXC | admin-dashboard  | .202  | 2 GB  | 1   | 16 GB | [CT101-admin-dashboard.md](lxc/CT101-admin-dashboard.md) |
| 102 | LXC | vaultwarden      | .203  | 512 M | 1   | 4 GB  | [CT102-vaultwarden.md](lxc/CT102-vaultwarden.md) |
| 103 | LXC | uptime-kuma      | .204  | 512 M | 1   | 4 GB  | [CT103-uptime-kuma.md](lxc/CT103-uptime-kuma.md) |
| 104 | LXC | docker-host      | .205  | 4 GB  | 2   | 20 GB | [CT104-docker-host.md](lxc/CT104-docker-host.md) |
| 106 | LXC | jellyfin         | .207  | 2 GB  | 2   | 10 GB | [CT106-jellyfin.md](lxc/CT106-jellyfin.md) |
| 107 | LXC | portfolio        | .210  | 512 M | 1   | 8 GB  | [CT107-portfolio.md](lxc/CT107-portfolio.md) |
| 108 | LXC | welcome-page     | .211  | 512 M | 1   | 8 GB  | [CT108-welcome-page.md](lxc/CT108-welcome-page.md) |
| 109 | LXC | orynthia         | .212  | 2 GB  | 1   | 8 GB  | [CT109-orynthia.md](lxc/CT109-orynthia.md) |
| 200 | VM  | homeassistant    | .208  | 10 GB | 2   | 32 GB | [VM200-homeassistant.md](vm/VM200-homeassistant.md) |
| 201 | VM  | pbs              | .209  | 4 GB  | 2   | 32 GB+480 GB | [VM201-pbs.md](vm/VM201-pbs.md) |

## Gemeinsame Eigenschaften LXCs

- OS: Debian 13 (Trixie) — alle
- `unprivileged: 1`
- `features: nesting=1` (alle), `keyctl=1` für Docker-CTs (102, 103, 104)
- `onboot: 1`
- Bridge: `vmbr0`, `firewall=1`
- Tags: `website`, `media`, `backup` für Filter im PVE-UI

## Befehlsreferenz

```bash
pct list                              # Status aller LXCs
pct status <vmid>                     # einzelner Status
pct config <vmid>                     # Konfiguration
pct exec <vmid> -- bash               # Shell im CT
pct enter <vmid>                      # Login-Shell
pct start|stop|reboot <vmid>          # Start/Stop/Reboot (NICHT 'restart' !)
pct shutdown <vmid> --timeout 60      # graceful

qm list                               # Status aller VMs
qm config <vmid>
qm guest exec <vmid> -- <cmd>         # via qemu-guest-agent
qm reboot|shutdown|start|stop <vmid>
```
