# Firewall

Siehe primär [../03-netzwerk/firewall.md](../03-netzwerk/firewall.md).

## Zusätzlich: Pro-Guest-Firewalls

| VMID | Datei | Notiz                                                         |
|------|-------|---------------------------------------------------------------|
| 100  | 100.fw | Samba (445/139/137-138 UDP) + ICMP                           |
| 102  | 102.fw | Vaultwarden :8081 von LAN + .202 + .122                      |
| 103  | 103.fw | Kuma :3001 von LAN                                           |
| 104  | 104.fw | Portainer (9000/9443), Immich (2283), .202 voll erreichbar   |
| 106  | 106.fw | Jellyfin :8096 + DLNA UDP (1900, 7359)                       |
| 201  | 201.fw | PBS :8007 + SSH :22 + ICMP nur aus +dc/lan                   |

CTs 101, 107, 108, 109 und VM 200: keine guest.fw → unrestricted, da LAN-only Zugriff bzw. nur via Tunnel exponiert.

## IPSets

| IPSet              | Range                    | Verwendung                         |
|--------------------|--------------------------|------------------------------------|
| `+dc/lan`          | 192.168.2.0/24           | Erlaubte Source für Host/PBS-FW    |
| `PVEFW-0-management-v4` | (auto, Cluster-Nodes) | PVE-internes Management            |

## Schnelle Tests

```bash
pve-firewall status                        # enabled/running
iptables -L PVEFW-HOST-IN -nv | head -15
ipset list PVEFW-0-lan-v4
```

## Vom WAN

Direkter Zugriff aus dem Internet auf 8006/22/8007 etc.: **nicht möglich** (kein Port-Forwarding am Router). Externer Zugriff ausschließlich über Cloudflare Tunnel.
