# Home-Server rxf-sys

> Proxmox VE 9.2 Home-Server mit 11 LXC-Containern und 2 VMs für NAS, Smart Home, Media, Backup, Vault, Portfolio, Remote-Management und Admin-Dashboard. Externer Zugriff über Cloudflare Tunnel.

---

## Schnellübersicht

|              |                                                                |
| ------------ | -------------------------------------------------------------- |
| **Hostname** | rxf-sys                                                        |
| **OS**       | Proxmox VE 9.2.6 (Debian 13 Trixie), proxmox-ve 9.2.0          |
| **Kernel**   | 7.0.14-8-pve (EFI Secure Boot enabled)                         |
| **Hardware** | HP EliteDesk 800 G5 Desktop Mini                               |
| **BIOS**     | R21 Ver. 02.25.00 (09.01.2026)                                 |
| **CPU**      | Intel Core i5-9500T (6 Cores @ 2.20 GHz, Turbo 3.70 GHz)       |
| **RAM**      | 32 GB DDR4                                                     |
| **Storage**  | 500 GB NVMe (System) + 500 GB SSD (Daten) + 480 GB SSD (PBS)   |
| **Netzwerk** | 192.168.2.0/24, Host 192.168.2.200                             |
| **PBS**      | als VM 201 mit sdb Disk-Passthrough (USB-SSD)                  |
| **External** | Cloudflare Tunnel `rxf-sys-home` (12 Public Hostnames)         |

---

## Dokumentationsstruktur

| Verzeichnis            | Inhalt                                                   |
| ---------------------- | -------------------------------------------------------- |
| [01-hardware/](01-hardware/)         | Hardware-Specs, Disks, BIOS                              |
| [02-installation/](02-installation/) | PVE-Installation, Post-Install, PBS-VM-Setup             |
| [03-netzwerk/](03-netzwerk/)         | Bridge, IP-Schema, Firewall, Cloudflare Tunnel           |
| [04-storage/](04-storage/)           | LVM-Thin, /mnt/storage, sdb-Passthrough, Bind-Mounts     |
| [05-container/](05-container/)       | Alle 11 LXCs + 2 VMs, einzeln dokumentiert               |
| [06-backup/](06-backup/)             | PVE vzdump, PBS-Datastore, Host-Config-Backup, Restore   |
| [07-monitoring/](07-monitoring/)     | Uptime-Kuma, Notifications (Strato SMTP), Admin-Dashboard|
| [08-sicherheit/](08-sicherheit/)     | PVE-Firewall, fail2ban, Token-Inventur                   |
| [09-wartung/](09-wartung/)           | Update-Schedules, Checklisten, Audit-Berichte            |
| [10-disaster-recovery/](10-disaster-recovery/) | Recovery-Bericht, Procedures, Notfallpläne     |
| [11-mailserver/](11-mailserver/)     | **Planung** — Migration Strato-Mail → eigener Mailserver |
| [configs/](configs/)                 | Anonymisierte Config-Snippets                            |
| [scripts/](scripts/)                 | Wartungs- und Backup-Skripte                             |
| [diagramme/](diagramme/)             | Netzwerk- und Storage-Diagramme                          |

---

