# 06 — Betrieb: Backup, Monitoring, Reputation, Wartung

Ein Mailserver ist nach dem Aufbau nicht fertig, sondern angefangen. Dieser
Teil entscheidet, ob das Projekt in einem Jahr noch läuft.

---

## Backup

### Was schon abgedeckt ist

CT 112 liegt auf `local-lvm` und wird damit vom nächtlichen vzdump-Job (02:00 →
PBS) mitgenommen, sobald der Container existiert — der Job sichert alle Guests
außer den ausgeschlossenen. Das umfasst Maildirs, DKIM-Key, Konfiguration und
Dovecot-Indizes.

```bash
# Nach dem ersten Backup verifizieren
qm guest exec 201 -- proxmox-backup-client snapshot list --repository \
  'root@pam!pve-host@192.168.2.209:backups' | grep 112

# Oder im PVE-UI: Datacenter → Backup → Job → letzter Lauf
grep -E '112|mailserver' /var/log/pve/tasks/index | tail -5
```

Maildir ist crash-sicher (eine Datei pro Mail, atomare Umbenennung), ein
LVM-Thin-Snapshot im laufenden Betrieb ist deshalb konsistent genug. Kein
Herunterfahren nötig.

### Was fehlt

| Lücke | Warum es bei Mail mehr wehtut | Maßnahme |
|-------|-------------------------------|----------|
| **Kein Off-site-Backup.** Der PBS-Datastore liegt auf der sdb im selben Gehäuse ([../04-storage/README.md](../04-storage/README.md#storage-sicherung)) | Wohnungsbrand oder Diebstahl = alle Mails weg, und anders als bei Jellyfin gibt es kein „nochmal herunterladen" | wöchentlich verschlüsselt nach außen, siehe unten |
| **DKIM-Key nur im Backup** | Ohne den Key kannst du nach einem Restore nicht signieren, bis der neue Public Key propagiert ist | Key zusätzlich in Vaultwarden (CT 102) ablegen |
| **VPS ist nicht im Backup** | Konfiguration ist überschaubar, aber Neuaufbau kostet einen Abend | `/etc/postfix`, `/etc/wireguard`, `/etc/nginx` in das Host-Config-Backup mitnehmen |

Off-site-Kopie der Maildirs, unabhängig vom PBS:

```bash
# In CT 112, wöchentlich
apt install -y restic
# Ziel: NAS (CT 100) und/oder externe Platte, verschlüsselt
restic -r /srv/mailbackup init
restic -r /srv/mailbackup backup /opt/dms/docker-data/dms/mail-data \
       /opt/dms/docker-data/dms/config
restic -r /srv/mailbackup forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
```

Das Restic-Passwort **nicht** nur in CT 112 ablegen — sonst ist das Backup nach
einem Totalverlust unlesbar. In Vaultwarden und auf Papier.

VPS-Configs in die bestehende Host-Config-Backup-Kette
([../06-backup/host-config-backup.md](../06-backup/host-config-backup.md))
aufnehmen — per `scp` vom VPS in ein Verzeichnis, das
`backup-host-config.sh` einsammelt.

### Restore testen

Ein ungetesteter Restore ist kein Backup. Einmal durchspielen:

```bash
# In eine neue VMID restaurieren, NICHT über CT 112 drüber
pct restore 912 <PBS-Snapshot> --storage local-lvm
# IP im restaurierten CT ändern, damit kein Konflikt entsteht
pct set 912 --net0 name=eth0,bridge=vmbr0,ip=192.168.2.240/24,gw=192.168.2.1
pct start 912
# Postfach öffnen, Mails zählen, dann wieder wegwerfen
pct destroy 912
```

> **Vorher Maßnahme 7 aus dem Audit erledigen:**
> `proxmox-backup-restore-image` ist laut
> [../09-wartung/audit-2026-08-05.md](../09-wartung/audit-2026-08-05.md#zu-punkt-7--file-level-restore)
> defekt, damit ist der Datei-Restore aus PBS kaputt. Für einen Mailserver ist
> „eine einzelne Mail zurückholen" der häufigste Restore-Fall überhaupt.

---

## Monitoring

### Uptime Kuma (CT 103)

Neue Monitore in `http://192.168.2.204:3001`:

| Monitor | Typ | Ziel | Intervall | Warum |
|---------|-----|------|-----------|-------|
| Mail SMTP extern | TCP Port | `mail.rxf-sys.de:25` | 5 min | Prüft VPS + Postfix. Fällt das aus, kommt keine Mail an. |
| Mail IMAPS intern | TCP Port | `192.168.2.215:993` | 5 min | Prüft CT 112 |
| Mail Submission | TCP Port | `192.168.2.215:465` | 5 min | Senden möglich? |
| WireGuard-Strecke | Ping | `10.9.0.1` (aus CT 112 heraus) | 5 min | Der Tunnel ist die stillste Fehlerquelle |
| Zertifikat CT 112 | HTTP(S) mit Cert-Expiry | `https://mail.rxf-sys.de` bzw. TCP+TLS | täglich | 90-Tage-Zertifikate, Warnung bei < 21 Tagen |
| Zertifikat VPS | dito | VPS-Endpunkt | täglich | eigenes Zertifikat, eigener Ablauf |
| Mail-Roundtrip | Push | Skript, siehe unten | 30 min | Der einzige Monitor, der die **Kette** prüft |

Der Roundtrip-Monitor ist der wichtige. Alle anderen sagen nur „Port offen".

### Roundtrip-Prüfung

Idee: alle 30 Minuten eine Mail an eine externe Adresse senden, die
automatisch an eine eigene Adresse zurückgeleitet wird. Kommt sie an,
Kuma-Push-URL aufrufen. Kommt sie nicht an, schlägt der Push-Monitor fehl —
und Kuma alarmiert über einen **anderen** Kanal als Mail (Telegram, ntfy,
Gotify).

```bash
# In CT 112: /usr/local/sbin/mail-roundtrip.sh (Skizze)
#!/bin/bash
set -euo pipefail
TOKEN=$(date +%s)
swaks --to loopback-test@example.com --from monitor@rxf-sys.de \
      --server localhost:25 --header "Subject: roundtrip $TOKEN" --body "$TOKEN"
sleep 300
# Postfach nach $TOKEN durchsuchen
if grep -rq "$TOKEN" /var/mail/rxf-sys.de/monitor/new/ 2>/dev/null; then
  curl -fsS "http://192.168.2.204:3001/api/push/<PUSH_TOKEN>?status=up&msg=ok"
fi
```

> Der Alarmkanal darf **nicht** Mail sein. Ein Mailserver, der seinen eigenen
> Ausfall per Mail meldet, meldet nichts.

### DMARC-Reports lesen

In den ersten zwei Wochen wöchentlich, danach monatlich. Du suchst nach:

- Versand über IPs, die nicht dein VPS sind → jemand nutzt deine Domain, oder
  ein Gerät sendet noch über Strato
- `dkim=fail` bei eigenen Mails → Selector oder Key falsch
- `spf=fail` bei eigenen Mails → SPF-Record unvollständig

Erst wenn zwei Wochen lang nur die VPS-IP auftaucht, ist `p=reject`
verantwortbar ([04-dns.md](04-dns.md#6-dmarc)).

### Postmaster-Programme

Kostenlos, liefern Daten, die du sonst nicht bekommst:

| Anbieter | Werkzeug | Was es zeigt |
|----------|----------|--------------|
| Google | [Postmaster Tools](https://postmaster.google.com) | Spam-Rate, Reputation, TLS-Quote für Gmail-Empfänger |
| Microsoft | SNDS + JMRP | Zustellprobleme bei Outlook/Hotmail, Beschwerde-Feedback |

Beide brauchen eine Domain-Verifizierung per DNS-TXT. Einmal einrichten, danach
ist das die erste Stelle zum Nachsehen, wenn „meine Mails kommen nicht an".

---

## Infra-Alerts: nicht über den eigenen Mailserver

Die PVE- und PBS-Notifications bleiben auf dem externen SMTP-Endpoint
`strato` ([../07-monitoring/notifications.md](../07-monitoring/notifications.md)).

Begründung, damit sie nicht später „aufgeräumt" wird: Läuft der Alert-Weg über
CT 112, dann bekommst du bei einem Ausfall von CT 112, des WireGuard-Tunnels
oder des VPS **keine Meldung darüber**. Genau diese Klasse von stillem Ausfall
hat im Juli 2026 fünf Backup-Nächte gekostet
([../09-wartung/audit-2026-08-05.md](../09-wartung/audit-2026-08-05.md#3-backup-ausfall-12–16-juli-2026)).

Wenn Strato ganz weg soll, vorher einen Ersatz einrichten:

| Option | Kosten | Anmerkung |
|--------|--------|-----------|
| Kleinster Strato-Mailtarif behalten | 1–3 €/Monat | einfachste Lösung, nichts zu ändern |
| Transaktions-SMTP (Brevo, Mailjet, Postmark) | kostenlos im kleinen Volumen | eigener Endpoint, unabhängige Infrastruktur |
| Gmail-Konto mit App-Passwort | 0 € | funktioniert, aber Google mag automatisierte Absender nicht dauerhaft |
| Kuma-Alarm über ntfy/Telegram statt Mail | 0 € | **empfehlenswert als Ergänzung** — ein Kanal, der ganz ohne Mail funktioniert |

Am robustesten: Infra-Alerts doppelt — externer SMTP **und** ein
Push-Kanal (ntfy/Telegram). Dann ist keine einzelne Komponente
alarmierungskritisch.

---

## Zustelltests

Nach dem Cutover und danach quartalsweise:

```bash
# 1. mail-tester.com: Adresse dort abholen, Mail hinschicken, Score ansehen
docker exec mailserver swaks --to test-XXXXX@srv1.mail-tester.com \
  --from info@rxf-sys.de --server localhost:25
# Ziel: 10/10. Unter 8 nachbessern.

# 2. Gmail-Header selbst prüfen
# Mail an ein Gmail-Konto senden, dort "Original anzeigen":
#   spf=pass    header.from=rxf-sys.de
#   dkim=pass   header.d=rxf-sys.de
#   dmarc=pass  header.from=rxf-sys.de

# 3. Konfigurationsprüfer
#   https://internet.nl/mail/rxf-sys.de/
#   https://mxtoolbox.com/domain/rxf-sys.de/
#   dig-Kontrollen aus 04-dns.md Abschnitt 9
```

### Blocklist-Checks

Monatlich, und bei jedem Zustellproblem als Erstes:

```bash
IP=<VPS-IPv4>
REV=$(echo $IP | awk -F. '{print $4"."$3"."$2"."$1}')
for bl in zen.spamhaus.org bl.spamcop.net b.barracudacentral.org \
          dnsbl.sorbs.net psbl.surriel.com; do
  printf '%-30s ' "$bl"
  r=$(dig +short "$REV.$bl" @127.0.0.1)
  [ -z "$r" ] && echo "ok" || echo "GELISTET: $r"
done
```

Bei einer Listung: Grund ermitteln (fast immer ein kompromittiertes Postfach
oder ein Weiterleitungsloop), abstellen, dann beim Betreiber Delisting
beantragen. Nicht vorher — sonst wird die Listung dauerhaft.

### Reputation aufbauen

Eine neue IP hat keine Historie. Google und Microsoft behandeln plötzlichen
Versand von unbekannten IPs skeptisch:

- Nicht am ersten Tag 500 Mails versenden.
- Ganz normal Mail schreiben; nach 2–3 Wochen regulärer Nutzung ist die
  Reputation etabliert.
- Newsletter oder Massenversand über die eigene IP: lassen. Dafür gibt es
  Transaktionsdienste.

---

## Wartung

Ergänzung zu [../09-wartung/checklisten.md](../09-wartung/checklisten.md):

### Wöchentlich

```bash
# Queue leer? Alles über ein paar Stunden ist ein Problem
pct exec 112 -- docker exec mailserver postqueue -p | tail -1
ssh root@<VPS> 'postqueue -p | tail -1'

# Abgewiesene und aufgeschobene Mail
pct exec 112 -- grep -cE 'status=(bounced|deferred)' \
  /opt/dms/docker-data/dms/mail-logs/mail.log
```

### Monatlich

- Updates: `pct exec 112 -- apt update && apt -y dist-upgrade`, dazu
  `docker compose pull && docker compose up -d` in `/opt/dms`
- VPS: `apt update && apt -y full-upgrade` (unattended-upgrades läuft, Reboots
  prüfen)
- Blocklist-Check (oben)
- Zertifikatsablauf beider Hosts kontrollieren
- Backup-Restore-Stichprobe: eine einzelne Mail aus PBS zurückholen

### Bei jeder neuen Mailadresse — beide Seiten

Das ist die Stelle, die im Alltag garantiert vergessen wird:

```bash
# 1. Postfach in CT 112
pct exec 112 -- docker exec -it mailserver setup email add neu@rxf-sys.de

# 2. UND auf dem VPS in relay_recipients eintragen, sonst weist der Relay ab
ssh root@<VPS> "echo 'neu@rxf-sys.de   OK' >> /etc/postfix/relay_recipients \
  && postmap /etc/postfix/relay_recipients && systemctl reload postfix"
```

> Wer Schritt 2 vergisst, bekommt „Relay access denied" — und sucht den Fehler
> auf dem falschen Server. Alternativ die Liste per LDAP/Skript
> synchronisieren, aber für eine Handvoll Adressen ist die Checkliste
> günstiger als die Automatisierung.

### Halbjährlich

- Postfach-Passwörter rotieren (aus Vaultwarden), besonders wenn der
  Passthrough aus [03-vps-relay.md](03-vps-relay.md#6-mail-clients-von-außen-optional)
  aktiv ist
- DKIM-Key rotieren: neuen Selector (`mail2`) anlegen, DNS-Record setzen,
  Propagierung abwarten, dann umschalten, alten Selector eine Woche später
  entfernen
- WireGuard-Keys rotieren
- `doc-audit.sh` laufen lassen und die Mail-Doku gegen den Ist-Zustand prüfen
