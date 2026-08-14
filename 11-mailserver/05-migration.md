# 05 — Migration Strato → CT 112

Postfachinhalte umziehen und den Cutover fahren, ohne Mail zu verlieren.

---

## 1. Werkzeug

`imapsync` kopiert IMAP-Postfächer inkrementell und idempotent — mehrfach
laufen lassen ist unschädlich, es überträgt jeweils nur, was fehlt. Genau das
brauchen wir: einen großen Lauf vorher, kleine Delta-Läufe nachher.

```bash
# Am besten in CT 112 selbst, dann ist der Zielweg kurz
pct exec 112 -- apt install -y imapsync
```

Zugangsdaten sicher ablegen statt in die Kommandozeile (sonst stehen die
Passwörter in `~/.bash_history` und in der Prozessliste):

```bash
pct enter 112
install -d -m 700 /root/migration
cd /root/migration
printf '%s' 'STRATO_PASSWORT'  > pw_strato   && chmod 600 pw_strato
printf '%s' 'NEUES_PASSWORT'   > pw_local    && chmod 600 pw_local
```

---

## 2. Trockenlauf

Immer zuerst. Zeigt, welche Ordner gefunden werden und wie das Mapping
aussieht, überträgt aber nichts.

```bash
imapsync --dry \
  --host1 imap.strato.de --port1 993 --ssl1 \
  --user1 'info@rxf-sys.de' --passfile1 /root/migration/pw_strato \
  --host2 127.0.0.1 --port2 993 --ssl2 \
  --user2 'info@rxf-sys.de' --passfile2 /root/migration/pw_local \
  --automap \
  --useheader 'Message-ID' --useheader 'Date' \
  --skipsize \
  --logdir /root/migration/logs
```

Im Output kontrollieren:

- Werden alle Ordner erkannt? Strato nennt sie oft deutsch (`Gesendet`,
  `Entwürfe`, `Papierkorb`) — `--automap` bildet sie auf die IMAP-Sonderordner
  (`Sent`, `Drafts`, `Trash`) ab. Wenn das Mapping nicht passt, explizit setzen:

```bash
  --f1f2 'Gesendet=Sent' \
  --f1f2 'Entwürfe=Drafts' \
  --f1f2 'Papierkorb=Trash' \
  --f1f2 'Spam=Junk'
```

- Stimmt die Nachrichtenzahl mit dem Strato-Webmail überein?
- Tauchen Fehler zu Ordnern mit Umlauten auf? Dann `--addheader` weglassen und
  `--regextrans2 's/[äöüÄÖÜß]/_/g'` **nicht** verwenden — besser explizites
  `--f1f2`-Mapping, sonst zerlegst du Ordnernamen.

---

## 3. Erster vollständiger Lauf

Kann bei großen Postfächern Stunden dauern. Deshalb in `tmux`/`screen`, nicht
in einer SSH-Sitzung, die abreißt.

```bash
apt install -y tmux
tmux new -s imapsync

imapsync \
  --host1 imap.strato.de --port1 993 --ssl1 \
  --user1 'info@rxf-sys.de' --passfile1 /root/migration/pw_strato \
  --host2 127.0.0.1 --port2 993 --ssl2 \
  --user2 'info@rxf-sys.de' --passfile2 /root/migration/pw_local \
  --automap \
  --useheader 'Message-ID' --useheader 'Date' \
  --skipsize \
  --nofoldersizes \
  --logdir /root/migration/logs \
  --logfile info-full.log
```

Erklärung der Flags, die zählen:

| Flag | Warum |
|------|-------|
| `--useheader 'Message-ID' --useheader 'Date'` | Duplikaterkennung. Ohne das erzeugen Folgeläufe Doppel. |
| `--skipsize` | Strato und Dovecot berechnen Größen unterschiedlich; ohne das gilt jede Mail als geändert. |
| `--nofoldersizes` | spart bei großen Postfächern viel Zeit vorab |
| `--automap` | Sonderordner automatisch zuordnen |
| kein `--delete2` | Nichts am Ziel löschen. **Nie** setzen, solange die Migration läuft. |

Danach die Zusammenfassung am Ende des Logs lesen — sie nennt übertragene und
übersprungene Nachrichten sowie Fehler:

```bash
tail -40 /root/migration/logs/info-full.log
grep -iE 'err|failed|warn' /root/migration/logs/info-full.log | head -30
```

