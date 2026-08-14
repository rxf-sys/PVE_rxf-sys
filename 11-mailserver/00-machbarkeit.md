# 00 — Machbarkeit & Ist-Zustand erheben

Vor jedem Handgriff: klären, was tatsächlich da ist. Die vorhandene Doku
widerspricht sich an einer Stelle (siehe unten), und die Postfachgrößen
bestimmen das Disk-Sizing.

---

## 1. Warum Direktbetrieb zu Hause ausfällt

Die drei Blocker im Detail, damit die Architekturentscheidung nachvollziehbar
bleibt.

### 1.1 Cloudflare Tunnel kann kein SMTP

Der Tunnel (CT 110, siehe
[../03-netzwerk/cloudflare-tunnel.md](../03-netzwerk/cloudflare-tunnel.md))
veröffentlicht ausschließlich HTTP/HTTPS/WebSocket-Origins. Für beliebige
TCP-Verbindungen gibt es `cloudflared access tcp`, das setzt aber einen
cloudflared-Client auf **jedem** verbindenden Rechner voraus. Fremde
Mailserver, die dir Mail zustellen wollen, haben den nicht. Ein MX-Record kann
nicht auf einen Cloudflare-Tunnel zeigen.

Damit ist der Tunnel für Mail-Transport aus dem Spiel — er bleibt nützlich für
Webmail, Autoconfig und MTA-STS (alles HTTP), siehe [04-dns.md](04-dns.md).

### 1.2 Kein PTR, keine Zustellung

Empfänger prüfen, ob die verbindende IP einen PTR-Record hat, der vorwärts
wieder auf dieselbe IP auflöst (Forward-confirmed reverse DNS). An einem
Privatanschluss gehört der PTR dem Provider, meist in der Form
`p5dcb1234.dip0.t-ipconnect.de`. Setzen kannst du ihn nicht.

Gmail und Outlook behandeln fehlendes oder nicht passendes FCrDNS als starkes
Spam-Signal, viele kleinere Server weisen direkt ab.

### 1.3 Spamhaus PBL

Die Policy Block List listet Endkunden-Ranges vorsätzlich — sie sagt nicht „hier
war Spam", sondern „von hier sollte kein Mailserver direkt senden". Prüfen:

```bash
# Eigene öffentliche IP
curl -4 -s https://ifconfig.co

# PBL-Abfrage (IP-Oktette umgedreht + .zen.spamhaus.org)
# Beispiel für 203.0.113.45 → 45.113.0.203
dig +short 45.113.0.203.zen.spamhaus.org
# Antwort 127.0.0.10 oder 127.0.0.11 = PBL-Listung
```

> **Achtung:** Spamhaus liefert über öffentliche Resolver (8.8.8.8, 1.1.1.1)
> keine verlässlichen Antworten mehr, weil die Query-Volumen dort gesperrt
> sind. Für den Test einen eigenen Resolver nutzen, z. B. den des Routers.

### 1.4 Port 25 ausgehend

```bash
# Geht Port 25 raus? (Timeout = geblockt)
timeout 5 nc -zv gmail-smtp-in.l.google.com 25 && echo "25 offen" || echo "25 blockiert/timeout"
```

Selbst wenn der offen ist, ändern 1.2 und 1.3 nichts. Der Test dient nur der
Vollständigkeit.

---

## 2. Wo liegt die DNS-Zone?

Das ist die **wichtigste offene Frage**, weil alle DNS-Schritte davon abhängen.
Die Doku ist widersprüchlich:
[../07-monitoring/notifications.md](../07-monitoring/notifications.md) sagt
„DNS-Setup bei Strato", während der Cloudflare Tunnel 12 Public Hostnames unter
`rxf-sys.de` verwaltet — was Cloudflare-Nameserver voraussetzt.

```bash
# Autoritative Nameserver
dig +short NS rxf-sys.de

# Aktueller MX
dig +short MX rxf-sys.de

# Aktuelles SPF / DMARC / vorhandene DKIM-Selectoren
dig +short TXT rxf-sys.de
dig +short TXT _dmarc.rxf-sys.de
dig +short TXT mail._domainkey.rxf-sys.de

# Registrar (nicht identisch mit dem DNS-Betreiber!)
whois rxf-sys.de | grep -iE 'registrar|nserver|status'
```

Erwartete Ergebnisse und was sie bedeuten:

| `dig NS` liefert | Bedeutung | Konsequenz |
|------------------|-----------|------------|
| `*.ns.cloudflare.com` | Zone liegt auf Cloudflare | Alle Records in [04-dns.md](04-dns.md) im Cloudflare-Dashboard pflegen. Strato ist nur noch Registrar. Einfachster Fall. |
| `*.stratoserver.net` / `docks*.rzone.de` | Zone liegt bei Strato | Dann kann der Cloudflare Tunnel keine DNS-Records anlegen — prüfen, wie die 12 Hostnames dann auflösen. Vermutlich ist die Doku veraltet. |

