# 05 — Container & VMs

Vollständige Dokumentation aller 11 LXC-Container und 2 VMs.

## Übersicht

| ID  | Typ | Name             | IP    | RAM   | CPU | Disk  | Doku |
|-----|-----|------------------|-------|-------|-----|-------|------|
| 100 | LXC | nas              | .201  | 1 GB  | 1   | 8 GB  | [CT100-nas.md](lxc/CT100-nas.md) |
| 101 | LXC | admin-dashboard  | .202  | 2 GB  | 1   | 16 GB | [CT101-admin-dashboard.md](lxc/CT101-admin-dashboard.md) |
| 102 | LXC | vaultwarden      | .203  | 512 M | 1   | 4 GB  | [CT102-vaultwarden.md](lxc/CT102-vaultwarden.md) |
| 103 | LXC | uptime-kuma      | .204  | 512 M | 1   | 4 GB  | [CT103-uptime-kuma.md](lxc/CT103-uptime-kuma.md) |
| 105 | LXC | magicmirror      | .206  | 2 GB  | 2   | 12 GB | [CT105-magicmirror.md](lxc/CT105-magicmirror.md) |
| 106 | LXC | jellyfin         | .207  | 2 GB  | 2   | 10 GB | [CT106-jellyfin.md](lxc/CT106-jellyfin.md) |
| 107 | LXC | portfolio        | .210  | 512 M | 1   | 8 GB  | [CT107-portfolio.md](lxc/CT107-portfolio.md) |
| 108 | LXC | welcome-page     | .211  | 512 M | 1   | 8 GB  | [CT108-welcome-page.md](lxc/CT108-welcome-page.md) |
| 109 | LXC | orynthia         | .212  | 4 GB  | 1   | 24 GB | [CT109-orynthia.md](lxc/CT109-orynthia.md) |
| 110 | LXC | cloudflared      | .213  | 512 M | 1   | 8 GB  | [CT110-cloudflared.md](lxc/CT110-cloudflared.md) |
| 111 | LXC | rmm              | .214  | 2 GB  | 2   | 16 GB | [CT111-rmm.md](lxc/CT111-rmm.md) |
| 200 | VM  | homeassistant    | .208  | 6 GB  | 2   | 32 GB | [VM200-homeassistant.md](vm/VM200-homeassistant.md) |
| 201 | VM  | pbs              | .209  | 6 GB  | 2   | 32 GB+468 GB | [VM201-pbs.md](vm/VM201-pbs.md) |

**Summe:** 28160 MB RAM zugewiesen, 18 Cores, ~182 GB LVM-Thin.

## Gemeinsame Eigenschaften LXCs

- OS: Debian 13 (Trixie) — alle
- `unprivileged: 1` — alle
- `features: nesting=1` — alle; zusätzlich `keyctl=1` bei 101, 102, 103, 109
- `onboot: 1` — alle
- Bridge: `vmbr0`, `firewall=1` an der NIC — alle
- Tags: `website`, `media`, `backup`, `monitoring`, `vault` für Filter im PVE-UI

### Firewall-Regelsätze — unvollständig

`firewall=1` an der NIC allein filtert nichts. Es braucht zusätzlich eine
Regeldatei `/etc/pve/firewall/<vmid>.fw` mit `enable: 1`.

| Guest | Regelsatz | Status |
|-------|-----------|--------|
| 100, 102, 103, 106, 201 | vorhanden | `enable: 1`, `policy_in: DROP` |
| 111 | vorhanden | **ohne `[OPTIONS]`** — wirkungslos |
| 101, 105, 107, 108, 109, 110, 200 | **fehlt** | nur Cluster-Policy |

Siehe [../09-wartung/audit-2026-08-05.md](../09-wartung/audit-2026-08-05.md).

## Änderungshistorie der Guest-Landschaft

| Datum   | Änderung |
|---------|----------|
| 08/2026 | **CT 104 `docker-host` aufgelöst.** Cloudflared nach CT 110 (nativ) verschoben; Immich und Portainer ersatzlos entfernt. `photos.rxf-sys.de` zeigt weiterhin auf die tote Origin 192.168.2.205:2283 und liefert 502. |
| 08/2026 | CT 105 `magicmirror`, CT 110 `cloudflared`, CT 111 `rmm` neu |
| 08/2026 | CT 109 `orynthia` von 2 GB/8 GB auf 4 GB/24 GB vergrößert |
| 08/2026 | VM 200 und VM 201 auf je 6 GB RAM erhöht |

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
