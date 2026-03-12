# IP-Adress-Schema

## Uebersicht

| Bereich | IPs | Verwendung |
|---------|-----|------------|
| .1 | 192.168.2.1 | Router/Gateway (Speedport Smart 4) |
| .2-.29 | 192.168.2.2-29 | Reserviert (statische Geraete) |
| .30-.119 | 192.168.2.30-119 | DHCP-Bereich (Pi-hole) |
| .120-.131 | 192.168.2.120-131 | Server-Infrastruktur (statisch) |
| .132-.254 | 192.168.2.132-254 | Reserviert / Frei |

## Statische IP-Zuweisungen

| IP | Hostname | MAC-Adresse | Dienst |
|----|----------|-------------|--------|
| 192.168.2.120 | rxfsys (Host) | - | Proxmox |
| 192.168.2.121 | samba | BC:24:11:90:E2:A7 | Samba NAS |
| 192.168.2.122 | pi-hole | BC:24:11:44:B6:42 | DNS/DHCP |
| 192.168.2.123 | wireguard | BC:24:11:7B:30:3F | VPN |
| 192.168.2.124 | vaultwarden | BC:24:11:C6:9B:7C | Passwort-Manager |
| 192.168.2.125 | nginx-proxy | BC:24:11:F6:DB:42 | Reverse Proxy |
| 192.168.2.126 | jellyfin | - | Media Server |
| 192.168.2.127 | prometheus | - | Metriken |
| 192.168.2.128 | grafana | - | Dashboards |
| 192.168.2.129 | pbs | - | Backup Server |
| 192.168.2.130 | homeassistant | - | Smart Home |
| 192.168.2.131 | paperless | - | Dokumentenverwaltung |

## DHCP-Konfiguration (Pi-hole)

| Parameter | Wert |
|-----------|------|
| DHCP-Server | 192.168.2.122 (Pi-hole) |
| Bereich Start | 192.168.2.30 |
| Bereich Ende | 192.168.2.119 |
| Gateway | 192.168.2.1 |
| DNS-Server | 192.168.2.122 |
| Lease-Zeit | 24 Stunden |
| Domain | .home |

> **Hinweis:** Der DHCP-Server im Router (Speedport Smart 4) ist deaktiviert. Pi-hole uebernimmt die DHCP-Funktion.

## Lokale DNS-Eintraege

In Pi-hole unter `/etc/pihole/custom.list`:

```
192.168.2.120 proxmox.home server.home
192.168.2.121 samba.home nas.home
192.168.2.122 pihole.home dns.home
192.168.2.123 vpn.home wireguard.home
192.168.2.124 vault.home vaultwarden.home
192.168.2.125 proxy.home nginx.home
192.168.2.126 jellyfin.home
192.168.2.127 prometheus.home
192.168.2.128 grafana.home
192.168.2.129 pbs.home
192.168.2.130 homeassistant.home
192.168.2.131 paperless.home
```

## DuckDNS (Extern)

| Domain | Verwendung |
|--------|------------|
| rxfsys.duckdns.org | WireGuard VPN |
| vault-rxfsys.duckdns.org | Vaultwarden |

```bash
# Cronjob fuer IP-Update (alle 5 Minuten)
*/5 * * * * curl -s "https://www.duckdns.org/update?domains=rxfsys,vault-rxfsys&token=DEIN_TOKEN&ip=" > /dev/null
```