Beim MX gilt:

| `dig MX` liefert | Bedeutung |
|------------------|-----------|
| `route1.mx.cloudflare.net` o. ä. | **Cloudflare Email Routing ist aktiv** und hält den MX. Muss vor der Umstellung deaktiviert werden, sonst überschreibt Cloudflare deinen MX-Record — siehe [04-dns.md](04-dns.md#2-cloudflare-email-routing-abschalten). |
| `mx*.strato.de` / `smtpin.rzone.de` | Strato-Postfächer nehmen die Mail an. Klassischer Migrationsfall. |

> Wenn Cloudflare Email Routing den MX hält, gehen Mails an `info@rxf-sys.de`
> aktuell **nicht** in ein Strato-Postfach, sondern direkt weiter nach Gmail.
> Dann gibt es unter Umständen gar kein Strato-Postfach zu migrieren, sondern
> nur den SMTP-Sendezugang. Das würde die Migration deutlich verkürzen —
> unbedingt vorher klären.

---

## 3. Was liegt bei Strato?

Im Strato-Kundenbereich unter *E-Mail → E-Mail-Adressen verwalten* abklappern
und hier festhalten:

| Adresse | Typ | Größe | Ziel nach Migration |
|---------|-----|-------|---------------------|
| `info@rxf-sys.de` | Postfach / Weiterleitung? | ? | Postfach auf CT 112 |
| … | | | |

Postfachgrößen per IMAP verifizieren, ohne durchs Webinterface zu klicken:

```bash
# Auf dem Host oder in einem CT mit imapsync-Paket
apt install -y imapsync

# Nur zählen und messen, nichts übertragen
imapsync --dry \
  --host1 imap.strato.de --port1 993 --ssl1 \
  --user1 'info@rxf-sys.de' --password1 'STRATO_PW' \
  --host2 imap.strato.de --port2 993 --ssl2 \
  --user2 'info@rxf-sys.de' --password2 'STRATO_PW' \
  --justfolders --justfoldersizes
```

Strato-Zugangsdaten (zur Referenz):

| Dienst | Host | Port | Verschlüsselung |
|--------|------|------|-----------------|
| IMAP | `imap.strato.de` | 993 | SSL/TLS |
| IMAP | `imap.strato.de` | 143 | STARTTLS |
| SMTP | `smtp.strato.de` | 465 | SSL/TLS |
| SMTP | `smtp.strato.de` | 587 | STARTTLS |
| POP3 | `pop3.strato.de` | 995 | SSL/TLS |

Login ist immer die **vollständige Mailadresse**.

**Disk-Sizing:** Summe aller Postfächer × 2,5 als rootfs für CT 112 ansetzen
(Maildir braucht mehr als das Rohvolumen: Dovecot-Indizes, Rspamd-Statistik,
Logs, Reserve für Wachstum). Unter 10 GB Rohvolumen sind 32 GB richtig. Über
20 GB Rohvolumen: [02-ct112-mailserver.md](02-ct112-mailserver.md#disk-über-20-gb)
lesen.

---

## 4. Passt es auf den Server?

```bash
# RAM-Situation
free -m
awk '{s+=$1} END {print s" MB zugewiesen"}' <(for i in $(pct list | awk 'NR>1{print $1}'); do pct config $i | awk '/^memory:/{print $2}'; done; for i in $(qm list | awk 'NR>1{print $1}'); do qm config $i | awk '/^memory:/{print $2}'; done)

# Thin-Pool
pvesm status
lvs pve

# Ist 192.168.2.215 frei?
ping -c1 -W1 192.168.2.215 || echo "frei"
arp -n | grep 192.168.2.215 || echo "kein ARP-Eintrag"

# Ist VMID 112 frei?
pct list; qm list
```

Erwartung nach Doku-Stand: 28160 MB von 31871 MB zugewiesen → **3711 MB
Luft**. Ein 2-GB-CT würde daraus 95 % machen. Vorher aufräumen, siehe
[01-architektur.md](01-architektur.md#ressourcenbudget).

---

## 5. Entscheidungs-Checkliste

Erst weiter, wenn alle Punkte beantwortet sind:

- [ ] `dig NS rxf-sys.de` → Zone liegt bei: ______________
- [ ] `dig MX rxf-sys.de` → MX zeigt auf: ______________
- [ ] Cloudflare Email Routing aktiv? ja / nein
- [ ] Anzahl zu migrierender Postfächer: ____, Gesamtvolumen: ____ GB
- [ ] Webmail + CalDAV/CardDAV nötig? ja → Mailcow-Pfad / nein → docker-mailserver
- [ ] VPS-Anbieter gewählt, Port-25-Freischaltung geklärt
- [ ] 2 GB RAM auf rxf-sys freigeräumt
- [ ] Externer SMTP für PVE/PBS-Alerts bleibt bestehen
- [ ] [07-rollback.md](07-rollback.md) gelesen
