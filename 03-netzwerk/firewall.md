# PVE-Firewall

## Ebenen

1. **Datacenter (cluster.fw)** — globale Konfiguration, IPSets, generelle Policy
2. **Node (host.fw)** — Host-Firewall mit eingehenden Regeln
3. **Guest (`<vmid>.fw`)** — pro CT/VM, greift nur wenn `net0 firewall=1`

## Cluster (cluster.fw)

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[IPSET lan]
192.168.2.0/24

[RULES]
```

Wichtig: `IPSET` (nicht `ALIAS`!) — Aliases können nicht als `-source +ipset` verwendet werden, IPSets schon.

## Host (host.fw)

Pfad: `/etc/pve/nodes/rxf-sys/host.fw`

```ini
[OPTIONS]
enable: 1

[RULES]
IN ACCEPT -source +dc/lan -p tcp -dport 8006 -log nolog    # PVE-UI
IN ACCEPT -source +dc/lan -p tcp -dport 22 -log nolog      # SSH
IN ACCEPT -source +dc/lan -p icmp -log nolog               # Ping
```

Plus automatische PVE-Internal-Regeln (PVEFW-0-management-v4 IPSet enthält Cluster-Nodes).

## Pro-Guest-Firewalls

| VMID | Datei  | Policy_in | Erlaubte Ports                                           |
|------|--------|-----------|----------------------------------------------------------|
| 100  | 100.fw | DROP      | 445 + 139 + 137-138 (Samba) + icmp                       |
| 102  | 102.fw | DROP      | 8081 (Vaultwarden) + icmp                                |
| 103  | 103.fw | DROP      | 3001 (Kuma) + icmp                                       |
| 104  | 104.fw | DROP      | 9000, 9443 (Portainer), 2283 (Immich), 8000, alles von .202 + icmp |
| 106  | 106.fw | DROP      | 8096 (Jellyfin) + 1900, 7359 (DLNA UDP) + icmp           |
| 201  | 201.fw | DROP      | 8007 (PBS-UI) + 22 + icmp aus +dc/lan                    |

CTs ohne `.fw` (101, 107, 108, 109, VM 200): keine guest-firewall aktiv → unrestricted (LAN-trust).

## iptables-Snapshot

```bash
iptables -L INPUT -nv | head
iptables -L PVEFW-HOST-IN -nv | head -20
ipset list PVEFW-0-lan-v4
ipset list PVEFW-0-management-v4
```

## Verifikation

```bash
pve-firewall status               # enabled/running
pve-firewall compile              # zeigt komplette generierte iptables-Regeln

# Test PVE-UI vom LAN
curl -k -sS -o /dev/null -w 'HTTP %{http_code}\n' https://192.168.2.200:8006/
```

## Lockout-Recovery

Wenn man sich aussperrt:

```bash
# Konsole am Host:
pve-firewall stop          # alle Regeln raus
# oder: in /etc/pve/firewall/cluster.fw → enable: 0
pve-firewall restart
```

Die fail2ban-Regeln greifen unabhängig in eigene Chains (`f2b-sshd`).
