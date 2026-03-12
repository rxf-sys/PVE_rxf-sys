# Server-Spezifikationen

## System

| Komponente | Spezifikation |
|------------|---------------|
| **Hostname** | rxfsys |
| **Formfaktor** | Mini-PC / Desktop |
| **CPU** | Intel Core i5-9500T @ 2.20GHz (6 Cores, 6 Threads) |
| **RAM** | 32 GB DDR4 |
| **Boot-Mode** | EFI (Secure Boot aktiv) |
| **OS** | Proxmox VE 9.1.4 |
| **Kernel** | Linux 6.17.2-1-pve |

## CPU-Details

```
Modell:          Intel Core i5-9500T
Architektur:     x86_64 (Coffee Lake)
Kerne:           6
Threads:         6
Basistakt:       2.20 GHz
Turbo:           3.70 GHz
TDP:             35W
Virtualisierung: VT-x, VT-d
```

## RAM

| Slot | Groesse | Typ | Takt |
|------|---------|-----|------|
| DIMM 1 | 16 GB | DDR4 | <!-- Takt eintragen --> |
| DIMM 2 | 16 GB | DDR4 | <!-- Takt eintragen --> |
| **Gesamt** | **32 GB** | | |

## Ressourcen-Verteilung

```
Proxmox Host:             ~8 GB (Reserve)
Container gesamt:         ~24 GB zugewiesen
  CT 100 (Samba):          1 GB
  CT 101 (Pi-hole):        2 GB
  CT 102 (WireGuard):      1 GB
  CT 103 (Vaultwarden):    2 GB
  CT 104 (Nginx):          1 GB
  CT 105 (Jellyfin):       8 GB
  CT 106 (Prometheus):     2 GB
  CT 107 (Grafana):        1 GB
  CT 108 (PBS):            2 GB
  CT 109 (Home Assistant): 2 GB
  CT 110 (Paperless):      2 GB
```

## Pruefbefehle

```bash
# CPU-Info
lscpu

# RAM-Info
free -h
dmidecode -t memory

# Mainboard
dmidecode -t baseboard

# PCI-Geraete
lspci
```
