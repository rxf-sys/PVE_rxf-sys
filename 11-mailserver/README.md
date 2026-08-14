# 11 — Mailserver (Migration Strato → eigener Server)

> **Status: Planungsdokument.** Nichts davon ist auf rxf-sys umgesetzt.
> Es gibt (Stand 14.08.2026) keinen CT 112, keinen VPS und keine geänderten
> DNS-Records. Dieses Verzeichnis beschreibt den Weg dorthin, nicht den
> Ist-Zustand. Der restliche Doku-Baum dokumentiert ausschließlich Ist-Zustand —
> bitte diese Trennung beim Umsetzen mitpflegen.

---

## Das Wichtigste zuerst

Ein vollständiger Mailserver **allein** auf rxf-sys funktioniert nicht. Nicht
„schwierig", sondern technisch verbaut, aus drei Gründen:

| Blocker | Konsequenz |
|---------|------------|
| Kein Port-Forwarding am Router, externer Zugriff nur via Cloudflare Tunnel | Cloudflare Tunnel proxyt **nur HTTP/HTTPS/WebSocket**. SMTP (25), Submission (465/587) und IMAPS (993) lassen sich damit nicht veröffentlichen. Fremde Mailserver können deinen MX also nicht erreichen. |
| Privatkunden-Anschluss ohne rDNS-Kontrolle | Kein PTR-Record auf `mail.rxf-sys.de` setzbar. Gmail, Outlook, GMX und Web.de weisen Mail von Hosts ohne passenden PTR ab oder sortieren sie in Spam. |
| IP steht in der Spamhaus PBL | Dynamische Endkunden-Ranges sind dort **per Definition** gelistet. Direktversand ins Internet scheitert damit unabhängig von allem anderen. Zusätzlich blockieren viele ISPs Port 25 ausgehend. |

Deshalb ist die Zielarchitektur nicht „Mailserver zu Hause", sondern
**Mailserver zu Hause + kleiner VPS als Relay davor**. Die Postfächer, die
Daten und die Verwaltung liegen bei dir auf rxf-sys — der VPS ist ein dummer
Briefkasten mit sauberer IP, der nichts speichert.

Details und die Alternativen (inkl. der Varianten ohne VPS) in
[01-architektur.md](01-architektur.md).

---

## Ehrliche Erwartungshaltung

Bevor du Zeit investierst — drei Punkte, die man vorher wissen sollte:

