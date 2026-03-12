# LVM-Thin Pool

## Uebersicht

Der LVM-Thin Pool `pve/data` stellt den Storage fuer alle Container-Rootfs bereit.

| Parameter | Wert |
|-----------|------|
| Volume Group | pve |
| Thin Pool | data |
| Groesse | 337 GB |
| Belegung | ~14% |

## Container-Volumes

| LV | Groesse | Belegung | Container |
|----|---------|----------|-----------|
| vm-100-disk-0 | 15 GB | 9% | Samba |
| vm-101-disk-0 | 8 GB | 16% | Pi-hole |
| vm-102-disk-0 | 8 GB | 25% | WireGuard |
| vm-103-disk-0 | 8 GB | 23% | Vaultwarden |
| vm-104-disk-0 | 8 GB | 38% | Nginx PM |
| vm-105-disk-0 | 32 GB | 66% | Jellyfin |
| vm-106-disk-0 | 15 GB | 12% | Prometheus |
| vm-107-disk-0 | 8 GB | 29% | Grafana |
| vm-108-disk-0 | 20 GB | 11% | PBS |
| vm-109-disk-0 | 10 GB | 47% | Home Assistant |
| vm-110-disk-0 | 10 GB | 41% | Paperless |
| **Gesamt** | **132 GB** | | |

## Verwaltung

```bash
# Thin Pool Status
lvs -a pve/data

# Alle Volumes anzeigen
lvs

# Volume vergroessern (Beispiel: CT 105 auf 40GB)
pct resize 105 rootfs 40G

# Thin Pool erweitern
lvextend -L +50G pve/data

# Pruefbefehle
pvs    # Physical Volumes
vgs    # Volume Groups
lvs    # Logical Volumes
```

## Wichtig

- Thin Provisioning: Die tatsaechlich belegte Groesse ist kleiner als die zugewiesene
- Bei >80% Belegung des Thin Pools: Vergroessern oder aufraumen
- Snapshots belegen zusaetzlichen Platz im Thin Pool
