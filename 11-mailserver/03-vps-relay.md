# 03 — VPS-Relay

Der VPS ist ein **Briefkasten ohne Lager**: er nimmt Mail aus dem Internet an,
schiebt sie durch WireGuard nach CT 112 und speichert selbst nichts. Umgekehrt
verlässt ausgehende Mail von CT 112 das Netz über die IP des VPS — die eine IP
mit sauberem PTR.

---

## 1. Bestellen — in dieser Reihenfolge

**Vor** allem anderen die zwei Killerkriterien klären, sonst ist der VPS
nutzlos:

1. **Port 25 ausgehend.** Bei vielen Hostern (Hetzner, DigitalOcean, Oracle,
   AWS) für neue Accounts gesperrt. Support-Ticket schreiben, Zweck angeben
   („persönlicher Mailserver für eine eigene Domain"), Freischaltung abwarten.
   Kann Tage dauern, kann abgelehnt werden.
2. **rDNS/PTR selbst setzbar.** Im Kundenportal prüfen, dass du das Feld
   bearbeiten kannst.

Erst wenn beides bestätigt ist, weitermachen.

Danach sofort die zugewiesene IP prüfen — bevor du irgendetwas aufbaust:

```bash
# Auf dem VPS
curl -4 -s https://ifconfig.co
curl -6 -s https://ifconfig.co

# Vorbelastung prüfen (IP-Oktette umgedreht), NICHT über 8.8.8.8/1.1.1.1
dig +short 45.113.0.203.zen.spamhaus.org      # Beispiel: IP 203.0.113.45
dig +short 45.113.0.203.bl.spamcop.net
dig +short 45.113.0.203.b.barracudacentral.org
```

Leere Antworten = ungelistet = gut. Bei einer Listung die IP tauschen (bei den
meisten Hostern kostenlos möglich) oder den VPS neu bestellen. **Eine
vorbelastete IP kostet dich Wochen Reputationsarbeit** — und das merkst du erst
nach der DNS-Umstellung.

**Sizing:** 1 vCPU / 2 GB / 20 GB reicht. Der VPS speichert keine Mail, braucht
aber Platz für die Postfix-Queue, falls CT 112 mal offline ist (dort stapelt
sich dann alles, was reinkommt).

---

## 2. Grundhärtung

```bash
apt update && apt -y full-upgrade
apt install -y ufw fail2ban unattended-upgrades chrony

# SSH: Keys statt Passwörter
# /etc/ssh/sshd_config.d/99-hardening.conf
cat >/etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
systemctl restart ssh          # vorher! sicherstellen, dass der Key funktioniert

hostnamectl set-hostname mail.rxf-sys.de
cat >>/etc/hosts <<'EOF'
127.0.1.1   mail.rxf-sys.de mail
EOF
hostname -f    # muss "mail.rxf-sys.de" liefern
```

Firewall:

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp        comment 'SSH'
ufw allow 25/tcp        comment 'SMTP inbound MX'
ufw allow 80/tcp        comment 'ACME HTTP-01 + mta-sts'
ufw allow 443/tcp       comment 'mta-sts'
ufw allow 51820/udp     comment 'WireGuard'
ufw allow 465/tcp       comment 'Submission passthrough'   # nur wenn Abschnitt 6
ufw allow 993/tcp       comment 'IMAPS passthrough'        # nur wenn Abschnitt 6
ufw enable
ufw status verbose
```

---

## 3. PTR und eigener Resolver

### PTR setzen

Im Kundenportal des Hosters, für IPv4 **und** IPv6 (falls vorhanden):

```
<VPS-IPv4>  →  mail.rxf-sys.de
<VPS-IPv6>  →  mail.rxf-sys.de
```

Kontrolle — Vorwärts und Rückwärts müssen zusammenpassen (FCrDNS):

```bash
dig +short -x <VPS-IPv4>          # → mail.rxf-sys.de.
dig +short A mail.rxf-sys.de      # → <VPS-IPv4>
dig +short -x <VPS-IPv6>          # → mail.rxf-sys.de.
dig +short AAAA mail.rxf-sys.de   # → <VPS-IPv6>
```

> Der A-Record kommt aus [04-dns.md](04-dns.md) und muss auf **DNS only /
> grauer Wolke** stehen. Wenn Cloudflare proxyt, löst `mail.rxf-sys.de` auf
> Cloudflare-IPs auf, der PTR passt nicht mehr, und der MX ist kaputt.

### IPv6

Wenn der VPS IPv6 hat, sendet Postfix bevorzugt darüber. Dann müssen
IPv6-PTR **und** IPv6 im SPF stimmen — sonst weist Google Mail über IPv6
strenger ab als über IPv4. Zwei saubere Wege:

```bash
# Weg 1 (empfohlen, wenn PTRv6 gesetzt ist): beides nutzen
postconf -e 'inet_protocols = all'

# Weg 2 (wenn IPv6-PTR nicht setzbar): IPv6 für Mail abschalten
postconf -e 'inet_protocols = ipv4'
```

Halbe Sachen — IPv6 aktiv, aber ohne PTR — sind die schlechteste Variante.

### Eigener Resolver

Spamhaus und andere RBLs blocken Anfragen über öffentliche Resolver
(8.8.8.8, 1.1.1.1). Ohne eigenen Resolver liefern die RBL-Prüfungen still
falsche Ergebnisse:

```bash
apt install -y unbound
systemctl enable --now unbound

# Postfix/System auf den lokalen Resolver zeigen lassen
# (Anbieter-spezifisch: cloud-init / netplan / resolvconf beachten)
echo 'nameserver 127.0.0.1' > /etc/resolv.conf
dig +short google.com @127.0.0.1
```

---

## 4. WireGuard (VPS-Seite)

```bash
apt install -y wireguard-tools
umask 077
wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
cat /etc/wireguard/public.key      # → in die CT-112-Config eintragen

cat >/etc/wireguard/wg0.conf <<'EOF'
[Interface]
Address = 10.9.0.1/24
ListenPort = 51820
PrivateKey = <VPS_PRIVATE_KEY>

[Peer]
# CT 112 mailserver
PublicKey = <CT112_PUBLIC_KEY>
AllowedIPs = 10.9.0.2/32
EOF
chmod 600 /etc/wireguard/wg0.conf

systemctl enable --now wg-quick@wg0
wg show
```

Der VPS gibt **keinen** `Endpoint` für den Peer an — CT 112 baut auf, der VPS
lernt die Adresse aus dem ersten Handshake. Genau deshalb braucht CT 112
`PersistentKeepalive`.

Nach dem Start von CT 112:

```bash
ping -c3 10.9.0.2
nc -zv 10.9.0.2 25
```

Kein IP-Forwarding aktivieren. Der VPS ist kein Router, er ist ein Mail-Relay —
`net.ipv4.ip_forward` bleibt aus.

---

## 5. Postfix als Relay

```bash
DEBIAN_FRONTEND=noninteractive apt install -y postfix postfix-pcre
# Auswahl: "No configuration" oder "Internet Site" – wird unten überschrieben
```

`/etc/postfix/main.cf`:

```ini
myhostname = mail.rxf-sys.de
mydomain = rxf-sys.de
myorigin = $mydomain

# Nichts lokal zustellen — hier wohnt kein Postfach
mydestination =
local_transport = error:5.1.1 local delivery disabled
local_recipient_maps =
alias_maps =

inet_interfaces = all
inet_protocols = all              # oder ipv4, siehe IPv6-Abschnitt

# --- Eingang: nur für die eigene Domain relayen ---
relay_domains = rxf-sys.de
transport_maps = hash:/etc/postfix/transport
relay_recipient_maps = hash:/etc/postfix/relay_recipients

# --- Ausgang: der Heimserver darf über uns senden ---
mynetworks = 127.0.0.0/8 [::1]/128 10.9.0.0/24

smtpd_helo_required = yes
smtpd_recipient_restrictions =
    permit_mynetworks,
    reject_unauth_destination,
    reject_non_fqdn_recipient,
    reject_invalid_helo_hostname,
    reject_non_fqdn_helo_hostname,
    reject_unknown_reverse_client_hostname,
    reject_rbl_client zen.spamhaus.org,
    reject_rbl_client b.barracudacentral.org

# --- TLS ---
smtpd_tls_cert_file = /etc/letsencrypt/live/mail.rxf-sys.de/fullchain.pem
smtpd_tls_key_file  = /etc/letsencrypt/live/mail.rxf-sys.de/privkey.pem
smtpd_tls_security_level = may
smtpd_tls_loglevel = 1
smtp_tls_security_level = may
smtp_tls_CApath = /etc/ssl/certs

message_size_limit = 52428800     # 50 MB, muss zu CT 112 passen

# Keine Bounces an gefälschte Absender erzeugen
notify_classes = resource, software
```

Die drei Map-Dateien:

```bash
# Wohin mit Mail für rxf-sys.de → durch den Tunnel
cat >/etc/postfix/transport <<'EOF'
rxf-sys.de    smtp:[10.9.0.2]:25
EOF

# Welche Adressen existieren überhaupt — verhindert Backscatter
cat >/etc/postfix/relay_recipients <<'EOF'
info@rxf-sys.de         OK
postmaster@rxf-sys.de   OK
abuse@rxf-sys.de        OK
dmarc@rxf-sys.de        OK
EOF

postmap /etc/postfix/transport
postmap /etc/postfix/relay_recipients
systemctl restart postfix
postfix check && echo "Config ok"
```

> **`relay_recipient_maps` ist keine Kür.** Ohne sie nimmt der VPS Mail für
> jede beliebige Adresse `@rxf-sys.de` an und produziert danach Bounces an
> gefälschte Absender — Backscatter, der dich selbst auf Blocklisten bringt.
> Die Datei muss bei **jeder** neuen Adresse mitgepflegt werden. Eintrag dazu
> in die Wartungscheckliste, siehe [06-betrieb.md](06-betrieb.md#wartung).

### Zertifikat auf dem VPS

Hier funktioniert HTTP-01, weil Port 80 offen ist:

```bash
apt install -y certbot
certbot certonly --standalone -d mail.rxf-sys.de \
  --email info@rxf-sys.de --agree-tos --no-eff-email

cat >/etc/letsencrypt/renewal-hooks/deploy/postfix-reload.sh <<'EOF'
#!/bin/sh
systemctl reload postfix
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/postfix-reload.sh
certbot renew --dry-run
```

Dass CT 112 und VPS zwei getrennte Zertifikate für denselben Namen haben, ist
zulässig und beabsichtigt — der private Schlüssel des einen liegt nie auf dem
anderen.

---

## 6. Mail-Clients von außen (optional)

Damit Handy und Laptop unterwegs Mail abrufen können, ohne VPN, leitet der VPS
993 und 465 unverändert durch. **TLS wird nicht auf dem VPS terminiert** — die
Verbindung endet auf CT 112, das Zertifikat und die Passwörter bleiben zu Hause.

```bash
apt install -y nginx libnginx-mod-stream

cat >/etc/nginx/modules-enabled/60-mail-stream.conf <<'EOF'
stream {
    upstream imaps { server 10.9.0.2:993; }
    upstream subms { server 10.9.0.2:465; }

    server {
        listen 993;
        listen [::]:993;
        proxy_pass imaps;
        proxy_timeout 10m;
    }
    server {
        listen 465;
        listen [::]:465;
        proxy_pass subms;
        proxy_timeout 5m;
    }
}
EOF
nginx -t && systemctl reload nginx
```

> Damit sind IMAP und Submission **aus dem ganzen Internet erreichbar**. Das
> ist der Preis für Komfort. Zwingend dazu: sehr starke Postfach-Passwörter
> (aus Vaultwarden in CT 102, nicht selbst gedacht) und fail2ban aus
> Abschnitt 7.
>
> Sicherere Alternative: **kein** Passthrough, stattdessen WireGuard auf dem
> Handy als zweiter Peer (`10.9.0.3/32`, `AllowedIPs = 10.9.0.0/24` plus
> `192.168.2.215/32`). Dann ist von außen ausschließlich Port 25 offen. Mehr
> Klickarbeit beim Einrichten, deutlich kleinere Angriffsfläche.

Nachteil des Passthrough: CT 112 sieht als Client-IP immer `10.9.0.1`, in den
Dovecot-Logs steht keine echte Adresse mehr. Wenn dich das stört, PROXY-Protokoll
aktivieren (`proxy_protocol on;` in nginx, `haproxy_trusted_networks` in
Dovecot) — nur zusammen umstellen, sonst brechen die Logins.

---

## 7. fail2ban

Hier ist die Angriffsfläche, also hier gehört die Sperre hin.

```bash
cat >/etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
backend = systemd
ignoreip = 127.0.0.1/8 ::1 10.9.0.0/24
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true

[postfix]
enabled = true
mode = aggressive

[postfix-rbl]
enabled = true
EOF

systemctl restart fail2ban
fail2ban-client status
```

Wenn der Passthrough aus Abschnitt 6 läuft, kommt für die IMAP-Logins ein
eigener Jail hinzu — die Fehlversuche loggt aber **CT 112**, nicht der VPS.
Zwei Wege: entweder die Dovecot-Logs per rsyslog an den VPS schicken, oder
fail2ban in CT 112 laufen lassen und dort nur Rate-Limits setzen. Der
pragmatische Kompromiss ist, es beim WireGuard-Peer für mobile Geräte zu
belassen und den Passthrough weglassen.

---

## 8. Ende-zu-Ende-Test **vor** der DNS-Umstellung

Der entscheidende Punkt: alles lässt sich prüfen, während der MX noch bei
Strato steht. Nichts davon berührt den Produktivbetrieb.

### Eingang: Internet → VPS → CT 112

```bash
# Von einem beliebigen dritten Rechner, direkt an die VPS-IP
swaks --to info@rxf-sys.de --from dein.gmail@gmail.com \
      --server <VPS-IPv4> --tls

# Auf dem VPS mitlesen
tail -f /var/log/mail.log | grep -E 'relay=|status='
# Erwartung: relay=10.9.0.2[10.9.0.2]:25, status=sent

# In CT 112 nachsehen
pct exec 112 -- docker exec mailserver ls -la /var/mail/rxf-sys.de/info/new/
```

### Ausgang: CT 112 → VPS → Internet

```bash
# In CT 112
pct exec 112 -- docker exec mailserver \
  swaks --to dein.gmail@gmail.com --from info@rxf-sys.de --server localhost:25

# Auf dem VPS
tail -f /var/log/mail.log | grep -E 'to=<dein.gmail|status='
# Erwartung: status=sent (250 ... OK) von gmail-smtp-in
```

In der Gmail-Nachricht dann *Original anzeigen* und kontrollieren:

| Prüfung | Erwartung an diesem Punkt |
|---------|---------------------------|
| `Received: from mail.rxf-sys.de (<VPS-IP>)` | ja |
| SPF | **fail** — noch normal, SPF-Record kommt in [04-dns.md](04-dns.md) |
| DKIM | **none** — Record fehlt noch |
| Landet die Mail an? | idealerweise ja, wahrscheinlich im Spam |

Wenn Ein- und Ausgang durchlaufen, ist die Technik fertig. **Alles was jetzt
noch fehlt, ist DNS** — und das ist der Schritt, der sichtbar wird.

### Häufige Stolpersteine

| Symptom | Ursache |
|---------|---------|
| `status=deferred (connect to 10.9.0.2: No route to host)` | WireGuard steht nicht oder Keepalive fehlt → `wg show` auf beiden Seiten, `latest handshake` prüfen |
| `Relay access denied` bei eingehender Mail | Adresse fehlt in `relay_recipients` oder `postmap` vergessen |
| Eingehende Mail landet in der VPS-Queue statt im Tunnel | `transport`-Map nicht gemappt (`postmap /etc/postfix/transport`) oder falsche Klammerung — `[10.9.0.2]` mit eckigen Klammern, sonst wird ein MX-Lookup versucht |
| Ausgehend `450 Client host rejected` | RBL-Listung des VPS → Abschnitt 1 |
| `Connection timed out` zu gmail-smtp-in:25 | Port 25 ausgehend beim Hoster noch gesperrt |