## Topologie

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   HEIMNETZWERK 192.168.2.0/24                           │
│                                                                         │
│   Router (UniFi / Speedport)                                            │
│   Gateway 192.168.2.1                                                   │
│                                                                         │
│   PROXMOX HOST rxf-sys 192.168.2.200  ←  https://192.168.2.200:8006     │
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │ LXC-Container                                                   │   │
│   │  CT 100  nas                 .201  (Samba: 445, 139, 137-138)   │   │
│   │  CT 101  admin-dashboard     .202  (Docker, :80 frontend)       │   │
│   │  CT 102  vaultwarden         .203  (Docker, :8081)              │   │
│   │  CT 103  uptime-kuma         .204  (Docker, :3001)              │   │
│   │  CT 105  magicmirror         .206  (Smart-Mirror-Dashboard)     │   │
│   │  CT 106  jellyfin            .207  (nativ, :8096 + GPU)         │   │
│   │  CT 107  portfolio           .210  (Caddy, :80)                 │   │
│   │  CT 108  welcome-page        .211  (Caddy, :80 + :9000 hooks)   │   │
│   │  CT 109  orynthia            .212  (Docker, :80 + :443 nginx)   │   │
│   │  CT 110  cloudflared         .213  (nativ, nur outbound)        │   │
│   │  CT 111  rmm                 .214  (Docker, :80 + RustDesk)     │   │
│   ├─────────────────────────────────────────────────────────────────┤   │
│   │ VMs                                                             │   │
│   │  VM 200  homeassistant       .208  (HA OS, :8123)               │   │
│   │  VM 201  pbs                 .209  (PBS, :8007, sdb passthrough)│   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│   IP-Bereich Server (statisch): 192.168.2.200-214                       │
│   Cloudflare Tunnel-Verbindung: outbound von CT 110 → cloudflare        │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Container-/VM-Übersicht

| ID  | Typ | Name             | IP    | RAM   | CPU | Disk  | Service                          | Doku |
|-----|-----|------------------|-------|-------|-----|-------|----------------------------------|------|
| 100 | LXC | nas              | .201  | 1 GB  | 1   | 8 GB  | Samba (NAS)                      | [→](05-container/lxc/CT100-nas.md) |
| 101 | LXC | admin-dashboard  | .202  | 2 GB  | 1   | 16 GB | rxf-admin (NestJS+Vite Docker)   | [→](05-container/lxc/CT101-admin-dashboard.md) |
| 102 | LXC | vaultwarden      | .203  | 512 M | 1   | 4 GB  | Vaultwarden (Docker)             | [→](05-container/lxc/CT102-vaultwarden.md) |
| 103 | LXC | uptime-kuma      | .204  | 512 M | 1   | 4 GB  | Uptime Kuma (Docker)             | [→](05-container/lxc/CT103-uptime-kuma.md) |
| 105 | LXC | magicmirror      | .206  | 2 GB  | 2   | 12 GB | MagicMirror-Dashboard            | [→](05-container/lxc/CT105-magicmirror.md) |
| 106 | LXC | jellyfin         | .207  | 2 GB  | 2   | 10 GB | Jellyfin (nativ, GPU)            | [→](05-container/lxc/CT106-jellyfin.md) |
| 107 | LXC | portfolio        | .210  | 512 M | 1   | 8 GB  | Portfolio (Caddy)                | [→](05-container/lxc/CT107-portfolio.md) |
| 108 | LXC | welcome-page     | .211  | 512 M | 1   | 8 GB  | Welcome Page (Caddy) + Hooks     | [→](05-container/lxc/CT108-welcome-page.md) |
| 109 | LXC | orynthia         | .212  | 4 GB  | 1   | 24 GB | Orynthia (Docker: nginx+nest+pg) | [→](05-container/lxc/CT109-orynthia.md) |
| 110 | LXC | cloudflared      | .213  | 512 M | 1   | 8 GB  | Cloudflare Tunnel (nativ)        | [→](05-container/lxc/CT110-cloudflared.md) |
| 111 | LXC | rmm              | .214  | 2 GB  | 2   | 16 GB | RustDesk-RMM (Docker)            | [→](05-container/lxc/CT111-rmm.md) |
| 200 | VM  | homeassistant    | .208  | 6 GB  | 2   | 32 GB | Home Assistant OS                | [→](05-container/vm/VM200-homeassistant.md) |
| 201 | VM  | pbs              | .209  | 6 GB  | 2   | 32 GB | Proxmox Backup Server            | [→](05-container/vm/VM201-pbs.md) |

**Gesamt-Ressourcen:** 28160 MB RAM zugewiesen (88 % von 31871 MB physisch), 18 CPU-Cores,
~182 GB LVM-Thin (18 % des 337 GB Pools) + sdb-Passthrough 468 GB