1. **Es wird nicht billiger.** VPS ca. 4–6 €/Monat gegen Strato Mail für
   ca. 1–3 €/Monat. Der Gewinn ist Kontrolle und Lernen, nicht Geld.
   Kostenrechnung: [01-architektur.md](01-architektur.md#kosten).
2. **Mail ist der unversöhnlichste Dienst im Selbstbau.** Bei Jellyfin merkt
   niemand einen Ausfall. Bei Mail bekommst du still keine Rechnungen,
   Passwort-Resets oder Behördenpost mehr. Der Parallelbetrieb mit Strato über
   2–4 Wochen in [05-migration.md](05-migration.md) ist kein Luxus.
3. **RAM reicht aktuell nicht.** 28160 von 31871 MB sind zugewiesen (88 %).
   Vor CT 112 müssen 2 GB frei werden — siehe
   [01-architektur.md](01-architektur.md#ressourcenbudget).

Wenn dir das zu viel ist: Variante C in
[01-architektur.md](01-architektur.md#variante-c--postfächer-zu-hause-strato-bleibt-postbote)
gibt dir eigene Postfächer auf rxf-sys **ohne** VPS, ohne DNS-Änderung und
ohne Risiko. Strato bleibt dabei der Postbote. Das ist der ehrliche Einstieg —
konkret ausgeführt als Variante P in
[08-alternativen-ohne-vps.md](08-alternativen-ohne-vps.md#3-variante-p--pull-postfächer-zu-hause-provider-als-briefkasten),
zusammen mit allen weiteren Wegen ohne eigenen VPS.

---

## Reihenfolge

Nicht überspringen — jeder Schritt setzt den vorigen voraus.

| # | Schritt | Doku | Aufwand |
|---|---------|------|---------|
| 0 | Ist-Zustand erheben: Wo liegt die Zone? Wer hält den MX? Wie groß sind die Postfächer? | [00-machbarkeit.md](00-machbarkeit.md) | 30 min |
| 1 | Architektur + Variante festlegen, RAM freiräumen | [01-architektur.md](01-architektur.md) | 1 h |
| 2 | VPS bestellen, Port 25 freischalten lassen, PTR setzen, WireGuard aufbauen | [03-vps-relay.md](03-vps-relay.md) | 2–3 h |
| 3 | CT 112 anlegen, Mailstack installieren, Zertifikate via DNS-01 | [02-ct112-mailserver.md](02-ct112-mailserver.md) | 3–4 h |
| 4 | Postfix-Relay auf dem VPS, Ende-zu-Ende-Test **ohne** DNS-Umstellung | [03-vps-relay.md](03-vps-relay.md#8-ende-zu-ende-test-vor-der-dns-umstellung) | 1–2 h |
| 5 | DNS: DKIM/SPF/DMARC vorbereiten, Cloudflare Email Routing abschalten, MX umlegen | [04-dns.md](04-dns.md) | 1 h + Wartezeit |
| 6 | imapsync Strato → eigener Server, Cutover, Parallelbetrieb | [05-migration.md](05-migration.md) | 2–4 Wochen |
| 7 | Backup, Monitoring, Reputation, Wartung dauerhaft einrichten | [06-betrieb.md](06-betrieb.md) | 2 h |
| — | Rollback-Plan (vorher lesen, nicht erst im Ernstfall) | [07-rollback.md](07-rollback.md) | 15 min |
| — | **Alternativen ohne eigenen VPS** — inkl. „kann der VPS nicht auf rxf-sys laufen?" | [08-alternativen-ohne-vps.md](08-alternativen-ohne-vps.md) | 20 min |

Realistisch: **ein Wochenende Aufbau, danach 2–4 Wochen Parallelbetrieb**, erst
dann Strato kündigen.

---

## Geplante Eckdaten

| | |
|---|---|
| **Guest** | CT 112 `mailserver`, unprivileged LXC, Debian 13 |
| **IP intern** | 192.168.2.215/24 (erweitert den Guest-Bereich auf .200–.215) |
| **RAM / CPU / Disk** | 2 GB / 2 Cores / 32 GB auf `local-lvm` |
| **Warum rootfs statt Bind-Mount** | `local-lvm` läuft über vzdump → PBS. `/mnt/storage` ist **nicht** in der Backup-Kette (siehe [../04-storage/README.md](../04-storage/README.md)). Mail gehört nicht auf ungesicherten Storage. |
| **Mailstack** | docker-mailserver (Postfix + Dovecot + Rspamd), ClamAV **aus** |
| **VPS** | 1 vCPU / 2 GB, statische IPv4 + IPv6, PTR = `mail.rxf-sys.de` |
| **Tunnel** | WireGuard, `10.9.0.1` (VPS) ↔ `10.9.0.2` (CT 112) |
| **Öffentlicher Name** | `mail.rxf-sys.de` → VPS-IP, **DNS only / grauer Wolke** |
| **DKIM-Selector** | `mail` (RSA 2048) |
| **Zertifikate** | Let's Encrypt via **DNS-01** (Cloudflare-Token) — HTTP-01 geht zu Hause nicht, Port 80 ist nicht erreichbar |

Mailflow-Diagramm: [../diagramme/mail-flow.md](../diagramme/mail-flow.md)

---

## Was bewusst **nicht** umgestellt wird

**PVE- und PBS-Notifications bleiben auf einem externen SMTP** (heute Strato,
siehe [../07-monitoring/notifications.md](../07-monitoring/notifications.md)).

Grund: Wenn die Backup- und Störungsmeldungen über den eigenen Mailserver
laufen, bekommst du bei einem Ausfall des Mailservers keine Meldung über den
Ausfall des Mailservers. Genau dieser Fall ist im Juli 2026 schon einmal
teuer geworden — fünf Nächte Backup-Ausfall, siehe
[../09-wartung/audit-2026-08-05.md](../09-wartung/audit-2026-08-05.md#3-backup-ausfall-12–16-juli-2026).

Konkret heißt das: Bei Strato entweder den kleinsten Mail-Tarif behalten oder
vor der Kündigung einen Ersatz-Relay für Infra-Alerts einrichten. Details in
[06-betrieb.md](06-betrieb.md#infra-alerts-nicht-über-den-eigenen-mailserver).

---

## Offene Entscheidungen für dich

Diese Punkte kann die Anleitung nicht für dich beantworten — sie stehen in
[00-machbarkeit.md](00-machbarkeit.md) mit den Befehlen zum Klären:

1. Liegt die Zone `rxf-sys.de` auf Cloudflare-Nameservern oder bei Strato?
   ([../07-monitoring/notifications.md](../07-monitoring/notifications.md)
   behauptet „DNS-Setup bei Strato", der Tunnel legt Records aber in
   Cloudflare an — eines von beiden ist veraltet.)
2. Welche Adressen existieren bei Strato wirklich, und wie viel Datenvolumen
   ist das?
3. Soll `info@rxf-sys.de` weiter nach Gmail weitergeleitet werden, oder wird
   das eigene Postfach der Zielort? (Cloudflare Email Routing muss so oder so
   weg, es belegt den MX.)
4. Brauchst du Webmail und Kalender/Kontakte (CalDAV/CardDAV)? Falls ja, ist
   Mailcow statt docker-mailserver die passendere Wahl — braucht aber 6 GB RAM
   und damit eine größere Aufräumaktion.
