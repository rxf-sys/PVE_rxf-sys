# Firewall

Siehe primär [../03-netzwerk/firewall.md](../03-netzwerk/firewall.md).

## Zusätzlich: Pro-Guest-Firewalls

Stand 05.08.2026. Alle Guests haben `firewall=1` an der NIC — das allein
filtert aber nichts. Wirksam wird die Guest-Firewall erst mit einer Datei
`/etc/pve/firewall/<vmid>.fw`, die `enable: 1` setzt.

| VMID | Datei | Wirksam | Notiz                                                  |
|------|-------|---------|--------------------------------------------------------|
| 100  | 100.fw | ja     | Samba (445/139/137-138 UDP) + ICMP                     |
| 102  | 102.fw | ja     | Vaultwarden :8081 von LAN + .202 + .122                |
| 103  | 103.fw | ja     | Kuma :3001 von LAN                                     |
| 106  | 106.fw | ja     | Jellyfin :8096 + DLNA UDP (1900, 7359)                 |
| 201  | 201.fw | ja     | PBS :8007 + SSH :22 + ICMP nur aus +dc/lan             |
| 111  | 111.fw | **nein** | Datei existiert, aber **ohne `[OPTIONS]`-Block** — kein `enable: 1`, kein `policy_in: DROP`. Regelsatz wirkungslos. |
| 101, 105, 107, 108, 109, 110, 200 | — | **nein** | keine Datei vorhanden |

`104.fw` ist mit der Auflösung von CT 104 entfallen.

### Warum das zählt

Die alte Fassung dieser Doku begründete die fehlenden Regelsätze mit „LAN-only
Zugriff bzw. nur via Tunnel exponiert". Das trägt nur zum Teil:

- **CT 111 (rmm)** öffnet Port 80 und die RustDesk-Portgruppe 21115–21119
  (TCP + UDP). Das ist der Guest mit der größten offenen Angriffsfläche und
  ausgerechnet der ohne wirksamen Regelsatz.
- **CT 109 (orynthia)** exponiert 80, 443 und 3000 mit Postgres und Redis
  dahinter.
- Für die restlichen ist das Risiko gering, aber die Inkonsistenz macht die
  Doku unbrauchbar als Referenz — man kann aus `firewall=1` nicht ableiten,
  ob tatsächlich gefiltert wird.

### Regelsatz nachziehen

Vorlage, die dem Muster der bestehenden Dateien folgt:

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 22 -log nolog
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 80 -log nolog
IN ACCEPT -p icmp
```

Vor dem Aktivieren die tatsächlich benötigten Ports je Guest prüfen
(`pct exec <id> -- ss -tulpn`), sonst sperrt man laufende Dienste aus. Guest-
Firewalls lassen sich gefahrlos testen: `pve-firewall status` zeigt den
Compile-Fehler, und ein `enable: 0` macht die Änderung sofort rückgängig.

## IPSets

| IPSet              | Range                    | Verwendung                         |
|--------------------|--------------------------|------------------------------------|
| `+dc/lan`          | 192.168.2.0/24           | Erlaubte Source für Host/PBS-FW    |
| `PVEFW-0-management-v4` | (auto, Cluster-Nodes) | PVE-internes Management            |

## Schnelle Tests

```bash
pve-firewall status                        # enabled/running
iptables -L PVEFW-HOST-IN -nv | head -15
ipset list PVEFW-0-lan-v4
```

## Vom WAN

Direkter Zugriff aus dem Internet auf 8006/22/8007 etc.: **nicht möglich** (kein Port-Forwarding am Router). Externer Zugriff ausschließlich über Cloudflare Tunnel.