> **Hinweis zur RAM-Auslastung:** 88 % Zuweisung lässt dem Host wenig Reserve.
> LXCs belegen zwar nur, was sie tatsächlich brauchen, die beiden VMs (je 6 GB)
> reservieren aber fest. Vor weiteren Guests siehe [09-wartung/audit-2026-08-05.md](09-wartung/audit-2026-08-05.md).

---

## Wichtige URLs

### Lokal (LAN)

| Dienst             | URL                            |
|--------------------|--------------------------------|
| **PVE Web-UI**     | https://192.168.2.200:8006     |
| **PBS Web-UI**     | https://192.168.2.209:8007     |
| **Admin-Dashboard**| http://192.168.2.202           |
| **Vaultwarden**    | http://192.168.2.203:8081      |
| **Uptime Kuma**    | http://192.168.2.204:3001      |
| **MagicMirror**    | http://192.168.2.206 (Port unbestätigt) |
| **Jellyfin**       | http://192.168.2.207:8096      |
| **Home Assistant** | http://192.168.2.208:8123      |
| **RMM**            | http://192.168.2.214           |
| **NAS (Samba)**    | `\\nas.home\shared` (CIFS)     |

### Public (Cloudflare Tunnel)

| Hostname                  | → Origin                       | Status |
|---------------------------|--------------------------------|--------|
| admin.rxf-sys.de          | http://192.168.2.202:80        | ok |
| ha.rxf-sys.de             | http://192.168.2.208:8123      | ok |
| media.rxf-sys.de          | http://192.168.2.207:8096      | ok |
| photos.rxf-sys.de         | http://192.168.2.205:2283      | **502 — Origin existiert nicht mehr** |
| monitor.rxf-sys.de        | http://192.168.2.204:3001      | ok |
| vault.rxf-sys.de          | http://192.168.2.203:8081      | ok |
| pbs.rxf-sys.de            | https://192.168.2.209:8007     | ok |
| portfolio.rxf-sys.de      | http://192.168.2.210:80        | ok |
| pve.rxf-sys.de            | https://192.168.2.200:8006     | ok |
| www.rxf-sys.de            | http://192.168.2.211:80        | ok |
| orynthia.rxf-sys.de       | http://192.168.2.212:80        | ok |
| hooks.rxf-sys.de          | http://192.168.2.211:9000      | ok |

---

## Geplant (nicht umgesetzt)

| Vorhaben | Doku | Status |
|----------|------|--------|
| Mailserver CT 112 (.215) + VPS-Relay, Migration von Strato-Mail | [11-mailserver/](11-mailserver/) | Planung, 14.08.2026 |

Kernpunkt: Ein Mailserver **allein** auf rxf-sys funktioniert nicht — der
Cloudflare Tunnel transportiert kein SMTP, und der Privatanschluss hat keinen
setzbaren PTR. Die Zielarchitektur ist deshalb Postfächer zu Hause plus kleiner
VPS als Relay davor. Vorher müssen 2 GB RAM frei werden
([09-wartung/audit-2026-08-05.md](09-wartung/audit-2026-08-05.md), Maßnahme 10).

---

## Schnellbefehle

```bash
# Guest-Status
pct list && qm list

# Storage
pvesm status

# Backups
ls -la /mnt/storage/host-configs/                          # Host-Config-Backups (täglich)
qm guest exec 201 -- proxmox-backup-manager garbage-collection list
qm guest exec 201 -- proxmox-backup-manager prune-job list

# Updates
apt update && apt -y dist-upgrade                           # Host
for id in 100 101 102 103 105 106 107 108 109 110 111; do   # Alle CTs
  pct exec $id -- bash -c 'apt update && apt -y dist-upgrade'
done

# Firewall-Status
pve-firewall status
iptables -L PVEFW-HOST-IN -nv | head

# Health
systemctl --failed
pvesm status
qm guest ping 201 || qm guest exec 201 -- uname -r

# Vollaudit (Ist-Zustand + Best-Practice-Check, read-only)
/usr/local/sbin/doc-audit.sh          # → /root/audit-<datum>.md
```

---

*Letzte Aktualisierung: 5. August 2026 (nach Audit — siehe [09-wartung/audit-2026-08-05.md](09-wartung/audit-2026-08-05.md))*
