# CT 111 — rmm (RustDesk Remote Management)

Remote-Management-Stack auf Basis von RustDesk, mit eigenem Web-Frontend und
Backend.

## Spec

| Spec       | Wert                            |
|------------|---------------------------------|
| Hostname   | rmm                             |
| IP         | 192.168.2.214/24                |
| RAM        | 2048 MB                         |
| CPU        | 2 Cores                         |
| rootfs     | local-lvm:vm-111-disk-0, 16 GB  |
| OS         | Debian 13 (Trixie)              |
| Features   | nesting=1                       |
| unprivileged | 1                             |
| onboot     | 1                               |
| Tags       | (keine)                         |

## Services (Docker)

| Container        | Image                             | Ports                    | Zweck                        |
|------------------|-----------------------------------|--------------------------|------------------------------|
| rxf-rmm-web      | `rxf-sys/rmm-web:latest`          | 80 (extern), 443, 2019   | Web-UI (Caddy-basiert)       |
| rxf-rmm-backend  | `rxf-sys/rmm-backend:latest`      | 8080 (nur intern)        | API, Healthcheck aktiv       |
| rxf-rmm-hbbs     | `rustdesk/rustdesk-server:latest` | 21115-21118 TCP, 21116 UDP | RustDesk ID/Rendezvous-Server |
| rxf-rmm-hbbr     | `rustdesk/rustdesk-server:latest` | 21117, 21119 TCP         | RustDesk Relay-Server        |

`rmm-web` und `rmm-backend` sind selbstgebaute Images (kein Registry-Pull), sie
werden also lokal im CT gebaut.

## Ports

| Port        | Protokoll | Dienst                        |
|-------------|-----------|-------------------------------|
| 80          | TCP       | Web-UI                        |
| 21115       | TCP       | RustDesk NAT-Type-Test        |
| 21116       | TCP + UDP | RustDesk ID-Registrierung / Heartbeat |
| 21117       | TCP       | RustDesk Relay                |
| 21118       | TCP       | RustDesk Web-Client (hbbs)    |
| 21119       | TCP       | RustDesk Web-Client (hbbr)    |
| 22          | TCP       | SSH                           |

## Firewall — offener Punkt

`/etc/pve/firewall/111.fw` existiert, hat aber **keinen `[OPTIONS]`-Block**:

```
[RULES]

IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 22 -log nolog
```

Ohne `enable: 1` ist der Regelsatz wirkungslos, und ohne `policy_in: DROP` gibt
es keine Default-Ablehnung. Der Container ist damit im LAN ungefiltert
erreichbar — inklusive Port 80 und der kompletten RustDesk-Portgruppe.

Alle anderen dokumentierten Guest-Regelsätze (100, 102, 103, 106, 201) folgen
diesem Muster:

```
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 22 -log nolog
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 80 -log nolog
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 21115:21119 -log nolog
IN ACCEPT -source 192.168.2.0/24 -p udp -dport 21116 -log nolog
IN ACCEPT -p icmp
```

Beachten: RustDesk-Clients außerhalb des LAN erreichen den Server nur, wenn die
Ports entsprechend zugänglich sind. Wenn Fernzugriff von außen gewünscht ist,
gehört das über den Cloudflare Tunnel oder eine bewusste Portfreigabe geregelt —
nicht über eine fehlende Firewall-Konfiguration.

Siehe [../../09-wartung/audit-2026-08-05.md](../../09-wartung/audit-2026-08-05.md).

## Wartung

```bash
pct exec 111 -- docker ps
pct exec 111 -- docker logs rxf-rmm-backend --tail 30
pct exec 111 -- docker logs rxf-rmm-hbbs --tail 30
```

## Backup

- vzdump täglich 02:00 → pbs
- RustDesk-Schlüssel und -Datenbank liegen in Docker-Volumes im CT-rootfs und
  sind damit Teil des vzdump-Backups. **Der RustDesk-Server-Key ist beim
  Neuaufsetzen entscheidend** — ohne ihn müssen alle Clients neu verbunden werden.