Für jedes weitere Postfach denselben Lauf mit angepassten `--user1`/`--user2`.
Bei mehr als zwei Postfächern lohnt eine Datei mit Zugangsdaten und eine
Schleife — dann aber `chmod 600` und nach der Migration löschen.

### Speicherplatz prüfen

```bash
pct exec 112 -- df -h /
pct exec 112 -- du -sh /opt/dms/docker-data/dms/mail-data/
```

Wenn das rootfs eng wird: `pct resize 112 rootfs +16G` (online möglich).

---

## 4. Cutover-Runbook

Der eigentliche Umzug. Zeitpunkt: **Freitagabend oder Samstagmorgen** — dann
ist wenig Geschäftsverkehr unterwegs, und du hast das Wochenende zum Nachjustieren.

| T | Schritt | Prüfung |
|---|---------|---------|
| **T-7 Tage** | VPS steht, CT 112 steht, Ende-zu-Ende-Test grün ([03-vps-relay.md](03-vps-relay.md#8-ende-zu-ende-test-vor-der-dns-umstellung)) | Test-Mail läuft in beide Richtungen |
| **T-2 Tage** | TTL aller betroffenen Records auf 300 s ([04-dns.md](04-dns.md#1-ttl-absenken--mindestens-24-h-vorher)) | `dig +noall +answer MX rxf-sys.de` |
| **T-1 Tag** | A/AAAA `mail`, DKIM, SPF, DMARC (`p=none`) anlegen — **MX noch nicht** | Kontroll-Snippet aus [04-dns.md](04-dns.md#9-kontroll-snippet) |
| **T-1 Tag** | Erster vollständiger imapsync-Lauf | Nachrichtenzahlen stimmen |
| **T-0** | Cloudflare Email Routing abschalten (falls aktiv) | `dig +short MX rxf-sys.de` → leer |
| **T-0 +1 min** | MX auf `mail.rxf-sys.de` setzen, alte MX löschen | `dig +short MX rxf-sys.de` |
| **T-0 +10 min** | Testmail von Gmail/GMX an `info@rxf-sys.de` | landet in CT 112 |
| **T-0 +30 min** | Delta-imapsync (holt, was zwischenzeitlich noch bei Strato lag) | Log ohne Fehler |
| **T-0 +1 h** | Mail-Clients umstellen (Handy, Laptop, Thunderbird) | Senden **und** Empfangen je Gerät |
| **T-0 +2 h** | Zustelltests: mail-tester.com, Gmail-Header prüfen | SPF/DKIM/DMARC = pass |
| **T+1 Tag** | Delta-imapsync erneut, DMARC-Reports ansehen | keine fremden Sender |
| **T+3 Tage** | Delta-imapsync letztes Mal, Strato-Postfach leer? | keine neuen Mails bei Strato |
| **T+7 Tage** | SPF auf `-all`, DMARC auf `p=quarantine; pct=25` | Reports weiter sauber |
| **T+14 Tage** | MTA-STS auf `enforce`, DMARC auf `p=reject` | keine Zustellprobleme |
| **T+28 Tage** | Strato-Mailtarif entscheiden — [07-rollback.md](07-rollback.md) vorher lesen | Infra-Alert-Ersatz steht |

### Delta-Lauf

Nach dem Cutover läuft neue Mail direkt in CT 112. Bei Strato liegt nur noch,
was in der DNS-Propagierungslücke dort angekommen ist. Derselbe Befehl wie
oben, er überträgt nur die Differenz:

```bash
imapsync \
  --host1 imap.strato.de --port1 993 --ssl1 \
  --user1 'info@rxf-sys.de' --passfile1 /root/migration/pw_strato \
  --host2 127.0.0.1 --port2 993 --ssl2 \
  --user2 'info@rxf-sys.de' --passfile2 /root/migration/pw_local \
  --automap --useheader 'Message-ID' --useheader 'Date' --skipsize \
  --logdir /root/migration/logs --logfile info-delta-$(date +%F-%H%M).log
```

Solange laufen lassen, bis zwei Läufe hintereinander „0 transferred" melden.

---

## 5. Mail-Clients umstellen

| Einstellung | Im LAN | Von außen |
|-------------|--------|-----------|
| IMAP-Server | `192.168.2.215` | `mail.rxf-sys.de` |
| IMAP-Port | 993, SSL/TLS | 993, SSL/TLS |
| SMTP-Server | `192.168.2.215` | `mail.rxf-sys.de` |
| SMTP-Port | 465, SSL/TLS | 465, SSL/TLS |
| Benutzername | vollständige Mailadresse | vollständige Mailadresse |
| Authentifizierung | Passwort (normal), innerhalb TLS | dito |

> **Ein Client-Profil, nicht zwei.** Wenn du im LAN die IP und von außen den
> Namen einträgst, brauchst du zwei Profile pro Gerät. Besser: überall
> `mail.rxf-sys.de` verwenden und im Router oder auf dem Host einen internen
> DNS-Eintrag setzen, der `mail.rxf-sys.de` im LAN auf 192.168.2.215 auflöst
> (Split-Horizon-DNS). Dann funktioniert dasselbe Profil überall, und das
> Zertifikat passt in beiden Fällen.
>
> Am Router: lokaler DNS-Override `mail.rxf-sys.de → 192.168.2.215`.
> Auf dem PVE-Host reicht der Eintrag in `/etc/hosts` (siehe
> [../03-netzwerk/README.md](../03-netzwerk/README.md#dns)) — der gilt aber nur
> für den Host selbst.

Passwörter für die Postfächer aus Vaultwarden (CT 102) generieren, nicht selbst
erfinden. Wenn der Passthrough aus
[03-vps-relay.md](03-vps-relay.md#6-mail-clients-von-außen-optional) aktiv ist,
sind diese Passwörter das Einzige zwischen dem Internet und deinem Postfach.

---

## 6. Was **nicht** mitkommt

| Was | Warum | Was zu tun ist |
|-----|-------|----------------|
| **Filterregeln** aus dem Strato-Webmail | serverseitig proprietär | von Hand als Sieve-Regeln in CT 112 nachbauen (ManageSieve, Port 4190, z. B. mit Thunderbirds Sieve-Add-on) |
| **Abwesenheitsnotiz** | dito | als Sieve `vacation`-Regel |
| **Kontakte und Kalender** | CardDAV/CalDAV, nicht IMAP | Bei Strato exportieren (vCard/ICS). docker-mailserver kann **kein** CalDAV — entweder Radicale als zusätzlicher Container, oder Mailcow statt docker-mailserver ([01-architektur.md](01-architektur.md#wahl-des-mailstacks)). |
| **Weiterleitungen** und Aliase | Strato-Konfiguration | in CT 112 als `setup alias add` neu anlegen |
| **Gelesen/Ungelesen, Flags** | kommt mit imapsync mit | — |
| **Ordnerstruktur** | kommt mit, siehe `--automap` | Mapping prüfen |

---

## 7. Strato: kündigen oder behalten?

**Nicht am Cutover-Tag kündigen.** Mindestens 4 Wochen Parallelbetrieb:

- Das Strato-Postfach ist dein Rollback-Ziel
  ([07-rollback.md](07-rollback.md)).
- Der Strato-SMTP hält die PVE-/PBS-Notifications am Leben
  ([06-betrieb.md](06-betrieb.md#infra-alerts-nicht-über-den-eigenen-mailserver)).

Nach 4 Wochen ohne Auffälligkeiten:

- [ ] Alle Postfächer vollständig migriert, zwei Delta-Läufe mit „0 transferred"
- [ ] DMARC-Reports zeigen keinen legitimen Versand mehr über Strato
- [ ] Ersatz für Infra-Alerts steht (oder kleinster Strato-Tarif bleibt)
- [ ] `include:_spf.strato.de` aus dem SPF entfernt — **nur** wenn wirklich
      nichts mehr über Strato sendet
- [ ] Strato-Zugangsdaten in Vaultwarden archiviert, nicht gelöscht
- [ ] Domain-Registrierung bleibt bei Strato (davon unabhängig) — **nicht
      versehentlich mitkündigen!**

> Der letzte Punkt ist der teuerste Fehler in diesem Dokument: Wenn `rxf-sys.de`
> bei Strato registriert ist und du das falsche Paket kündigst, verlierst du
> die Domain und damit alle 12 Tunnel-Hostnames, die Zertifikate und die
> Mailadressen. Im Kundenbereich genau nachsehen, welcher Vertrag der
> Mail-Vertrag ist.

Nach dem Löschen des Strato-Postfachs auch die Migrationsdateien aufräumen:

```bash
pct exec 112 -- shred -u /root/migration/pw_strato /root/migration/pw_local
pct exec 112 -- rm -rf /root/migration/logs
```
