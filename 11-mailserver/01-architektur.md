# 01 — Architektur & Varianten

---

## Die vier Wege

| | Variante A **VPS-Relay + Postfächer zu Hause** | Variante B **alles auf dem VPS** | Variante C **Strato bleibt Postbote** | Variante D **Port-Forwarding zu Hause** |
|---|---|---|---|---|
| Daten liegen | auf rxf-sys | auf dem VPS | auf rxf-sys | auf rxf-sys |
| Eingang | VPS → WireGuard → CT 112 | VPS | Abholung per IMAP von Strato | direkt aus dem Internet |
| Ausgang | CT 112 → VPS → Internet | VPS → Internet | CT 112 → Strato-SMTP | direkt |
| Kosten/Monat | ~4–6 € VPS | ~4–6 € VPS | Strato-Tarif (~1–3 €) | 0 € |
| DNS-Änderung | ja (MX, SPF, DKIM, DMARC) | ja | **nein** | ja |
| Zustellrate | gut (eigene IP + PTR) | gut | sehr gut (Stratos Reputation) | **schlecht bis unbrauchbar** |
| Aufwand | hoch | mittel | niedrig | mittel |
| „eigener Mailserver"? | ja | nur formal — läuft nicht auf rxf-sys | halb — Postfächer ja, Transport nein | ja, aber kaputt |
| Single Point of Failure | VPS (Eingang), Zuhause (Postfächer) | VPS | Strato | Anschluss |

### Empfehlung: **Variante A**

