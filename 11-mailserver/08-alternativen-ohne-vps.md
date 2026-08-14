# 08 — Alternativen ohne eigenen VPS

Die naheliegende Frage: *Kann ich den VPS nicht einfach als VM auf rxf-sys
laufen lassen?* Und danach: *Was gibt es sonst?*

---

## 1. VPS auf dem eigenen Server — nein

Technisch kannst du natürlich eine VM anlegen; „VPS" heißt ja wörtlich nichts
anderes. Nur nützt es nichts, denn der Wert des VPS liegt nicht darin, **was**
er ist, sondern **wo** er steht.

Der Relay muss vier Eigenschaften mitbringen. Alle vier sind Eigenschaften des
Anschlusses, nicht der Maschine:

| Was gebraucht wird | VPS beim Hoster | VM auf rxf-sys |
|--------------------|-----------------|----------------|
| Statische IPv4, aus dem Internet auf **Port 25** erreichbar | ja | **nein** — dieselbe dynamische Anschluss-IP wie alles andere, und der Router leitet nichts weiter |
| PTR-Record selbst setzbar | ja | **nein** — der PTR gehört dem Provider |
| IP nicht in der Spamhaus PBL | ja | **nein** — Endkunden-Range, per Definition gelistet |
| Port 25 ausgehend offen | ja | oft vom ISP geblockt |

