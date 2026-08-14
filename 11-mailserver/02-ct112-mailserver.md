# 02 — CT 112 `mailserver` aufsetzen

Zielzustand: unprivilegierter Debian-13-LXC auf 192.168.2.215 mit
docker-mailserver, gültigem Let's-Encrypt-Zertifikat für `mail.rxf-sys.de` und
WireGuard-Verbindung zum VPS.

> Reihenfolge: Der VPS aus [03-vps-relay.md](03-vps-relay.md) muss noch nicht
> stehen, aber die WireGuard-Schritte hier setzen die dort erzeugten Keys
> voraus. Praktikabel ist: VPS bestellen → hier Abschnitte 1–5 → dort
> Abschnitte 1–7 → hier Abschnitt 6 (WireGuard) → Ende-zu-Ende-Test.

---

## 1. Vorbedingungen abhaken

- [ ] 2 GB RAM freigeräumt ([01-architektur.md](01-architektur.md#ressourcenbudget))
- [ ] VMID 112 und IP 192.168.2.215 frei ([00-machbarkeit.md](00-machbarkeit.md#4-passt-es-auf-den-server))
- [ ] Cloudflare-API-Token mit `Zone → DNS → Edit` für `rxf-sys.de` erzeugt
      (das bestehende Dashboard-Token aus
      [../03-netzwerk/cloudflare-tunnel.md](../03-netzwerk/cloudflare-tunnel.md)
      hat nur `DNS: Read` — **neues, eigenes Token anlegen**, nicht das alte
      erweitern)
- [ ] Debian-13-Template vorhanden

```bash
pveam update
pveam available --section system | grep debian-13
pveam download local debian-13-standard_13.x-x_amd64.tar.zst   # exakte Version aus obiger Liste
```

---

## 2. Container anlegen

Folgt den gemeinsamen Eigenschaften aus
[../05-container/README.md](../05-container/README.md): `unprivileged`,
`nesting=1`, `keyctl=1` (für Docker), `onboot=1`, `firewall=1`.

```bash
pct create 112 local:vztmpl/debian-13-standard_13.x-x_amd64.tar.zst \
  --hostname mailserver \
  --cores 2 \
  --memory 2048 \
  --swap 512 \
  --rootfs local-lvm:32 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,ip=192.168.2.215/24,gw=192.168.2.1 \
  --nameserver 192.168.2.1 \
  --unprivileged 1 \
  --features nesting=1,keyctl=1 \
  --onboot 1 \
  --startup order=3 \
  --tags mail \
  --password

pct start 112
pct exec 112 -- bash -c 'apt update && apt -y dist-upgrade'
```

`startup order=3` sorgt dafür, dass der Mailserver nach der PBS-VM
(`order=1`) hochkommt und nicht mit ihr um I/O konkurriert.

### Disk über 20 GB

Falls die Postfachsumme aus
[00-machbarkeit.md](00-machbarkeit.md#3-was-liegt-bei-strato) über ~20 GB liegt,
wird ein 32-GB-rootfs zu klein. Zwei Optionen:

1. **rootfs größer** — z. B. `--rootfs local-lvm:64`. Bevorzugt, weil damit
   alles in der vzdump/PBS-Kette bleibt. Der Thin-Pool hat Platz (337 GB,
   ~18 % belegt). Nachträglich: `pct resize 112 rootfs +32G`.
2. **Bind-Mount auf `/mnt/storage/mail`** — nur mit **eigenem Backup**.
   `/mnt/storage` ist ausdrücklich **nicht** in der Backup-Kette
   ([../04-storage/README.md](../04-storage/README.md#storage-sicherung)).
   Postfächer auf ungesichertem Storage sind keine Option; wenn Bind-Mount,
   dann zwingend mit dem zusätzlichen Job aus
   [06-betrieb.md](06-betrieb.md#backup).

> Option 1 ist die richtige Wahl, solange der Thin-Pool das trägt.

---

## 3. Docker installieren

Wie in CT 101/102/103/109 etabliert:

```bash
pct enter 112

apt install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  > /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
docker run --rm hello-world
```

Setze außerdem den FQDN korrekt — docker-mailserver leitet daraus `myhostname`
und den Zertifikatspfad ab:

```bash
hostnamectl set-hostname mail
cat >/etc/hosts <<'EOF'
127.0.0.1       localhost
127.0.1.1       mail.rxf-sys.de mail
192.168.2.215   mail.rxf-sys.de mail
EOF
hostname -f     # muss "mail.rxf-sys.de" liefern
```

---

## 4. Zertifikat via DNS-01

**HTTP-01 funktioniert hier nicht** — Port 80 ist von außen nicht erreichbar
(kein Port-Forwarding). Also DNS-01 über die Cloudflare-API.

```bash
apt install -y certbot python3-certbot-dns-cloudflare

install -d -m 700 /root/.secrets
cat >/root/.secrets/cloudflare.ini <<'EOF'
dns_cloudflare_api_token = DEIN_NEUES_TOKEN_MIT_DNS_EDIT
EOF
chmod 600 /root/.secrets/cloudflare.ini

certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /root/.secrets/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d mail.rxf-sys.de \
  -d autoconfig.rxf-sys.de \
  --email info@rxf-sys.de --agree-tos --no-eff-email

ls -l /etc/letsencrypt/live/mail.rxf-sys.de/
```

Erneuerung läuft über den mitgelieferten `certbot.timer`. Reload-Hook, damit
Postfix/Dovecot das neue Zertifikat auch ziehen:

```bash
cat >/etc/letsencrypt/renewal-hooks/deploy/dms-reload.sh <<'EOF'
#!/bin/sh
docker exec mailserver /usr/bin/supervisorctl restart postfix dovecot 2>/dev/null || \
  docker restart mailserver
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/dms-reload.sh

systemctl list-timers certbot.timer
certbot renew --dry-run
```

> docker-mailserver erkennt Zertifikatswechsel im gemounteten
> `/etc/letsencrypt` normalerweise selbst und lädt neu. Der Hook ist die
> Absicherung dagegen, dass genau das nach einem Update nicht mehr greift und
> du es erst 90 Tage später merkst.

**Zertifikatsablauf gehört in Uptime Kuma** — siehe
[06-betrieb.md](06-betrieb.md#monitoring).

---

## 5. docker-mailserver

```bash
install -d /opt/dms
cd /opt/dms
curl -fsSL -o compose.yaml \
  https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/compose.yaml
curl -fsSL -o mailserver.env \
  https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/mailserver.env
```

`compose.yaml` anpassen — Hostname, Volumes, Zertifikate:

```yaml
services:
  mailserver:
    image: ghcr.io/docker-mailserver/docker-mailserver:latest
    container_name: mailserver
    hostname: mail.rxf-sys.de
    env_file: mailserver.env
    restart: always
    stop_grace_period: 1m
    ports:
      - "25:25"      # nur vom VPS über WireGuard erreichbar (Guest-FW!)
      - "465:465"    # Submission implicit TLS
      - "587:587"    # Submission STARTTLS
      - "993:993"    # IMAPS
      - "4190:4190"  # ManageSieve
    volumes:
      - ./docker-data/dms/mail-data/:/var/mail/
      - ./docker-data/dms/mail-state/:/var/mail-state/
      - ./docker-data/dms/mail-logs/:/var/log/mail/
      - ./docker-data/dms/config/:/tmp/docker-mailserver/
      - /etc/letsencrypt:/etc/letsencrypt:ro
      - /etc/localtime:/etc/localtime:ro
    healthcheck:
      test: "ss --listening --tcp | grep -P 'LISTEN.+:smtp' || exit 1"
      timeout: 3s
      retries: 0
```

Wichtige Werte in `mailserver.env`:

```ini
# --- Grundlagen ---
OVERRIDE_HOSTNAME=mail.rxf-sys.de
POSTMASTER_ADDRESS=postmaster@rxf-sys.de
SSL_TYPE=letsencrypt
LOG_LEVEL=info

# --- Filterung ---
ENABLE_RSPAMD=1
ENABLE_OPENDKIM=0          # DKIM signiert Rspamd
ENABLE_OPENDMARC=0         # DMARC prüft Rspamd
ENABLE_AMAVIS=0
ENABLE_SPAMASSASSIN=0
ENABLE_CLAMAV=0            # bewusst aus: 1-2 GB RAM, siehe 01-architektur.md
MOVE_SPAM_TO_JUNK=1

# --- Dovecot ---
ENABLE_MANAGESIEVE=1
ENABLE_QUOTAS=1

# --- fail2ban aus: Angriffsfläche liegt auf dem VPS, nicht hier ---
ENABLE_FAIL2BAN=0

# --- Ausgang: alles über den VPS-Relay ---
RELAY_HOST=10.9.0.1
RELAY_PORT=25

# --- Wer darf einliefern/relayen ---
PERMIT_DOCKER=none
```

> **`ENABLE_FAIL2BAN=0` ist eine bewusste Entscheidung.** fail2ban im Container
> im unprivilegierten LXC müsste nftables-Regeln setzen und braucht dafür
> `NET_ADMIN` — in einem unprivileged Guest fragil bis unmöglich. Die
> Brute-Force-Fläche liegt sowieso auf dem VPS (dort ist 993/465 aus dem
> Internet erreichbar), und dort läuft fail2ban richtig, siehe
> [03-vps-relay.md](03-vps-relay.md#7-fail2ban).

Starten und Postfächer anlegen:

```bash
docker compose up -d
docker compose logs -f          # bis "mail systems are up"

# Postfächer (für jede Adresse aus 00-machbarkeit.md)
docker exec -it mailserver setup email add info@rxf-sys.de
docker exec -it mailserver setup email add postmaster@rxf-sys.de
docker exec -it mailserver setup email add dmarc@rxf-sys.de

# Aliase
docker exec -it mailserver setup alias add abuse@rxf-sys.de postmaster@rxf-sys.de

# Kontrolle
docker exec -it mailserver setup email list
docker exec -it mailserver setup alias list
```

> `postmaster@` und `abuse@` sind nicht optional. Manche Provider prüfen deren
> Erreichbarkeit, und Beschwerden landen dort — wenn niemand liest, wird aus
> einem Problem eine Blocklistung.

### DKIM-Key erzeugen

```bash
docker exec -it mailserver setup config dkim help     # Flags der installierten Version prüfen
docker exec -it mailserver setup config dkim keysize 2048 selector mail

# Public Key für den DNS-Record (Rspamd-Pfad; bei OpenDKIM liegt er anders)
find /opt/dms/docker-data/dms/config -name '*.public*' -o -name '*.txt' | head
cat /opt/dms/docker-data/dms/config/rspamd/dkim/mail.public.key
```

Der Inhalt geht als TXT-Record nach `mail._domainkey.rxf-sys.de` — Format und
Fallstricke in [04-dns.md](04-dns.md#4-dkim).

> Die genauen Pfade und Flags von `setup config dkim` haben sich zwischen
> docker-mailserver-Versionen geändert. Im Zweifel `setup config dkim help`
> und die offizielle Doku, nicht dieses Dokument, als Wahrheit nehmen.

### Rspamd: den Relay-Hop überspringen

Weil alle eingehende Mail über den VPS läuft, sieht Rspamd als verbindende IP
immer `10.9.0.1`. Ohne Anpassung sind damit alle IP-basierten Prüfungen (RBL,
SPF) wertlos — sie bewerten deinen eigenen VPS. Rspamd muss den Hop als
vertrauenswürdig kennen, damit es für die IP-Prüfungen einen Received-Header
weiter zurückschaut:

```bash
install -d /opt/dms/docker-data/dms/config/rspamd/override.d
cat >/opt/dms/docker-data/dms/config/rspamd/override.d/options.inc <<'EOF'
local_addrs = "127.0.0.0/8, ::1/128, 10.9.0.0/24";
EOF
docker compose restart
```

Danach an einer echten eingehenden Mail kontrollieren, dass die Prüfungen auf
die **ursprüngliche** Absender-IP zielen und nicht auf 10.9.0.1:

```bash
docker exec mailserver rspamc stat
grep -E 'SPF|DMARC|RBL' /opt/dms/docker-data/dms/mail-logs/mail.log | tail -20
```

**Alternative, falls das nicht sauber läuft:** die Spam-Prüfung auf den VPS
verlagern (Rspamd oder postscreen dort), damit direkt an der SMTP-Verbindung
abgewiesen wird. Das ist ohnehin die sauberere Variante — spart Bandbreite und
erzeugt kein Backscatter — kostet aber RAM auf dem VPS und splittet die
Konfiguration auf zwei Hosts.

---

## 6. WireGuard nach dem VPS

Keys und die VPS-Seite kommen aus
[03-vps-relay.md](03-vps-relay.md#4-wireguard-vps-seite).

```bash
apt install -y wireguard-tools
umask 077
wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
cat /etc/wireguard/public.key      # → in die VPS-Config eintragen

cat >/etc/wireguard/wg0.conf <<'EOF'
[Interface]
Address = 10.9.0.2/24
PrivateKey = <CT112_PRIVATE_KEY>
# kein ListenPort: Verbindung wird immer von hier aufgebaut

[Peer]
PublicKey = <VPS_PUBLIC_KEY>
Endpoint = <VPS_PUBLIC_IP>:51820
AllowedIPs = 10.9.0.0/24
PersistentKeepalive = 25
EOF
chmod 600 /etc/wireguard/wg0.conf

systemctl enable --now wg-quick@wg0
wg show
ping -c3 10.9.0.1
```

`PersistentKeepalive = 25` ist Pflicht, nicht Kosmetik: ohne die Keepalives
schließt das NAT des Routers die Rückrichtung, und der VPS kann eingehende Mail
nicht mehr durchschieben.

### Wenn WireGuard im unprivileged LXC nicht startet

Das Kernel-Modul gehört dem Host. Erst dort laden:

```bash
# auf rxf-sys
modprobe wireguard
echo wireguard > /etc/modules-load.d/wireguard.conf
lsmod | grep wireguard
```

Falls `wg-quick` im CT danach weiter scheitert (`Operation not permitted`),
auf die Userspace-Implementierung wechseln. Die braucht `/dev/net/tun`:

```bash
# auf rxf-sys
pct stop 112
cat >>/etc/pve/lxc/112.conf <<'EOF'
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF
pct start 112

# im CT
apt install -y wireguard-go
WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go systemctl restart wg-quick@wg0
```

Dauerhaft per Drop-in:

```bash
mkdir -p /etc/systemd/system/wg-quick@wg0.service.d
cat >/etc/systemd/system/wg-quick@wg0.service.d/userspace.conf <<'EOF'
[Service]
Environment=WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go
EOF
systemctl daemon-reload && systemctl restart wg-quick@wg0
```

---

## 7. Guest-Firewall `112.fw`

Wichtig: **Port 25 darf nur vom VPS erreichbar sein**, nicht vom LAN und erst
recht nicht offen. Der Regelsatz folgt dem Muster der bestehenden Dateien
([../08-sicherheit/firewall.md](../08-sicherheit/firewall.md)) — und diesmal
mit `[OPTIONS]`-Block, anders als das kaputte `111.fw`.

`/etc/pve/firewall/112.fw` auf dem Host:

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -source +dc/lan -p tcp -dport 22 -log nolog     # SSH aus dem LAN
IN ACCEPT -source +dc/lan -p tcp -dport 465 -log nolog    # Submission implicit TLS
IN ACCEPT -source +dc/lan -p tcp -dport 587 -log nolog    # Submission STARTTLS
IN ACCEPT -source +dc/lan -p tcp -dport 993 -log nolog    # IMAPS
IN ACCEPT -source +dc/lan -p tcp -dport 4190 -log nolog   # ManageSieve
IN ACCEPT -source +dc/lan -p icmp -log nolog
```

Port 25 taucht hier absichtlich **nicht** auf: der VPS liefert über
`wg0` ein, und dieses Interface durchläuft die PVE-Bridge-Firewall nicht — die
filtert nur `net0` auf `vmbr0`. Der Zugang aus dem WireGuard-Netz ist damit
frei, aus dem LAN und dem Internet aber zu.

Prüfen und aktivieren:

```bash
pve-firewall compile | grep -A20 'chain.*112'
pve-firewall restart
pve-firewall status

# Gegenprobe von einem LAN-Rechner
nc -zv 192.168.2.215 993 && echo "IMAPS ok"
nc -zv 192.168.2.215 25  && echo "FEHLER: 25 ist aus dem LAN offen"
```

---

## 8. Lokaler Funktionstest (ohne DNS)

Noch bevor irgendein DNS-Record angefasst wird:

```bash
# Dienste lauschen?
pct exec 112 -- ss -tulpn | grep -E ':(25|465|587|993|4190)'

# TLS und Zertifikatsname
openssl s_client -connect 192.168.2.215:993 -servername mail.rxf-sys.de </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -dates

# IMAP-Login mit einem echten Postfach
openssl s_client -crlf -connect 192.168.2.215:993 </dev/null
# a LOGIN info@rxf-sys.de DEIN_PW
# a LIST "" "*"
# a LOGOUT

# Interne Zustellung
pct exec 112 -- docker exec mailserver \
  swaks --to info@rxf-sys.de --from test@example.com --server localhost:25
pct exec 112 -- docker exec mailserver \
  find /var/mail -name 'new' -type d -exec ls -la {} \;
```

Ein Mailclient im LAN sollte sich jetzt mit `192.168.2.215`, IMAPS 993 und
SMTP 465 verbinden können. **Erst wenn das läuft**, weiter mit
[03-vps-relay.md](03-vps-relay.md).

---

## 9. Nach dem Aufbau dokumentieren

Damit die Doku nicht driftet (der Audit vom 05.08. hat genau davon eine Seite
voll):

- [ ] `05-container/lxc/CT112-mailserver.md` nach dem Muster von
      [CT102-vaultwarden.md](../05-container/lxc/CT102-vaultwarden.md) anlegen
- [ ] Tabellen in [../README.md](../README.md) und
      [../05-container/README.md](../05-container/README.md) ergänzen
      (inkl. neuer RAM-Summe)
- [ ] [../03-netzwerk/README.md](../03-netzwerk/README.md): .215 eintragen,
      IP-Schema auf .200–.215 erweitern
- [ ] [../08-sicherheit/firewall.md](../08-sicherheit/firewall.md) und
      [../03-netzwerk/firewall.md](../03-netzwerk/firewall.md): `112.fw`
      aufnehmen
- [ ] [../CHANGE~1.MD](../CHANGE~1.MD): Eintrag ergänzen
- [ ] `configs/pve/firewall/112.fw` anonymisiert ablegen
- [ ] `scripts/doc-audit.sh`: 112 in die Guest-Listen aufnehmen
