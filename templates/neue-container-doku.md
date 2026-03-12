# CT <ID> - <Name>

## Uebersicht

| Parameter | Wert |
|-----------|------|
| **CT-ID** | <ID> |
| **Hostname** | <name> |
| **IP** | 192.168.2.<IP> |
| **OS** | Debian 12 |
| **RAM** | <X> GB |
| **CPU** | <N> Cores |
| **Disk** | <X> GB |
| **Port(s)** | <PORT> |
| **Funktion** | <Beschreibung> |
| **Unprivileged** | Ja |
| **Nesting** | Ja |
| **Autostart** | Ja |

## Container-Konfiguration

```ini
# /etc/pve/lxc/<ID>.conf
arch: amd64
cores: <N>
features: nesting=1
hostname: <name>
memory: <MB>
net0: name=eth0,bridge=vmbr0,ip=192.168.2.<IP>/24,gw=192.168.2.1,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-<ID>-disk-0,size=<X>G
swap: <MB>
unprivileged: 1
```

## Installation

```bash
# Container erstellen
pct create <ID> local:vztmpl/debian-12-standard_12.x-1_amd64.tar.zst \
  --hostname <name> \
  --cores <N> \
  --memory <MB> \
  --rootfs local-lvm:<X> \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.2.<IP>/24,gw=192.168.2.1 \
  --features nesting=1 \
  --unprivileged 1 \
  --onboot 1

pct start <ID>
pct exec <ID> -- apt update && pct exec <ID> -- apt upgrade -y
```

### Dienst installieren

```bash
# <Installations-Schritte hier>
```

## Konfiguration

<!-- Wichtige Konfigurationsdetails hier -->

## Wartung

```bash
# Status pruefen
pct exec <ID> -- systemctl status <DIENST>

# Logs pruefen
pct exec <ID> -- journalctl -u <DIENST> --since today

# Neustart
pct exec <ID> -- systemctl restart <DIENST>
```

## Backup

```bash
# Manuelles Backup
vzdump <ID> --storage local --compress zstd --mode snapshot
```

## Troubleshooting

| Problem | Loesung |
|---------|---------|
| Dienst startet nicht | `systemctl status <DIENST>` pruefen |
| Kein Netzwerk | `ip addr` und Gateway pruefen |
| Container startet nicht | `lxc-start -n <ID> -F -l DEBUG` |
