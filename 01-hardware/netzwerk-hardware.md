# Netzwerk-Hardware

## Netzwerk-Interface

| Interface | Typ | Geschwindigkeit | Verwendung |
|-----------|-----|-----------------|------------|
| nic0 | Onboard Ethernet | 1 Gbit/s | Bridge vmbr0 |

## Netzwerk-Geraete

| Geraet | Modell | IP | Funktion |
|--------|--------|-----|----------|
| Router | Speedport Smart 4 | 192.168.2.1 | Internet-Gateway |

<!-- Weitere Switches, APs etc. hier eintragen -->

## Verkabelung

```
Internet
  │
  ▼
[Speedport Smart 4] ── 192.168.2.1
  │
  │ (Ethernet, 1Gbit)
  │
  ▼
[rxfsys Server] ── 192.168.2.120
  │
  └── nic0 → vmbr0 (Bridge)
       ├── CT 100 (Samba)      .121
       ├── CT 101 (Pi-hole)    .122
       ├── CT 102 (WireGuard)  .123
       ├── CT 103 (Vaultwarden).124
       ├── CT 104 (Nginx)      .125
       ├── CT 105 (Jellyfin)   .126
       ├── CT 106 (Prometheus) .127
       ├── CT 107 (Grafana)    .128
       ├── CT 108 (PBS)        .129
       ├── CT 109 (HA)         .130
       └── CT 110 (Paperless)  .131
```

## Pruefbefehle

```bash
# Interfaces anzeigen
ip link show
ip addr show

# Bridge-Status
brctl show

# Geschwindigkeit pruefen
ethtool nic0
```
