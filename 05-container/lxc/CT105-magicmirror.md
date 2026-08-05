# CT 105 — magicmirror

Smart-Mirror-/Dashboard-Container. Die VMID 105 und die IP .206 waren seit dem
Destroy des alten CT 105 frei und wurden hier wiederverwendet.

## Spec

| Spec       | Wert                            |
|------------|---------------------------------|
| Hostname   | magicmirror                     |
| IP         | 192.168.2.206/24                |
| RAM        | 2048 MB                         |
| CPU        | 2 Cores                         |
| rootfs     | local-lvm:vm-105-disk-0, 12 GB (25 % belegt) |
| OS         | Debian 13 (Trixie)              |
| Features   | nesting=1                       |
| unprivileged | 1                             |
| onboot     | 1                               |
| Tags       | (keine)                         |

## Services

> **Noch nicht erfasst.** Das Audit vom 05.08.2026 hat für diesen Container nur
> die PVE-Konfiguration abgedeckt; die Innensicht (laufende Dienste, Ports,
> Docker-Container) fehlt. Vor dem nächsten Audit hier nachtragen:
>
> ```bash
> pct exec 105 -- bash -lc 'grep PRETTY_NAME /etc/os-release; ss -tulpnH | sort -u'
> pct exec 105 -- bash -lc 'command -v docker >/dev/null && docker ps || echo "kein Docker"'
> pct exec 105 -- systemctl list-units --type=service --state=running --no-legend
> ```
>
> Ergänzt werden sollten: Port des Web-Frontends, Installationspfad,
> Update-Verfahren und ob MagicMirror nativ oder in Docker läuft.

`nesting=1` ist gesetzt, was auf einen Docker- oder Podman-Betrieb hindeutet —
bestätigt ist das aber nicht.

## Firewall

**Offen:** Für CT 105 existiert kein Regelsatz unter `/etc/pve/firewall/105.fw`.
An der NIC steht `firewall=1`, ohne Regeldatei greift aber nur die
Cluster-Policy. Siehe
[../../09-wartung/audit-2026-08-05.md](../../09-wartung/audit-2026-08-05.md).

## URLs

- LAN: `http://192.168.2.206` — **Port unbestätigt** (MagicMirror² nutzt per
  Default 8080; im Audit nicht erfasst)
- Public: keiner. Der Container hat keinen Eintrag im Cloudflare Tunnel.

## Backup

- vzdump täglich 02:00 → pbs, 13 Snapshots vorhanden, letztes Backup aktuell
