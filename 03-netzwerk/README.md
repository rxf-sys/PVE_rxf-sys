# 03 — Netzwerk

## Topologie

```
Internet
    │
[Router]  192.168.2.1   (DHCP für Clients .30-119)
    │
    ├── Switch (UniFi / direkt)
    │
    └── rxf-sys (192.168.2.200) ── vmbr0 ── nic0
                 │
                 └── alle Guests via vmbr0
```

## Bridge

- `vmbr0` (Linux Bridge) auf physischem `nic0`
- IP: 192.168.2.200/24, Gateway 192.168.2.1
- Keine VLANs, kein STP, alles flach in 192.168.2.0/24

Siehe `/etc/network/interfaces`:

```
auto lo
iface lo inet loopback

iface nic0 inet manual

auto vmbr0
iface vmbr0 inet static
        address 192.168.2.200/24
        gateway 192.168.2.1
        bridge-ports nic0
        bridge-stp off
        bridge-fd 0
```

## IP-Schema

| Bereich         | Zweck                                   |
|-----------------|-----------------------------------------|
| 192.168.2.1     | Gateway / Router                        |
| 192.168.2.2-29  | Reserviert (Infrastruktur)              |
| 192.168.2.30-119| DHCP (Clients)                          |
| 192.168.2.120-199 | Reserviert                            |
| **192.168.2.200** | rxf-sys Host                          |
| **192.168.2.201-214** | Guests (siehe Tabelle unten)      |
| 192.168.2.215-254 | Reserviert                            |

### Statische IPs (Guests)

| IP            | Hostname        | VMID | Typ |
|---------------|-----------------|------|-----|
| 192.168.2.201 | nas             | 100  | LXC |
| 192.168.2.202 | admin-dashboard | 101  | LXC |
| 192.168.2.203 | vaultwarden     | 102  | LXC |
| 192.168.2.204 | uptime-kuma     | 103  | LXC |
| 192.168.2.206 | magicmirror     | 105  | LXC |
| 192.168.2.207 | jellyfin        | 106  | LXC |
| 192.168.2.208 | homeassistant   | 200  | VM  |
| 192.168.2.209 | pbs             | 201  | VM  |
| 192.168.2.210 | portfolio       | 107  | LXC |
| 192.168.2.211 | welcome-page    | 108  | LXC |
| 192.168.2.212 | orynthia        | 109  | LXC |
| 192.168.2.213 | cloudflared     | 110  | LXC |
| 192.168.2.214 | rmm             | 111  | LXC |

**192.168.2.205 ist seit der Auflösung von CT 104 (`docker-host`) frei.**
Achtung: `photos.rxf-sys.de` zeigt im Cloudflare Tunnel noch auf diese Adresse.
Vor einer Neuvergabe der .205 den Tunnel-Eintrag entfernen — sonst landen
externe Requests auf einem beliebigen neuen Guest.

## DNS

- Primär: 192.168.2.1 (Router-DNS)
- `/etc/hosts` enthält lokale Aliase:
  - `192.168.2.200 rxf-sys.home rxf-sys`
  - `192.168.2.209 pbs.home pbs`

## Firewall

Siehe [firewall.md](firewall.md).

## Cloudflare Tunnel

Siehe [cloudflare-tunnel.md](cloudflare-tunnel.md).
