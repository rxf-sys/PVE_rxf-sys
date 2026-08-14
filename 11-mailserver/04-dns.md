# 04 — DNS-Records

Der sichtbare Teil. Alles bis hier war folgenlos — ab jetzt wird produktive
Mail umgeleitet. Deshalb die Reihenfolge strikt einhalten: **erst die Records,
die nichts umlenken (A, DKIM, SPF vorbereiten), dann der MX.**

> Zuerst klären, wo die Zone liegt:
> [00-machbarkeit.md](00-machbarkeit.md#2-wo-liegt-die-dns-zone). Die
> folgenden Schritte gehen von Cloudflare als DNS-Betreiber aus, weil der
> Tunnel dort 12 Hostnames verwaltet. Bei Strato-DNS ist der Ablauf identisch,
> nur das Eingabeformular ist ein anderes.

---

## 1. TTL absenken — mindestens 24 h vorher

Vor allen anderen Änderungen die TTL der Records, die du anfassen wirst, auf
**300 Sekunden** stellen und einen Tag warten. Sonst hängen fremde Resolver
nach dem Cutover stundenlang am alten MX, und ein Rollback wirkt nicht.

Bei Cloudflare bedeutet „Auto"-TTL für graue (unproxied) Records 300 s — dann
ist nichts zu tun. Bei Strato explizit setzen.

```bash
dig +noall +answer MX rxf-sys.de       # TTL in der zweiten Spalte prüfen
```

---

## 2. Cloudflare Email Routing abschalten

**Nur wenn aktiv** (siehe
[00-machbarkeit.md](00-machbarkeit.md#2-wo-liegt-die-dns-zone)) — dann hält es
den MX und überschreibt eigene MX-Records wieder.

Dashboard → Zone `rxf-sys.de` → **Email** → *Email Routing* → *Settings* →
**Disable Email Routing**.

Danach kontrollieren, dass die drei `route*.mx.cloudflare.net`-MX-Records und
der `cf2024-1._domainkey`-TXT-Record verschwunden sind:

```bash
dig +short MX rxf-sys.de
dig +short TXT rxf-sys.de
```

> **Wichtig:** In dem Moment, in dem Email Routing aus ist und noch kein neuer
> MX steht, ist die Domain für Mail **nicht erreichbar**. Sendende Server
> wiederholen zwar, aber der nächste Schritt sollte direkt folgen. Am besten
> Abschnitte 3–6 vorher vorbereiten und Email Routing als letzten Handgriff vor
> dem MX-Wechsel abschalten.
>
> Und: die Weiterleitung `info@rxf-sys.de → Gmail` hört damit auf zu
> funktionieren. Wenn du sie behalten willst, richte sie stattdessen als
> Sieve-Regel oder Alias auf CT 112 ein.

---

## 3. A/AAAA für `mail.rxf-sys.de`

| Typ | Name | Wert | Proxy | TTL |
|-----|------|------|-------|-----|
| A | `mail` | `<VPS-IPv4>` | **DNS only (grau)** | 300 |
| AAAA | `mail` | `<VPS-IPv6>` | **DNS only (grau)** | 300 |

> **Der häufigste Fehler im ganzen Projekt:** den Record auf „Proxied"
> (orangene Wolke) stehen lassen. Dann löst `mail.rxf-sys.de` auf
> Cloudflare-IPs auf, Cloudflare proxyt kein SMTP, der PTR passt nicht mehr —
> und der MX ist tot. **Graue Wolke, immer.**

Kontrolle:

```bash
dig +short A mail.rxf-sys.de       # muss die VPS-IP sein, keine 104.x/172.6x
dig +short -x <VPS-IPv4>           # muss mail.rxf-sys.de. sein
```

---

## 4. DKIM

Public Key aus
[02-ct112-mailserver.md](02-ct112-mailserver.md#dkim-key-erzeugen) als TXT:

| Typ | Name | Wert |
|-----|------|------|
| TXT | `mail._domainkey` | `v=DKIM1; k=rsa; p=MIIBIjANBgkq...` |

Fallstricke:

- Der von `setup config dkim` erzeugte Text enthält oft Zeilenumbrüche und
  Anführungszeichen in mehreren Teilstrings (`"..." "..."`). Für Cloudflare
  **alles zu einer Zeile ohne Anführungszeichen** zusammenziehen, nur der
  reine Inhalt ab `v=DKIM1`.
- Kein Leerzeichen innerhalb des `p=`-Base64.
- 2048-Bit-Keys überschreiten 255 Zeichen pro String; DNS-Anbieter splitten
  intern selbst. Bei Cloudflare einfach am Stück einfügen.

Kontrolle:

```bash
dig +short TXT mail._domainkey.rxf-sys.de

# Ende-zu-Ende: Signatur an einer echten Mail prüfen
docker exec mailserver rspamadm dkim_keygen -s mail -d rxf-sys.de -t   # nur Testausgabe
```

Wirklich verifiziert ist DKIM erst, wenn eine Testmail bei Gmail mit
`dkim=pass header.d=rxf-sys.de` ankommt — siehe [06-betrieb.md](06-betrieb.md#zustelltests).

---

## 5. SPF

Ausgehende Mail verlässt das Netz **ausschließlich** über die VPS-IP. Der
Record ist deshalb kurz:

| Typ | Name | Wert |
|-----|------|------|
| TXT | `@` | `v=spf1 ip4:<VPS-IPv4> ip6:<VPS-IPv6> ~all` |

- Nur **einen** SPF-Record pro Domain. Mehrere `v=spf1`-TXT-Records = `permerror`
  = SPF gilt als ungültig. Alte Strato- und Cloudflare-Einträge vorher entfernen.
- Start mit `~all` (softfail). Nach 1–2 Wochen ohne Auffälligkeiten in den
  DMARC-Reports auf `-all` (hardfail) verschärfen.
- **Solange Strato noch Mail versendet** (Parallelbetrieb, PVE-Notifications),
  muss Strato mit drin stehen:
  `v=spf1 ip4:<VPS-IPv4> ip6:<VPS-IPv6> include:_spf.strato.de ~all`
  Das `include` erst entfernen, wenn wirklich nichts mehr über Strato geht.
  Wenn die Infra-Alerts dauerhaft über Strato laufen
  ([06-betrieb.md](06-betrieb.md#infra-alerts-nicht-über-den-eigenen-mailserver)),
  bleibt der `include` dauerhaft stehen.

```bash
dig +short TXT rxf-sys.de | grep spf1      # muss genau eine Zeile sein
```

---

## 6. DMARC

Stufenweise verschärfen, nicht direkt auf `reject`:

| Phase | Wert | Wann |
|-------|------|------|
| 1 — beobachten | `v=DMARC1; p=none; rua=mailto:dmarc@rxf-sys.de; ruf=mailto:dmarc@rxf-sys.de; fo=1; adkim=r; aspf=r` | ab Cutover |
| 2 — aussortieren | `v=DMARC1; p=quarantine; pct=25; rua=mailto:dmarc@rxf-sys.de` | nach 1–2 Wochen sauberen Reports |
| 3 — abweisen | `v=DMARC1; p=reject; rua=mailto:dmarc@rxf-sys.de; adkim=s; aspf=s` | nach weiteren 2 Wochen |

| Typ | Name | Wert |
|-----|------|------|
| TXT | `_dmarc` | siehe Phase |

`p=reject` erst, wenn du die Reports wirklich gelesen hast. Sonst verwirft die
Welt still Mail, die du versendet hast — z. B. weil ein Gerät noch über Strato
sendet.

Die Reports gehen an `dmarc@rxf-sys.de` — das Postfach muss existieren
([02-ct112-mailserver.md](02-ct112-mailserver.md#5-docker-mailserver)). Sie
kommen als gezippte XML. Zum Lesen genügt ein Online-Parser oder
`dmarc-report-converter`; wichtig ist nur, dass du in Woche 1 hineinschaust.

---

## 7. Der MX — der Punkt ohne Wiederkehr

Erst wenn 3–6 stehen und
[der Ende-zu-Ende-Test](03-vps-relay.md#8-ende-zu-ende-test-vor-der-dns-umstellung)
grün war:

| Typ | Name | Priorität | Wert | Proxy | TTL |
|-----|------|-----------|------|-------|-----|
| MX | `@` | 10 | `mail.rxf-sys.de` | — | 300 |

Alte MX-Records (Strato, Cloudflare Email Routing) **löschen**, nicht auf
höhere Priorität setzen. Ein Backup-MX mit Strato dahinter klingt nach
Absicherung, ist aber eine Falle: Spammer zielen bevorzugt auf den
Backup-MX, und du bekommst gespaltene Zustellung ohne es zu merken. Sendende
Server wiederholen von sich aus bis zu fünf Tage — das ist die bessere
Absicherung.

```bash
dig +short MX rxf-sys.de
# 10 mail.rxf-sys.de.

# MX muss auf einen Namen mit A-Record zeigen, nicht auf ein CNAME
dig +short A mail.rxf-sys.de
```

**Ab hier läuft die Uhr:** weiter mit
[05-migration.md](05-migration.md#4-cutover-runbook).

---

## 8. Optional, aber empfehlenswert

### Autoconfig / Autodiscover

Damit Thunderbird und Outlook die Einstellungen selbst finden, statt dass du
sie auf jedem Gerät tippst. Beides ist reines HTTPS und läuft damit über den
**bestehenden Cloudflare Tunnel** — z. B. als weiterer Hostname auf die Caddy-
Instanz in CT 108
([../05-container/lxc/CT108-welcome-page.md](../05-container/lxc/CT108-welcome-page.md)).

| Typ | Name | Wert | Zweck |
|-----|------|------|-------|
| SRV | `_imaps._tcp` | `0 1 993 mail.rxf-sys.de` | RFC 6186 |
| SRV | `_submissions._tcp` | `0 1 465 mail.rxf-sys.de` | RFC 6186 |
| SRV | `_imap._tcp` | `0 0 .` | „gibt es nicht" (unverschlüsselt) |
| SRV | `_submission._tcp` | `0 0 .` | dito |
| CNAME | `autoconfig` | Tunnel-Hostname | Thunderbird |
| CNAME | `autodiscover` | Tunnel-Hostname | Outlook |

`autoconfig.rxf-sys.de/mail/config-v1.1.xml` (Thunderbird):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<clientConfig version="1.1">
  <emailProvider id="rxf-sys.de">
    <domain>rxf-sys.de</domain>
    <displayName>rxf-sys Mail</displayName>
    <incomingServer type="imap">
      <hostname>mail.rxf-sys.de</hostname>
      <port>993</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    <outgoingServer type="smtp">
      <hostname>mail.rxf-sys.de</hostname>
      <port>465</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </outgoingServer>
  </emailProvider>
</clientConfig>
```

> `password-cleartext` klingt falsch, ist aber korrekt: es bedeutet
> „Passwort im Klartext **innerhalb** der TLS-Verbindung" — das übliche
> `AUTH PLAIN` über TLS.

### MTA-STS und TLS-RPT

Erzwingt TLS für eingehende Mail und lässt dich Fehler sehen. Braucht eine
HTTPS-Seite — wieder über den Cloudflare Tunnel:

| Typ | Name | Wert |
|-----|------|------|
| TXT | `_mta-sts` | `v=STSv1; id=20260814000000` |
| TXT | `_smtp._tls` | `v=TLSRPTv1; rua=mailto:dmarc@rxf-sys.de` |
| CNAME | `mta-sts` | Tunnel-Hostname (CT 108) |

`https://mta-sts.rxf-sys.de/.well-known/mta-sts.txt`:

```
version: STSv1
mode: testing
max_age: 604800
mx: mail.rxf-sys.de
```

`mode: testing` zuerst — es meldet Fehler, erzwingt aber nichts. Nach 1–2
Wochen ohne Fehlerberichte auf `mode: enforce`. Bei jeder Änderung der Datei
muss die `id` im TXT-Record hochgezählt werden.

> Bei `mode: enforce` und einem später abgelaufenen Zertifikat auf dem VPS
> nehmen fremde Server **keine** Mail mehr an. Der Zertifikatsmonitor aus
> [06-betrieb.md](06-betrieb.md#monitoring) ist dann Pflicht, nicht optional.

---

## 9. Kontroll-Snippet

Alles auf einmal prüfen:

```bash
for r in "MX rxf-sys.de" "TXT rxf-sys.de" "TXT _dmarc.rxf-sys.de" \
         "TXT mail._domainkey.rxf-sys.de" "A mail.rxf-sys.de" \
         "AAAA mail.rxf-sys.de" "TXT _mta-sts.rxf-sys.de"; do
  printf '%-38s ' "$r"
  dig +short $r | tr '\n' ' '
  echo
done
echo -n "PTR v4: "; dig +short -x <VPS-IPv4>
echo -n "PTR v6: "; dig +short -x <VPS-IPv6>
```
