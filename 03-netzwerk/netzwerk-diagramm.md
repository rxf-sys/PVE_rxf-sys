# Netzwerk-Diagramm

## Topologie

```
┌──────────────────────────────────────────────────────────────────────┐
│                    HEIMNETZWERK 192.168.2.0/24                       │
│                                                                      │
│   Internet                                                           │
│   ────┬─────                                                         │
│       │                                                              │
│       ▼                                                              │
│   [Speedport Smart 4]                                                │
│   192.168.2.1  │  DHCP: Deaktiviert (Pi-hole uebernimmt)            │
│                │                                                     │
│   ─────────────┴─────────────────────────────────────────────────    │
│                │                                                     │
│                │ (1 Gbit Ethernet)                                   │
│                │                                                     │
│   ┌────────────┴─────────────────────────────────────────────────┐   │
│   │  PROXMOX HOST (rxfsys) - 192.168.2.120                      │   │
│   │  https://192.168.2.120:8006                                  │   │
│   │                                                              │   │
│   │  nic0 ──► vmbr0 (Bridge)                                    │   │
│   │           │                                                  │   │
│   │  ┌────────┴──────────────────────────────────────────────┐   │   │
│   │  │                 LXC CONTAINER                         │   │   │
│   │  ├───────────────────────────────────────────────────────┤   │   │
│   │  │  CT 100 - Samba         192.168.2.121  :445           │   │   │
│   │  │  CT 101 - Pi-hole       192.168.2.122  :53/:80/:67   │   │   │
│   │  │  CT 102 - WireGuard     192.168.2.123  :51820/:51821 │   │   │
│   │  │  CT 103 - Vaultwarden   192.168.2.124  :8081         │   │   │
│   │  │  CT 104 - Nginx-Proxy   192.168.2.125  :80/:443/:81  │   │   │
│   │  │  CT 105 - Jellyfin      192.168.2.126  :8096         │   │   │
│   │  │  CT 106 - Prometheus    192.168.2.127  :9090         │   │   │
│   │  │  CT 107 - Grafana       192.168.2.128  :3000         │   │   │
│   │  │  CT 108 - PBS           192.168.2.129  :8007         │   │   │
│   │  │  CT 109 - Home Assist.  192.168.2.130  :8123         │   │   │
│   │  │  CT 110 - Paperless     192.168.2.131  :8000         │   │   │
│   │  └───────────────────────────────────────────────────────┘   │   │
│   └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│   IP-Bereiche:                                                       │
│   • Server (statisch): 192.168.2.120-131                             │
│   • Clients (DHCP):    192.168.2.30-119 (via Pi-hole)                │
│   • Reserviert:        192.168.2.2-29, 192.168.2.132-254             │
└──────────────────────────────────────────────────────────────────────┘
```

## Dienste-Verbindungen

```
                    EXTERN (Internet)
                         │
              ┌──────────┴──────────┐
              │                     │
         :51820 (UDP)          :443/:80 (TCP)
              │                     │
              ▼                     ▼
        [CT 102]              [CT 104]
        WireGuard             Nginx Proxy
              │                     │
              │              ┌──────┴──────┐
              │              │             │
              │              ▼             ▼
              │         [CT 103]      (weitere
              │         Vaultwarden    Dienste)
              │           :8081
              │
              ▼
        Zugriff auf alle
        LAN-Dienste via VPN


       INTERN (LAN)
    ┌───────────────────────────────────┐
    │                                   │
    │  [CT 101] Pi-hole ◄── alle DNS    │
    │    :53 / :67         Anfragen     │
    │                                   │
    │  [CT 100] Samba ◄── Dateifreigabe │
    │    :445                           │
    │                                   │
    │  [CT 105] Jellyfin ◄── Medien    │
    │    :8096                          │
    │                                   │
    │  [CT 106] Prometheus ──►          │
    │    :9090            [CT 107]      │
    │    (sammelt)        Grafana       │
    │                      :3000        │
    │                    (visualisiert) │
    │                                   │
    │  [CT 108] PBS ◄── Backups aller  │
    │    :8007          Container       │
    │                                   │
    │  [CT 109] Home Assistant          │
    │    :8123                          │
    │                                   │
    │  [CT 110] Paperless               │
    │    :8000                          │
    └───────────────────────────────────┘
```

## Mermaid-Diagramm

Fuer GitHub-Rendering (wird automatisch als Grafik dargestellt):

```mermaid
graph TD
    Internet((Internet)) --> Router[Speedport Smart 4<br/>192.168.2.1]
    Router --> |1Gbit| PVE[Proxmox Host<br/>192.168.2.120]

    PVE --> CT100[CT100 Samba<br/>.121 :445]
    PVE --> CT101[CT101 Pi-hole<br/>.122 :53/:67/:80]
    PVE --> CT102[CT102 WireGuard<br/>.123 :51820]
    PVE --> CT103[CT103 Vaultwarden<br/>.124 :8081]
    PVE --> CT104[CT104 Nginx<br/>.125 :80/:443]
    PVE --> CT105[CT105 Jellyfin<br/>.126 :8096]
    PVE --> CT106[CT106 Prometheus<br/>.127 :9090]
    PVE --> CT107[CT107 Grafana<br/>.128 :3000]
    PVE --> CT108[CT108 PBS<br/>.129 :8007]
    PVE --> CT109[CT109 Home Assistant<br/>.130 :8123]
    PVE --> CT110[CT110 Paperless<br/>.131 :8000]

    Internet -.->|:51820 UDP| CT102
    Internet -.->|:443/:80 TCP| CT104
    CT104 -->|Reverse Proxy| CT103
    CT106 -->|Metriken| CT107

    style Internet fill:#ff6b6b
    style Router fill:#ffd93d
    style PVE fill:#6bcb77
```
