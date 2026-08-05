# CT 110 — cloudflared

Dedizierter Container für den Cloudflare Tunnel. Übernahm im Sommer 2026 die
Tunnel-Rolle vom aufgelösten CT 104 (`docker-host`).

## Spec

| Spec       | Wert                            |
|------------|---------------------------------|
| Hostname   | cloudflared                     |
| IP         | 192.168.2.213/24                |
| RAM        | 512 MB                          |
| CPU        | 1 Core                          |
| rootfs     | local-lvm:vm-110-disk-0, 8 GB   |
| OS         | Debian 13 (Trixie)              |
| Features   | nesting=1                       |
| unprivileged | 1                             |
| onboot     | 1                               |
| Tags       | (keine)                         |

## Service

`cloudflared` läuft **nativ als systemd-Service**, nicht in Docker — anders als
in CT 104, wo es ein Docker-Container war. Im CT ist keine Docker-Engine
installiert.

| Listener            | Zweck                                    |
|---------------------|------------------------------------------|
| 127.0.0.1:20241     | cloudflared Metrics/Management (lokal)   |
| 127.0.0.1:20242     | cloudflared Metrics/Management (lokal)   |
| UDP, wechselnde Ports | QUIC-Verbindungen zur Cloudflare-Edge  |

Es gibt **keinen eingehenden Listener** — der Tunnel baut ausschließlich
ausgehende Verbindungen auf. Deshalb ist auch keine Portfreigabe nötig.

```bash
pct exec 110 -- systemctl status cloudflared
pct exec 110 -- journalctl -u cloudflared --since '1 hour ago' --no-pager
```

## Tunnel

Tunnel-Name `rxf-sys-home`, 12 Public Hostnames.
Details, Origins und Token-Rotation: [../../03-netzwerk/cloudflare-tunnel.md](../../03-netzwerk/cloudflare-tunnel.md).

## Firewall

**Offen:** Für CT 110 existiert kein Regelsatz unter `/etc/pve/firewall/110.fw`.
An der NIC steht `firewall=1`, ohne Regeldatei greift aber nur die
Cluster-Policy. Da der Container keine eingehenden Dienste anbietet, ist das
risikoarm, sollte aber der Konsistenz halber nachgezogen werden — siehe
[../../09-wartung/audit-2026-08-05.md](../../09-wartung/audit-2026-08-05.md).

## Warum ein eigener Container

Der Tunnel ist der einzige Weg von außen ins Netz. In CT 104 hing er zusammen
mit Immich, Portainer und deren Datenbanken in einem Container — jeder Neustart
dieses Stacks nahm den externen Zugriff auf alle 12 Hostnames mit. Als eigener,
minimaler Container ist der Tunnel von den Anwendungen entkoppelt.

## Backup

- vzdump täglich 02:00 → pbs
- Der Tunnel-Token liegt in der cloudflared-Konfiguration im CT-rootfs und ist
  damit Teil des vzdump-Backups.
