# Netzwerk-Diagramm

## Physisch + Logisch (ASCII)

```
                 ┌──────────────────┐
                 │  Internet (WAN)  │
                 └────────┬─────────┘
                          │
                  ┌───────┴───────┐
                  │  Router .1    │
                  │  (UniFi/      │
                  │   Speedport)  │
                  └───────┬───────┘
                          │ 192.168.2.0/24
            ┌─────────────┼─────────────┐
            │             │             │
        Client PCs    rxf-sys (.200)   ggf. weitere
        .30-.119      Proxmox VE 9.2   Geräte
                          │
                       nic0
                          │
                       vmbr0 (Bridge)
                          │
   ┌─────────┬───────────┬─────────┬───────────┬─────────┐
   │         │           │         │           │         │
 CT 100    CT 101      CT 102    CT 103      CT 104    ...
 .201      .202        .203      .204        .205
 nas       admin-      vault-    uptime-     docker-
 (Samba)   dashboard   warden    kuma        host
                                             │
                                             └─ Docker:
                                                  cloudflared ──┐
                                                  immich        │
                                                  portainer     │
                                                                ▼
                                                       Cloudflare Edge
                                                                ▲
                                                                │
                                                       Public Internet
                                                            (12 Hostnames)
```

## Cloudflare Tunnel Routing

```mermaid
flowchart LR
  Internet[Public Internet]
  CFEdge[Cloudflare Edge]
  Tunnel[Cloudflared in CT 104]
  Internet -- TLS --> CFEdge
  CFEdge -- tunnel:443 outbound --> Tunnel
  Tunnel -- "http :80" --> WelcomePage["CT 108 :80\nwww.rxf-sys.de, hooks"]
  Tunnel -- "http :80" --> Portfolio["CT 107 :80\nportfolio"]
  Tunnel -- "http :8081" --> Vault["CT 102\nvault"]
  Tunnel -- "http :8123" --> HA["VM 200\nha"]
  Tunnel -- "http :2283" --> Immich["CT 104 docker\nphotos"]
  Tunnel -- "http :8096" --> Jellyfin["CT 106\nmedia"]
  Tunnel -- "http :3001" --> Kuma["CT 103\nmonitor"]
  Tunnel -- "http :80" --> AdminDash["CT 101\nadmin"]
  Tunnel -- "http :80" --> Orynthia["CT 109\norynthia"]
  Tunnel -- "https :8007" --> PBS["VM 201\npbs"]
  Tunnel -- "https :8006" --> PVE["Host\npve"]
```

## IP-Verteilung

```
192.168.2.0/24
│
├── .1                    Gateway / Router
├── .2-.29                Reserviert (Infrastructure)
├── .30-.119              DHCP (Clients)
├── .120-.199             Reserviert
├── .200                  rxf-sys HOST
├── .201                  CT 100 nas
├── .202                  CT 101 admin-dashboard
├── .203                  CT 102 vaultwarden
├── .204                  CT 103 uptime-kuma
├── .205                  CT 104 docker-host
├── .206                  (frei, war CT 105 nextcloud-aio)
├── .207                  CT 106 jellyfin
├── .208                  VM 200 homeassistant
├── .209                  VM 201 pbs
├── .210                  CT 107 portfolio
├── .211                  CT 108 welcome-page
├── .212                  CT 109 orynthia
└── .213-.254             Reserviert
```
