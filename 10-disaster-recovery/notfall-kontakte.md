# Notfall-Kontakte und Zugaenge

## Zugangsdaten-Speicherort

> Alle Passwoerter und Zugangsdaten sind in **Vaultwarden** gespeichert.
> Falls Vaultwarden nicht erreichbar: Recovery-Export auf separatem Medium aufbewahren!

## Wichtige Zugaenge

| Dienst | Zugang | Notizen |
|--------|--------|---------|
| Proxmox Host (SSH) | root@192.168.2.120 | SSH-Key oder Passwort |
| Proxmox Web-UI | https://192.168.2.120:8006 | root@pam |
| Router | http://192.168.2.1 | Speedport Admin |
| DuckDNS | https://www.duckdns.org | Account + Token |
| Vaultwarden | https://vault-rxfsys.duckdns.org | Master-Passwort |

## Physischer Zugang

Falls kein Netzwerkzugang moeglich:
1. Monitor und Tastatur an Server anschliessen
2. Direkt einloggen (root + Passwort)
3. Netzwerk pruefen und reparieren

## Vaultwarden Recovery

Falls Vaultwarden nicht verfuegbar:
1. Bitwarden Desktop/Mobile App hat Offline-Cache
2. Emergency Sheet (ausgedruckt aufbewahren!)
3. Backup der Vaultwarden-DB wiederherstellen (siehe [../06-backup/restore-anleitung.md](../06-backup/restore-anleitung.md))
