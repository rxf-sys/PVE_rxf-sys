# Checkliste: Neuen LXC-Container erstellen

## Vor der Erstellung

- [ ] Naechste freie CT-ID bestimmen (aktuell: ab 111)
- [ ] Naechste freie IP-Adresse bestimmen (aktuell: ab 192.168.2.132)
- [ ] RAM- und CPU-Bedarf abschaetzen
- [ ] Disk-Groesse festlegen
- [ ] CT-Template herunterladen (falls noetig)

## Container erstellen

```bash
# Template herunterladen (Beispiel: Debian 12)
pveam update
pveam download local debian-12-standard_12.x-1_amd64.tar.zst

# Container erstellen
pct create <ID> local:vztmpl/debian-12-standard_12.x-1_amd64.tar.zst \
  --hostname <NAME> \
  --cores <N> \
  --memory <MB> \
  --swap <MB> \
  --rootfs local-lvm:<SIZE_GB> \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.2.<IP>/24,gw=192.168.2.1 \
  --features nesting=1 \
  --unprivileged 1 \
  --onboot 1
```

## Nach der Erstellung

- [ ] Container starten: `pct start <ID>`
- [ ] System aktualisieren: `pct exec <ID> -- apt update && pct exec <ID> -- apt upgrade -y`
- [ ] Dienst installieren und konfigurieren
- [ ] Firewall-Regeln setzen (falls noetig)
- [ ] DNS-Eintrag in Pi-hole hinzufuegen
- [ ] Bind-Mounts konfigurieren (falls noetig)
- [ ] Autostart pruefen: `pct config <ID> | grep onboot`

## Dokumentation

- [ ] Container-Dokumentation erstellen: `05-container/lxc/CT<ID>-<name>.md`
- [ ] README.md in `05-container/` aktualisieren
- [ ] Haupt-README.md aktualisieren
- [ ] IP-Schema in `03-netzwerk/ip-schema.md` aktualisieren

## Backup

- [ ] Container in Backup-Job aufnehmen
- [ ] Ersten Backup manuell erstellen: `vzdump <ID> --storage local --compress zstd`

## Template fuer Container-Dokumentation

```markdown
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
| **Funktion** | <Beschreibung> |

## Installation

<Installations-Schritte>

## Konfiguration

<Konfigurations-Details>

## Wartung

<Wartungs-Hinweise>

## Troubleshooting

<Haeufige Probleme und Loesungen>
```
