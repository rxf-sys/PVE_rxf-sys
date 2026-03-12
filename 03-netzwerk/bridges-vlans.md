# Bridges und VLANs

## Bridge-Konfiguration

### vmbr0 (Standard-Bridge)

Alle Container sind an `vmbr0` angeschlossen. Die Bridge verbindet das physische Interface `nic0` mit den virtuellen Interfaces der Container.

**Datei:** `/etc/network/interfaces`

```
auto lo
iface lo inet loopback

iface nic0 inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.2.120/24
    gateway 192.168.2.1
    bridge-ports nic0
    bridge-stp off
    bridge-fd 0

source /etc/network/interfaces.d/*
```

### Parameter

| Parameter | Wert | Beschreibung |
|-----------|------|--------------|
| bridge-ports | nic0 | Physisches Interface |
| bridge-stp | off | Spanning Tree deaktiviert (einzelner Host) |
| bridge-fd | 0 | Forward Delay 0 (schnelles Forwarding) |

## VLANs

Aktuell werden **keine VLANs** verwendet. Alle Container befinden sich im gleichen Subnetz 192.168.2.0/24.

### Moegliche VLAN-Erweiterung

Falls zukuenftig VLANs gewuenscht sind:

| VLAN | Subnetz | Verwendung |
|------|---------|------------|
| VLAN 10 | 192.168.10.0/24 | Management |
| VLAN 20 | 192.168.20.0/24 | Server/Container |
| VLAN 30 | 192.168.30.0/24 | IoT / Smart Home |
| VLAN 40 | 192.168.40.0/24 | Gaeste |

## Pruefbefehle

```bash
# Bridge-Status
brctl show

# Interface-Konfiguration
cat /etc/network/interfaces

# Aktive Verbindungen
ip addr show vmbr0

# Netzwerk neu laden (Vorsicht!)
ifreload -a
```
