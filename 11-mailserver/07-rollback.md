# 07 — Rollback

**Vor** dem Cutover lesen, nicht danach. Im Ernstfall willst du keine
Entscheidungen treffen, sondern eine Liste abarbeiten.

---

## Voraussetzung: das Strato-Postfach lebt noch

Der ganze Rollback funktioniert nur, solange der Strato-Mailtarif nicht
gekündigt ist. Deshalb die 4 Wochen Parallelbetrieb aus
[05-migration.md](05-migration.md#7-strato-kündigen-oder-behalten).

Bewahre außerdem auf:

- [ ] Strato-Zugangsdaten (Vaultwarden, CT 102)
- [ ] Die alten DNS-Records **im Wortlaut**, vor der Änderung als Screenshot
      oder Textdatei gesichert — insbesondere MX-Prioritäten, alter SPF-Record
      und ob Cloudflare Email Routing aktiv war
- [ ] Die Cloudflare-Email-Routing-Regeln (welche Adresse ging wohin)

```bash
# Vor der Umstellung: Ist-Zustand wegschreiben
for r in MX TXT NS; do echo "=== $r ==="; dig +noall +answer $r rxf-sys.de; done \
  > ~/dns-vor-migration-$(date +%F).txt
dig +noall +answer TXT _dmarc.rxf-sys.de >> ~/dns-vor-migration-$(date +%F).txt
```

---

## Entscheidungsbaum

| Symptom | Kein Rollback nötig | Rollback |
|---------|---------------------|----------|
| Einzelne Empfänger sortieren in Spam | nachbessern: DKIM/SPF/DMARC prüfen, mail-tester | — |
| Mail an große Anbieter wird **abgewiesen** (5xx) | Blocklist prüfen, VPS-IP tauschen | wenn nach 24 h nicht behoben |
| Eingehende Mail kommt nicht an | WireGuard, `relay_recipients`, Postfix-Queue prüfen | wenn nach 2 h nicht behoben |
| CT 112 defekt, Daten intakt | Restore aus PBS | — |
| CT 112 defekt, Daten weg | Restore aus PBS | wenn Restore scheitert |
| VPS gekündigt/gesperrt | neuen VPS, DNS anpassen | ja, während des Neuaufbaus |
| Du hast einfach keine Lust mehr | — | ja, ist legitim |

Als Faustregel: **Eingehende Mail ist wichtiger als das Projekt.** Wenn Mail
länger als ein paar Stunden nicht ankommt, zurück zu Strato und in Ruhe
nachforschen. Sendende Server wiederholen bis zu fünf Tage — ein Rollback
innerhalb dieses Fensters verliert keine Mail.

---

## Rollback-Ablauf

### 1. MX zurückstellen (der eine wichtige Schritt)

```bash
# Alter Wert aus ~/dns-vor-migration-*.txt
# Typisch Strato:
#   MX  @  10  mx00.strato.de
#   MX  @  20  mx01.strato.de
```

Im DNS-Dashboard den MX auf `mail.rxf-sys.de` löschen und die alten Records
wieder anlegen. Bei aktivem Cloudflare Email Routing stattdessen: *Email* →
*Email Routing* → **Enable**, Cloudflare setzt seine MX-Records selbst zurück.

TTL steht auf 300 s → nach 5–10 Minuten greift die Änderung.

```bash
dig +short MX rxf-sys.de @1.1.1.1
dig +short MX rxf-sys.de @8.8.8.8
```

### 2. SPF zurücksetzen

```
v=spf1 include:_spf.strato.de ~all
```

Die VPS-IP kann drin bleiben, solange CT 112 noch sendet, schadet aber nicht,
wenn sie raus ist.

### 3. DMARC entschärfen

Falls schon auf `p=quarantine` oder `p=reject`: zurück auf

```
v=DMARC1; p=none; rua=mailto:dmarc@rxf-sys.de
```

Sonst verwirft die Welt Mail, die Strato in deinem Namen sendet, solange SPF
und DKIM noch auf den eigenen Server zeigen.

### 4. MTA-STS abschalten

Falls auf `mode: enforce`: **zuerst** hier ansetzen, sogar noch vor dem MX.
Ein `enforce`-Policy, die auf `mail.rxf-sys.de` festgelegt ist, verhindert die
Zustellung an die Strato-MX-Server.

```
version: STSv1
mode: none
max_age: 604800
mx: mail.rxf-sys.de
```

Und die `id` im TXT-Record `_mta-sts` hochzählen, sonst wird die Änderung nicht
abgeholt. Fremde Server haben die alte Policy bis zu `max_age` gecacht — mit
`max_age: 604800` sind das sieben Tage. **Deshalb während der Einführung
`max_age` niedrig halten (z. B. 86400) und erst am Ende erhöhen.**

### 5. Zwischenzeitlich empfangene Mail zurücksynchronisieren

Alles, was zwischen Cutover und Rollback in CT 112 gelandet ist, fehlt sonst
im Strato-Postfach. Derselbe imapsync-Befehl, Richtung getauscht:

```bash
imapsync \
  --host1 127.0.0.1 --port1 993 --ssl1 \
  --user1 'info@rxf-sys.de' --passfile1 /root/migration/pw_local \
  --host2 imap.strato.de --port2 993 --ssl2 \
  --user2 'info@rxf-sys.de' --passfile2 /root/migration/pw_strato \
  --automap --useheader 'Message-ID' --useheader 'Date' --skipsize \
  --logdir /root/migration/logs --logfile rollback-$(date +%F-%H%M).log
```

Achtung: Strato-Postfächer haben ein Speicherlimit. Wenn CT 112 inzwischen mehr
Mail hält als dort hineinpasst, nur die neuen Ordner zurückspiegeln
(`--include 'INBOX'`).

### 6. Clients zurückstellen

IMAP/SMTP wieder auf `imap.strato.de` / `smtp.strato.de`, Ports 993/465. Die
Zugangsdaten sind unverändert, sofern du das Strato-Passwort nicht geändert
hast.

### 7. CT 112 nicht wegwerfen

```bash
pct stop 112
# Container behalten — der Aufbau war die Arbeit, nicht die Config
```

Damit bleibt der Weg zurück offen: Fehler analysieren, Ursache abstellen,
zweiter Versuch. Der Container ist im PBS-Backup, kostet gestoppt kein RAM und
belegt im Thin-Pool nur das Genutzte.

Falls du das Projekt endgültig abbläst:

```bash
pct destroy 112
rm /etc/pve/firewall/112.fw
# VPS kündigen, WireGuard-Peer entfernen
# DNS: A/AAAA mail, DKIM, _mta-sts, _smtp._tls, SRV-Records entfernen
```

Und dann Variante C aus
[01-architektur.md](01-architektur.md#variante-c--postfächer-zu-hause-strato-bleibt-postbote)
in Erwägung ziehen — eigene Postfächer zu Hause, Strato als Postbote. Das
liefert einen guten Teil des Nutzens ohne jedes Zustellrisiko.

---

## Nach dem Rollback

- [ ] Kuma-Monitore für Mail deaktivieren, damit keine Daueralarme laufen
- [ ] PVE/PBS-Notifications prüfen (die liefen ohnehin über Strato)
- [ ] `dig`-Kontrolle: MX, SPF, DMARC, MTA-STS wieder im alten Zustand
- [ ] Testmail von Gmail an `info@rxf-sys.de` — kommt sie bei Strato an?
- [ ] Testmail von `info@rxf-sys.de` nach außen — geht sie über Strato raus?
- [ ] Ursache in [../CHANGE~1.MD](../CHANGE~1.MD) und in diesem Verzeichnis
      dokumentieren, damit der zweite Versuch nicht dieselbe Wand trifft
