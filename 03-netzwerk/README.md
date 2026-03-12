# Netzwerk

Netzwerk-Konfiguration des Proxmox Servers und aller Container.

| Dokument | Beschreibung |
|----------|--------------|
| [bridges-vlans.md](bridges-vlans.md) | Bridge-Konfiguration, VLANs |
| [ip-schema.md](ip-schema.md) | IP-Adress-Schema, DHCP, DNS |
| [firewall.md](firewall.md) | Firewall-Regeln, Port-Forwarding |
| [netzwerk-diagramm.md](netzwerk-diagramm.md) | Netzwerk-Topologie (visuell) |

## Kurzuebersicht

| Parameter | Wert |
|-----------|------|
| **Subnetz** | 192.168.2.0/24 |
| **Gateway** | 192.168.2.1 (Speedport Smart 4) |
| **DNS-Server** | 192.168.2.122 (Pi-hole) |
| **DHCP-Server** | 192.168.2.122 (Pi-hole) |
| **Domain** | .home |
| **Bridge** | vmbr0 |