Eine VM auf rxf-sys erbt die Anschluss-IP des Heimnetzes. Damit hat sie exakt
dieselben drei Blocker wie CT 112 selbst
([00-machbarkeit.md](00-machbarkeit.md#1-warum-direktbetrieb-zu-hause-ausfällt)).
Du hättest eine zweite Maschine mit demselben Problem — nur mit mehr
RAM-Verbrauch.

Kurz: **Der VPS ist kein Rechner, den du brauchst, sondern eine IP-Adresse, die
du mietest.** Die Maschine ist nur das, was mit der Adresse mitkommt.

### Zwei Varianten der Frage, die sich lohnen

**„Ich habe doch ein statisches IPv6-Präfix?"** Manche Anbieter delegieren ein
festes IPv6-Präfix. Trotzdem tot: rDNS für IPv6 wird an Privatkunden praktisch
nie delegiert, und ein reiner IPv6-MX ist unerreichbar für alle sendenden
Server ohne IPv6 — das ist noch immer ein erheblicher Teil. IPv6 kann Beiwerk
sein, nie der einzige Weg.

**„Dann nehme ich einen kostenlosen VPS."** Funktioniert nicht: Oracle Cloud
Always Free, Google Cloud Free Tier und AWS Free Tier sperren Port 25 ausgehend
**dauerhaft** und schalten ihn für Free-Accounts nicht frei. Genau deshalb sind
sie kostenlos. Der billigste Weg zu einer Port-25-fähigen IP sind die 4–5 €
bei Hetzner oder netcup.

---

## 2. Warum Tunnel- und Portweiterleitungsdienste ausfallen

Der Reflex ist, statt eines VPS irgendeinen Tunneldienst zu nehmen. Das
scheitert an einem Detail des Protokolls:

> **Ein MX-Record hat kein Portfeld.** Er nennt nur einen Hostnamen. Sendende
> Mailserver verbinden sich immer auf **Port 25**. Jeder Dienst, der dir einen
> zufälligen oder abweichenden Port gibt, ist für einen MX unbrauchbar.

| Dienst | Warum nicht |
|--------|-------------|
| **ngrok TCP**, localhost.run, bore | vergeben zufällige Ports. Kein MX möglich. |
| **Tailscale Funnel** | nur 443, 8443, 10000 und ausschließlich HTTPS |
| **Cloudflare Tunnel** (hast du schon, CT 110) | nur HTTP/HTTPS/WebSocket |
| **Cloudflare Spectrum** | beliebige TCP-Ports erst im Enterprise-Tarif, und SMTP gehört nicht zu den unterstützten Anwendungen |
| **frp / pgrok / WireGuard selbst gehostet** | brauchen einen Server mit öffentlicher IP als Gegenstelle — also wieder einen VPS |

Damit bleiben genau zwei Wege, wie Mail ohne offenen Port und ohne VPS zu dir
kommt. Beide funktionieren, weil **du** die Verbindung nach außen aufbaust:

- **Pull** — ein Dienst nimmt die Mail an und lagert sie; CT 112 holt sie ab.
- **Push über HTTPS** — ein Dienst nimmt die Mail an und schiebt sie als
  HTTPS-Request durch den Cloudflare Tunnel, den du schon hast.

---

## 3. Variante P — Pull: Postfächer zu Hause, Provider als Briefkasten

Das ist Variante C aus
[01-architektur.md](01-architektur.md#variante-c--postfächer-zu-hause-strato-bleibt-postbote),
hier nur konkret.

```
Internet ──25──► Provider-Postfach ◄──IMAP-Poll── CT 112 (getmail6)
                 (Strato, Migadu, …)                    │
                                                        ▼
CT 112 ──Submission──► Provider-SMTP ──25──► Internet   Dovecot/Maildir
```

**Eingang:** `getmail6` oder `fetchmail` in CT 112 pollt alle 1–5 Minuten das
Provider-Postfach per IMAP und liefert per LMTP an Dovecot. Der MX bleibt beim
Provider, keine DNS-Änderung nötig.

**Ausgang:** `smtp.strato.de:465` als Smarthost — genau der Zugang, der laut
[../07-monitoring/notifications.md](../07-monitoring/notifications.md) schon
konfiguriert ist. SPF, DKIM und DMARC bleiben Sache des Providers.

```bash
# In CT 112
apt install -y getmail6

install -d -m 700 /etc/getmail
cat >/etc/getmail/getmailrc-info <<'EOF'
[retriever]
type = SimpleIMAPSSLRetriever
server = imap.strato.de
port = 993
username = info@rxf-sys.de
password = STRATO_PW

[destination]
type = MDA_external
path = /usr/lib/dovecot/dovecot-lda
arguments = ("-d", "info@rxf-sys.de")

[options]
delete = false          # zunächst false! erst nach Wochen ohne Fehler auf true
read_all = false
delivered_to = false
received = false
message_log = /var/log/getmail.log
EOF
chmod 600 /etc/getmail/getmailrc-info

# Alle 2 Minuten per systemd-Timer
systemd-run --on-active=120 --unit=getmail-test \
  getmail --rcfile /etc/getmail/getmailrc-info
```

> `delete = false` in den ersten Wochen. Damit bleibt jede Mail zusätzlich beim
> Provider liegen — dein Sicherheitsnetz, solange du dem eigenen Setup noch
> nicht traust. Erst danach auf `true`, sonst läuft das Provider-Postfach voll.

| | |
|---|---|
| **Kosten** | 0–3 €/Monat (bestehender Mailtarif) |
| **DNS-Änderung** | keine |
| **Port-Forwarding** | keins |
| **Verzögerung** | Poll-Intervall, praktisch 1–5 Minuten |
| **Zustellrate** | die des Providers, also sehr gut |
| **Risiko** | minimal — nichts Produktives wird umgestellt |
| **Nachteil** | Provider bleibt im Spiel; Mail an nicht existierende Adressen und Spam werden erst beim Provider entschieden; kein „richtiger" eigener MX |

**Das ist der ehrlichste Einstieg.** Du bekommst eigene Postfächer, eigene
Suche, eigenes Backup über PBS — und kannst später jederzeit auf den VPS-Weg
umschalten, ohne die Postfächer erneut zu migrieren.

Statt Strato geht auch jeder andere günstige Anbieter mit eigener Domain
(Migadu, Purelymail, mailbox.org, Fastmail, 1–3 €/Monat), wenn es dir vor allem
darum geht, **von Strato weg** zu kommen.

---

## 4. Variante H — Push über HTTPS in den bestehenden Tunnel

Die interessante Variante: der Eingang läuft über den Cloudflare Tunnel, den du
für 12 Hostnames schon betreibst. Nicht als SMTP — sondern als HTTPS-Request
mit der Mail im Body.

```
Internet ──25──► Cloudflare Email Routing
                        │
                        ▼
                 Email Worker (JS)  ── liest raw MIME
                        │
                        │ HTTPS POST (mit Shared Secret)
                        ▼
              Cloudflare Tunnel (CT 110)
                        │
                        ▼
              mail-ingest (CT 112) ──► Postfix sendmail ──► Dovecot/Maildir

CT 112 ──Submission──► Transaktions-SMTP ──25──► Internet
```

**Eingang:** Cloudflare Email Routing hält den MX (kostenlos, hast du
möglicherweise schon aktiv) und routet auf einen **Email Worker**. Der Worker
bekommt die vollständige MIME-Nachricht und `fetch`t sie an einen Endpunkt in
deinem Netz — über den Tunnel, also ohne offenen Port. In CT 112 nimmt ein
kleiner HTTP-Dienst sie an und übergibt sie an Postfix.

Worker-Skizze:

```javascript
export default {
  async email(message, env, ctx) {
    const raw = await new Response(message.raw).arrayBuffer();
    const res = await fetch("https://mail-ingest.rxf-sys.de/inject", {
      method: "POST",
      headers: {
        "Content-Type": "message/rfc822",
        "X-Ingest-Token": env.INGEST_TOKEN,
        "X-Envelope-From": message.from,
        "X-Envelope-To": message.to,
      },
      body: raw,
    });
    if (!res.ok) {
      // Ablehnen, damit Cloudflare es erneut versucht statt die Mail zu verlieren
      message.setReject("temporary failure at destination");
    }
  },
};
```

Empfangsseite in CT 112 (Skizze, z. B. als kleiner Python/Node-Dienst hinter
dem Tunnel):

```
POST /inject
  → X-Ingest-Token prüfen (konstantzeitvergleich!)
  → Body an: sendmail -G -i -f <envelope-from> -- <envelope-to>
  → 200 nur wenn sendmail Exit 0, sonst 5xx
```

**Ausgang:** Email Workers können keine beliebige Mail versenden, nur
antworten. Der Versand läuft deshalb über einen Transaktions-SMTP als
Smarthost (`RELAY_HOST` in docker-mailserver):

| Dienst | Freikontingent | Anmerkung |
|--------|----------------|-----------|
| Brevo | ~300 Mails/Tag | SMTP-Relay, DKIM über deren Domain oder eigene |
| Mailjet | ~200/Tag, 6000/Monat | dito |
| SMTP2GO | ~1000/Monat | dito |
| Amazon SES | ~0,10 $ / 1000 Mails | kein Freikontingent, aber sehr günstig; eigene DKIM-Domain möglich |

SPF muss dann den Provider einschließen (`include:...`), DKIM signiert
entweder der Provider für deine Domain oder du selbst in CT 112 mit Rspamd.

| | |
|---|---|
| **Kosten** | 0–2 €/Monat |
| **DNS-Änderung** | ja (MX auf Cloudflare Email Routing, SPF auf den Versanddienst) |
| **Port-Forwarding** | keins |
| **Verzögerung** | praktisch sofort |
| **Zustellrate** | gut (Reputation des Versanddienstes) |
| **Nachteil** | **nicht standardisiert.** Zwei Cloudflare-Produkte plus ein selbstgeschriebener Ingest-Dienst in der Kette. Größenlimit von Email Routing (~25 MB) gilt. Fehlersuche ist unangenehm, weil kein Postfix-Log den Eingang zeigt. Kontingente der Freitarife beachten. |

Ehrlich: **technisch elegant, betrieblich fragil.** Empfehlenswert, wenn dich
das Basteln interessiert; nicht, wenn du einen Mailserver willst, der einfach
läuft. Der selbstgeschriebene Ingest-Endpunkt ist zudem eine
authentifizierungsbedürftige Schnittstelle, über die jeder Mail in dein
Postfach injizieren kann, der das Token kennt.

Dieselbe Bauform geht auch mit anderen Anbietern statt Cloudflare — Mailgun
Routes oder Amazon SES mit Lambda liefern ebenfalls per HTTP-Webhook. Das
Muster ist identisch, die Abhängigkeit nur eine andere.

---

## 5. Variante R — Inbound-Relay-Dienst auf einen abweichenden Port

Es gibt Dienste, die als MX für deine Domain auftreten, filtern und dann an
deinen Server weiterliefern (Kategorie „Inbound SMTP Relay" / „Mail Gateway",
z. B. DuoCircle, ~2–4 €/Monat). Manche erlauben dabei einen **abweichenden
Zielport**.

Falls ja, ergibt sich: Router leitet nur `2525/tcp` an CT 112 weiter, DynDNS
liefert die aktuelle Anschluss-IP, der Relay-Dienst stellt dorthin zu. Port 25
bleibt im Internet geschlossen, und weil ausschließlich die IP-Bereiche des
Relays einliefern, kann die PVE-Guest-Firewall den Zugang auf diese Quellen
begrenzen.

```ini
# 112.fw, ergänzend
IN ACCEPT -source <Relay-IP-Range> -p tcp -dport 2525 -log nolog
```

| | |
|---|---|
| **Kosten** | 2–4 €/Monat |
| **Port-Forwarding** | **ja**, ein Port, quellbeschränkt |
| **Vorteil** | kein VPS zu betreiben, Spamfilterung inklusive, sofortige Zustellung |
| **Nachteil** | bricht die dokumentierte Grundsatzentscheidung „kein Port-Forwarding" ([../08-sicherheit/firewall.md](../08-sicherheit/firewall.md#vom-wan)); DynDNS als zusätzliche Fehlerquelle; Ausgang braucht trotzdem einen Smarthost |

> **Vor der Buchung prüfen:** Unterstützt der Dienst wirklich einen
> abweichenden Zielport und einen DynDNS-Hostnamen als Ziel? Ohne beides
> funktioniert die Variante nicht. Nicht auf dieses Dokument verlassen —
> beim Anbieter nachfragen.

---

## 6. Variante S — Geschäftsanschluss mit statischer IP

Der Weg, der echtes Selfhosting zu Hause möglich macht: Business-Tarif beim
ISP mit statischer IPv4 und delegiertem rDNS. Dann brauchst du keinen Relay,
sondern setzt den PTR selbst und lässt Port 25 freischalten.

| | |
|---|---|
| **Kosten** | +10–20 €/Monat gegenüber dem Privattarif |
| **Aufwand** | Tarifwechsel, dann Netzumbau |
| **Vorteil** | vollständige Kontrolle, kein Dritter in der Kette, nützt auch allen anderen Diensten |
| **Nachteil** | teurer als der VPS; Port 25 muss ins Heimnetz geöffnet werden |

Und der Haken, der in diesem Netz besonders wiegt: rxf-sys ist laut
[../03-netzwerk/README.md](../03-netzwerk/README.md) **flach** — keine VLANs,
alle Guests und alle Clients in 192.168.2.0/24. Einen aus dem Internet
erreichbaren SMTP-Dienst in dasselbe Segment zu stellen wie NAS, Vaultwarden
und Home Assistant ist keine gute Idee. Diese Variante bedeutet also
zusätzlich: VLAN oder DMZ einführen, CT 112 dorthin, Firewall-Regeln zwischen
den Segmenten. Das ist ein eigenes Projekt, kein Nebeneffekt.

Vor dem Tarifwechsel beim Anbieter **schriftlich** klären: statische IPv4
enthalten? rDNS auf Wunsch setzbar? Port 25 ein- und ausgehend offen? Ohne
alle drei bringt der teurere Tarif nichts.

---

## 7. Variante M — kein Selfhosting, aber weg von Strato

Der Vollständigkeit halber, weil es oft die richtige Antwort ist: Mailhosting
mit eigener Domain bei einem Anbieter, der es gut macht. Migadu, mailbox.org,
Fastmail, Purelymail, 1–3 €/Monat. Du behältst `@rxf-sys.de`, bekommst IMAP,
Webmail, Kalender und Kontakte, und niemand muss nachts DKIM debuggen.

Das erfüllt „weg von Strato" vollständig und „eigener Server" gar nicht. Wenn
dein Ziel primär Unabhängigkeit von Strato war und nicht das Betreiben eines
Mailservers, ist das die günstigste und ruhigste Lösung — und es lässt sich
mit Variante P kombinieren: Postfächer beim Anbieter, zusätzlich eine
vollständige Kopie zu Hause auf rxf-sys, gesichert über PBS.

---

## 8. Gegenüberstellung

| | **A** VPS-Relay | **P** IMAP-Pull | **H** HTTPS-Push | **R** Inbound-Relay | **S** Business-Anschluss | **M** Managed |
|---|---|---|---|---|---|---|
| Daten liegen zu Hause | ja | ja | ja | ja | ja | nein |
| Kosten/Monat | 4–6 € | 0–3 € | 0–2 € | 2–4 € | +10–20 € | 1–3 € |
| Port-Forwarding | nein | nein | nein | **ja** (1 Port) | **ja** | nein |
| DNS-Änderung | ja | **nein** | ja | ja | ja | ja |
| Eigener MX | ja | nein | über Cloudflare | über Dienst | ja | nein |
| Zustellung eingehend | sofort | 1–5 min | sofort | sofort | sofort | sofort |
| Betriebsaufwand | hoch | niedrig | mittel–hoch | mittel | hoch | keiner |
| Standardkonform | ja | ja | **nein** | ja | ja | ja |
| Rückweg / Rollback | einfach | trivial | mittel | einfach | aufwendig | — |
| Nutzt bestehende Infra | — | Strato-SMTP | **Cloudflare Tunnel** | — | — | — |

---

## 9. Empfehlung

**Fang mit P an, wechsle später auf A.**

Begründung: P kostet dich einen Abend, ändert nichts am Produktivbetrieb und
liefert schon das Wesentliche — die Mails liegen auf rxf-sys, sind durchsuchbar
und landen in der PBS-Backup-Kette. Du lernst Dovecot, Sieve, Maildir und die
Backup-Mechanik in Ruhe kennen, während dein Mailempfang unangetastet
weiterläuft.

Wenn dir das nach ein paar Wochen zu wenig Kontrolle ist, kommt der VPS dazu
([03-vps-relay.md](03-vps-relay.md)), der MX wandert
([04-dns.md](04-dns.md)) und `getmail` wird abgeschaltet. **CT 112 bleibt dabei
unverändert** — die Postfächer müssen nicht erneut migriert werden. Das ist der
Grund, warum diese Reihenfolge nichts kostet: P ist kein Umweg, sondern die
erste Hälfte von A.

Von H würde ich abraten, solange es nicht das Basteln selbst ist, das dich
interessiert. Von S nur, wenn du das VLAN-Projekt ohnehin vorhast.