Weil sie das eigentliche Ziel erfüllt — die Postfächer und damit deine Daten
liegen auf rxf-sys und werden über die bestehende PBS-Kette gesichert — und
gleichzeitig die drei Blocker aus
[00-machbarkeit.md](00-machbarkeit.md#1-warum-direktbetrieb-zu-hause-ausfällt)
umgeht. Der VPS speichert nichts: er nimmt Mail an, schiebt sie durch den
Tunnel und vergisst sie. Fällt er aus, wiederholen sendende Server bis zu fünf
Tage — Mail geht nicht verloren.

### Variante B — alles auf dem VPS

Deutlich einfacher und robuster. Aber: dann läuft dein Mailserver nicht auf dem
Proxmox-Server, sondern bei einem Hoster, und die Mails liegen dort. Das ist
gegenüber Strato kein Kontrollgewinn, nur ein Anbieterwechsel mit mehr Arbeit.
Sinnvoll, wenn dir Zustellsicherheit über alles geht.

### Variante C — Postfächer zu Hause, Strato bleibt Postbote

Der ehrliche Einstieg, wenn Variante A zu viel ist:

- MX bleibt unverändert bei Strato/Cloudflare. **Keine DNS-Änderung, kein
  Reputationsrisiko, kein VPS.**
- CT 112 holt Mail per `getmail6` oder `fetchmail` über IMAP von Strato ab und
  legt sie in lokale Dovecot-Postfächer.
- Versand aus CT 112 über `smtp.strato.de:465` als Smarthost — genau der
  Zugang, der laut
  [../07-monitoring/notifications.md](../07-monitoring/notifications.md)
  schon existiert.
- Ergebnis: eigenes IMAP zu Hause, eigene Suche, eigene Archivierung, eigenes
  Backup über PBS. Strato macht nur noch Transport.

Nachteil: Du bist weiter von Strato abhängig und zahlst dort weiter. Aber du
kannst später von C nach A wechseln, ohne die Postfächer erneut zu migrieren —
CT 112 steht dann schon, es kommen nur VPS und DNS dazu. **Wenn du unsicher
bist, ist C → A der risikoärmste Pfad.**

### Variante D — Port-Forwarding zu Hause

Der Vollständigkeit halber: 25/465/587/993 am Router weiterleiten, DynDNS
dazu. Empfang würde teilweise funktionieren, **Versand nicht** (PBL + kein
PTR). Ergebnis ist ein Mailserver, der Mail annimmt, aber keine verschickt,
und der zusätzlich Port 25 aus dem ganzen Internet an dein Heimnetz öffnet —
gegen die dokumentierte Grundsatzentscheidung „kein Port-Forwarding, nur
Tunnel" in
[../08-sicherheit/firewall.md](../08-sicherheit/firewall.md#vom-wan). **Nicht
empfohlen.**

### Und ein VPS als VM auf rxf-sys?

Nein. Der Wert des VPS liegt nicht darin, **was** er ist, sondern **wo** er
steht: statische IP, setzbarer PTR, nicht in der Spamhaus PBL, Port 25 offen.
Das sind alles Eigenschaften des Anschlusses, nicht der Maschine. Eine VM auf
rxf-sys erbt die Heim-IP und damit exakt dieselben drei Blocker.

Du mietest keinen Rechner, du mietest eine IP-Adresse.

Weitere Wege ohne eigenen VPS — IMAP-Pull, HTTPS-Push durch den bestehenden
Cloudflare Tunnel, Inbound-Relay-Dienste, Geschäftsanschluss — stehen mit
Kosten- und Aufwandsvergleich in
[08-alternativen-ohne-vps.md](08-alternativen-ohne-vps.md).

---

## Zielarchitektur Variante A

```
                     ┌──────────────────────────────────────┐
   Internet ────────►│ VPS  mail.rxf-sys.de                 │
   (fremde MTAs      │ statische IPv4/IPv6, PTR gesetzt     │
    Port 25)         │                                      │
                     │  Postfix (reines Relay, kein Storage)│
                     │  ├─ inbound : für rxf-sys.de → WG    │
                     │  └─ outbound: von 10.9.0.0/24 → Welt │
                     │  nginx stream 993/465 → WG (optional)│
                     │  fail2ban, certbot (HTTP-01)         │
                     └──────────────┬───────────────────────┘
                                    │ WireGuard 10.9.0.0/24
                                    │ (nur ausgehend von CT 112
                                    │  aufgebaut, PersistentKeepalive)
   ─────────────────────────────────┼──────────────────────────────────
   HEIMNETZ 192.168.2.0/24          │
                                    ▼
   ┌───────────────────────────────────────────────────────────┐
   │ rxf-sys 192.168.2.200                                     │
   │                                                            │
   │  CT 112  mailserver  192.168.2.215   (10.9.0.2 im WG)     │
   │  ├─ Postfix   25 (nur von 10.9.0.1), 465/587 (LAN+WG)     │
   │  ├─ Dovecot   993 IMAPS, 4190 ManageSieve (LAN+WG)        │
   │  ├─ Rspamd    Filterung + DKIM-Signatur                   │
   │  └─ Maildir   auf rootfs local-lvm → vzdump → PBS         │
   │                                                            │
   │  CT 110  cloudflared  ── Tunnel ──► Webmail / autoconfig / │
   │                                     mta-sts (nur HTTP)     │
   │  VM 201  pbs          ── vzdump 02:00 ──► Datastore        │
   └───────────────────────────────────────────────────────────┘

   Mail-Clients im LAN     → direkt 192.168.2.215:993 / :465
   Mail-Clients von außen  → mail.rxf-sys.de:993 / :465 (via VPS-Passthrough)
                             oder WireGuard aufs Handy
```

Vollständiger Flow inkl. Filter-Reihenfolge:
[../diagramme/mail-flow.md](../diagramme/mail-flow.md)

### Warum der Tunnel von innen aufgebaut wird

CT 112 initiiert die WireGuard-Verbindung zum VPS, nicht umgekehrt. Damit
braucht der Router weiterhin **kein** Port-Forwarding, und die dokumentierte
Sicherheitslinie bleibt intakt: von außen ist nichts direkt erreichbar, alles
läuft über ausgehende Verbindungen — genau wie beim Cloudflare Tunnel in
CT 110.

---

## Wahl des Mailstacks

| Stack | RAM | Betriebsmodell | Webmail | Kalender | Urteil |
|-------|-----|----------------|---------|----------|--------|
| **docker-mailserver** | ~0,8–1,2 GB ohne ClamAV | ein `compose.yaml` + `setup`-CLI | nein (Roundcube separat) | nein | **Empfohlen.** Passt zum etablierten Docker-in-LXC-Muster (CT 101/102/103/109), gut dokumentiert, DKIM-Keygen eingebaut. |
| Stalwart | ~0,3–0,6 GB | eine Binary, JMAP + IMAP + SMTP | mitgeliefert (einfach) | teilweise | Sparsamste Option, moderner Stack. Weniger Erfahrungsberichte, Config-Schema ändert sich zwischen Versionen — dann strikt der offiziellen Doku folgen. |
| Mailcow | **min. 6 GB**, realistisch 8 | Docker-Compose-Verbund, offiziell **nicht** in LXC unterstützt → als VM | SOGo + Roundcube | ja (CalDAV/CardDAV/ActiveSync) | Nur wenn Groupware wirklich gebraucht wird. Braucht dann eine VM und eine größere RAM-Aufräumaktion. |
| Postfix + Dovecot + Rspamd manuell | ~0,6 GB | alles selbst | nein | nein | Maximale Kontrolle, maximaler Lernaufwand, maximale Fehlerquellen bei der Erstkonfiguration. |

**Entscheidung: docker-mailserver in CT 112.** Bei Bedarf Roundcube als
zweiter Container daneben und über den bestehenden Cloudflare Tunnel als
`webmail.rxf-sys.de` veröffentlichen — das ist reines HTTP und damit
tunnelfähig.

> **ClamAV bleibt aus** (`ENABLE_CLAMAV=0`). ClamAV allein braucht 1–2 GB RAM
> für die Signaturdatenbank und würde das Budget sprengen. Rspamd erledigt die
> Spamfilterung; für Malware ist der Virenschutz auf dem Endgerät die
> wirksamere Stelle.

---

## Ressourcenbudget

Ist-Zustand laut [../README.md](../README.md): **28160 MB von 31871 MB
zugewiesen (88 %)**, also 3711 MB frei. Maßnahme 10 im
[Audit vom 05.08.2026](../09-wartung/audit-2026-08-05.md) mahnt das schon an.

Mit CT 112 (2 GB) käme man auf 30208 MB = **95 %**. Zu wenig für den Host:
ARC/Pagecache, vzdump-Puffer und die PVE-Dienste brauchen echte Reserve.

### Vorher 2 GB freiräumen

LXCs belegen nur, was sie brauchen — die beiden **VMs reservieren fest**. Dort
liegt der Hebel:

```bash
# Tatsächliche Nutzung in den VMs prüfen, nicht raten
qm guest exec 200 -- free -m       # Home Assistant
qm guest exec 201 -- free -m       # PBS

# Bei reichlich Luft: auf 4 GB reduzieren (Shutdown nötig)
qm shutdown 200 --timeout 120 && qm set 200 --memory 4096 && qm start 200
qm shutdown 201 --timeout 120 && qm set 201 --memory 4096 && qm start 201
```

Einordnung:

- **VM 201 (PBS)** läuft mit 4 GB für einen Datastore dieser Größe komfortabel;
  PBS gibt 2 GB als Minimum an. Reduzierung unkritisch. **Achtung:** Danach
  einen vollständigen vzdump-Lauf und einen Verify beobachten, bevor du es als
  erledigt betrachtest — und `startup: order=1` nicht verlieren.
- **VM 200 (Home Assistant)** kommt mit 4 GB aus, solange keine schweren
  Add-ons (Frigate, große Recorder-DB) laufen. Vorher `free -m` prüfen.

Eine der beiden Reduzierungen reicht: 26112 + 2048 = 28160 MB → wieder 88 %,
also der heutige Stand mit Mailserver obendrauf.

Alternativ 1 GB für CT 112 ansetzen. Das läuft mit docker-mailserver ohne
ClamAV, wird aber bei größeren Rspamd-Läufen und paralleler IMAP-Nutzung eng.
**2 GB ist die belastbare Zahl.**

### Disk

| Posten | Größe |
|--------|-------|
| CT 112 rootfs auf `local-lvm` | 32 GB (thin-provisioned, belegt real nur das Genutzte) |
| Thin-Pool `pve-data` | 337 GB, aktuell ~18 % belegt → passt problemlos |

---

## Kosten

| Posten | Monat | Jahr |
|--------|-------|------|
| VPS (1 vCPU, 2 GB, statische IPv4+IPv6) | 4–6 € | 48–72 € |
| Strato Mail (Übergang, 2–4 Wochen Parallelbetrieb) | 1–3 € | — |
| Strato Mail (dauerhaft für Infra-Alerts, siehe [06-betrieb.md](06-betrieb.md)) | 1–3 € | 12–36 € |
| Domain `rxf-sys.de` (läuft weiter, unabhängig) | — | unverändert |
| **Summe dauerhaft** | **5–9 €** | **60–108 €** |

Dagegen Strato-Mail allein: 12–36 €/Jahr. **Selbst hosten kostet also mehr
Geld und deutlich mehr Zeit.** Der Gegenwert ist Kontrolle über die Daten,
unbegrenzte Aliase und Postfächer, und ein sehr lehrreiches Projekt. Wer nur
sparen will, sollte bei Strato bleiben.

### VPS-Auswahl — worauf es ankommt

| Kriterium | Warum |
|-----------|-------|
| **Port 25 ausgehend freigeschaltet** | Bei Hetzner, DigitalOcean, Oracle und anderen ist 25 für neue Accounts **gesperrt** und muss per Ticket freigeschaltet werden. Das kann Tage dauern und wird auch abgelehnt. **Vor** allem anderen klären. |
| **rDNS/PTR selbst setzbar** | Ohne das ist der VPS für Mail wertlos. Hetzner, netcup, IONOS und Contabo erlauben es im Kundenportal. |
| **IP nicht vorbelastet** | Nach dem Bestellen sofort gegen Spamhaus/Barracuda/SORBS prüfen (siehe [06-betrieb.md](06-betrieb.md#blocklist-checks)). Bei Listung: IP tauschen oder VPS neu bestellen, **bevor** du DNS umstellst. |
| Standort EU | DSGVO, Latenz |
| IPv6 | Wenn vorhanden, muss auch der IPv6-PTR gesetzt und die IPv6 im SPF stehen — sonst besser IPv6-Versand abschalten, siehe [03-vps-relay.md](03-vps-relay.md#ipv6). |

Konkret bewährt: Hetzner Cloud CX22 (Falkenstein/Nürnberg, ~4,15 €/Monat,
rDNS im Portal, Port 25 auf Ticket) oder netcup VPS 1000 (Port 25 meist offen).
