# CT 104 — immich (Neuinstallation)

Anleitung für die Neuanlage von CT 104 mit Immich. Die VMID 104 und die IP
`192.168.2.205` sind seit der Auflösung des alten `docker-host` frei.

> **Konkreter Ablauf für den Restore:** Dieses Dokument erklärt Hintergrund und
> Varianten. Wer die alte Bibliothek zurückholen will, arbeitet stattdessen
> [CT104-immich-install-v2.7.5.md](CT104-immich-install-v2.7.5.md) von oben nach
> unten durch — dort steht derselbe Weg als linearer Ablauf ohne Verzweigungen.

> **Warum genau 104 und .205:** Der Cloudflare Tunnel hat für
> `photos.rxf-sys.de` weiterhin die Origin `http://192.168.2.205:2283`
> eingetragen. Wer die alte VMID und IP wiederverwendet und Immich auf dem
> Standardport 2283 betreibt, bekommt den Public Hostname ohne jede Änderung in
> Cloudflare zurück — und schließt damit Maßnahme 5 aus
> [../../09-wartung/audit-2026-08-05.md](../../09-wartung/audit-2026-08-05.md).

---

## 0. Vor dem Start: ein Befund und zwei Entscheidungen

### 0.1 Befund vom 05.08.2026: die Datenbank ist da

`/mnt/storage/immich` hat die Auflösung von CT 104 überlebt; es lag auf sda1,
nicht im Container. Und Immich hatte seine automatischen DB-Dumps genau dorthin
geschrieben. Der Bestand:

| | |
|---|---|
| **Dumps** | 14 Stück, je ~17 MB gzip (230 MB gesamt) |
| **Neuester** | `immich-db-backup-20260803T020000-v2.7.5-pg14.19.sql.gz` |
| **Immich-Version** | **v2.7.5** |
| **Postgres** | 14.19 |
| **Bibliothek gesamt** | 2,4 GB (davon 230 MB Dumps, also ~2,2 GB Medien) |
| **Eigentümer** | `100000:100000` = root im unprivilegierten CT |

Damit ist die **vollständige Bibliothek wiederherstellbar** — Alben,
Gesichtszuordnungen, Benutzer, Metadaten. Nicht nur die Dateien.

> ### Zuerst die Dumps in Sicherheit bringen
>
> **Vor allem anderen.** Sobald ein neues Immich läuft, greift dessen eigene
> Retention (14 Dumps): Es schreibt um 02:00 einen frischen Dump einer
> womöglich *leeren* Datenbank und löscht dafür den ältesten alten. Nach zwei
> Wochen wäre der Bestand weg — und mit ihm die einzige Kopie der alten
> Datenbank.
>
> ```bash
> mkdir -p /mnt/storage/extra-backups/immich-db-2026-08
> cp -av /mnt/storage/immich/backups/*.sql.gz \
>        /mnt/storage/extra-backups/immich-db-2026-08/
> ls -lah /mnt/storage/extra-backups/immich-db-2026-08/
> ```

### Zeitlicher Verlauf

Die Dumps zeigen, wann Immich lief: durchgehend **5.–16. Juli**, dann eine
Lücke, dann wieder **2. und 3. August**. Die Datei `.immich` trägt den
1. August 16:05 — die Minute des Host-Reboots. CT 104 wurde also erst zwischen
dem **3. und 5. August** entfernt, der Verlust ist frisch.

Die Lücke vom 17. Juli bis 1. August fällt zeitlich in die Nähe des
PBS-Ausfalls vom 12.–16. Juli (siehe
[../../09-wartung/audit-2026-08-05.md](../../09-wartung/audit-2026-08-05.md)).
Ob das zusammenhängt, ist offen — für die Wiederherstellung spielt es keine
Rolle, der Dump vom 3. August ist der jüngste und vollständig.

### 0.2 RAM — reicht das noch?

Der Host hat 31871 MB, zugewiesen sind bereits 28160 MB (88 %). Mit 4 GB für
Immich stünden 32256 MB auf dem Papier — mehr als physisch vorhanden.

Das ist weniger dramatisch, als es klingt, aber man sollte den Unterschied
kennen:

- **LXC-Container** bekommen ein *Limit*, keine Reservierung. Die 11 CTs
  belegen zusammen real deutlich weniger als ihre Summe.
- **VMs reservieren fest.** VM 200 und VM 201 mit je 6 GB blockieren 12 GB hart.

Real belegt der Host aktuell **14 GB von 31 GB**. Für Immich mit 4 GB ist also
Luft da. Zwei Dinge trotzdem im Blick behalten:

- Der Check „RAM nicht überbucht" in `doc-audit.sh` springt danach auf `FAIL`.
  Das ist erwartbar und für LXC-lastige Hosts zu streng — im nächsten
  Audit-Bericht entsprechend einordnen.
- Größter Verbraucher ist **immich-machine-learning** (Gesichtserkennung,
  Smart Search). Wer knapp ist, fährt den Container herunter oder gibt ihm ein
  eigenes, kleineres Limit; Immich läuft auch ohne ML, nur ohne diese Features.

Wenn es enger wird: **VM 201 (PBS) von 6 GB auf 4 GB** ist der naheliegendste
Hebel — die Doku führte die VM lange mit 4 GB, und der Datastore ist mit 31 GB
von 460 GB gut überschaubar.

### 0.3 Wohin mit der Postgres-Datenbank?

Immich trennt zwei Pfade, und die gehören hier **nicht** an denselben Ort:

| Variable | Ort | Warum |
|----------|-----|-------|
| `UPLOAD_LOCATION` | `/srv/immich-data` (Bind-Mount auf `/mnt/storage/immich`) | die Bibliothek, groß, gehört auf sda1 |
| `DB_DATA_LOCATION` | `/opt/immich/postgres` (CT-rootfs auf local-lvm) | Immich unterstützt für die DB **keine Netzwerk-Shares**, und im rootfs landet sie automatisch im nächtlichen vzdump |

Der Haken an der DB im rootfs: vzdump läuft im `snapshot`-Modus und erwischt
Postgres im laufenden Betrieb, der Dump ist also nicht garantiert konsistent.
Deshalb sind Immichs eigene tägliche DB-Dumps nach `UPLOAD_LOCATION/backups`
kein Extra, sondern der eigentliche Rettungsanker — sie haben schon die letzte
Löschung überlebt.

---

## 1. Container anlegen

Auf dem **Host**:

```bash
pct create 104 local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname immich \
  --cores 2 \
  --memory 4096 \
  --swap 512 \
  --rootfs local-lvm:20 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.2.205/24,gw=192.168.2.1,firewall=1 \
  --nameserver 192.168.2.1 \
  --searchdomain home \
  --features nesting=1,keyctl=1 \
  --unprivileged 1 \
  --onboot 1 \
  --tags media \
  --start 1
```

`nesting=1` und `keyctl=1` sind für Docker in einem unprivilegierten Container
zwingend — dieselbe Kombination wie bei CT 101, 102, 103 und 109.

20 GB rootfs reichen für die Images (Server ~1,5 GB, ML ~3 GB), den Model-Cache
und die Postgres-Daten. Der Thin-Pool liegt bei 18 % von 337 GB, Platz ist da.

### Bind-Mount für die Bibliothek

```bash
pct set 104 -mp0 /mnt/storage/immich,mp=/srv/immich-data
```

Zu den Rechten: Das Verzeichnis gehört auf dem Host `101000:101000` (uid 1000
im CT), die darin liegenden Immich-Daten `100000:100000` (root im CT). Beides
passt zum Standard-idmap eines unprivilegierten Containers (Offset 100000) —
solange der neue CT ebenfalls `unprivileged: 1` ist, greifen die alten Daten
ohne `chown`. **Ein privilegierter Container würde hier nicht passen.**

### GPU durchreichen (optional, empfohlen)

Die Intel UHD 630 kann für Video-Transcoding **und** für die ML-Inferenz genutzt
werden. Sie ist bereits an CT 106 (Jellyfin) durchgereicht; mehrere Consumer
sind unproblematisch.

```bash
pct set 104 -dev0 /dev/dri/renderD128,gid=44
pct reboot 104
```

Gleiche Schreibweise wie bei CT 106. Prüfen:

```bash
pct exec 104 -- ls -la /dev/dri/
```

---

## 2. Docker installieren

```bash
pct enter 104
```

Ab hier **im Container**:

```bash
apt update && apt -y full-upgrade
apt -y install ca-certificates curl

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt update
apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

docker run --rm hello-world   # Funktionstest
```

---

## 3. Immich holen

> **Wenn die alte Bibliothek zurück soll** — und laut Abschnitt 0.1 kann sie
> das — hier **nicht** `latest` nehmen, sondern direkt mit **v2.7.5** starten:
> springe zu [Abschnitt 8.1](#81-restore-des-v275-dumps) und komm danach für
> das Upgrade auf v3 zurück. Der Rest dieses Abschnitts gilt für eine
> Installation auf der grünen Wiese.

Immer die Dateien eines **Release** verwenden, nicht die aus `main` — letztere
passen möglicherweise nicht zum veröffentlichten Image.

```bash
mkdir -p /opt/immich && cd /opt/immich

BASE=https://github.com/immich-app/immich/releases/latest/download
curl -fsSL -o docker-compose.yml        $BASE/docker-compose.yml
curl -fsSL -o .env                      $BASE/example.env
curl -fsSL -o hwaccel.transcoding.yml   $BASE/hwaccel.transcoding.yml
curl -fsSL -o hwaccel.ml.yml            $BASE/hwaccel.ml.yml
```

Das Compose-File definiert vier Services:

| Container                 | Image                                              | Port |
|---------------------------|----------------------------------------------------|------|
| `immich_server`           | `ghcr.io/immich-app/immich-server`                 | 2283 |
| `immich_machine_learning` | `ghcr.io/immich-app/immich-machine-learning`       | intern |
| `immich_redis`            | `docker.io/valkey/valkey:9`                        | intern |
| `immich_postgres`         | `ghcr.io/immich-app/postgres:14-vectorchord…`      | intern |

> **Gute Nachricht für den Restore:** Das Postgres-Image ist zwischen v2.7.5
> und dem aktuellen Release **bitgleich** — beide Compose-Dateien verweisen auf
> `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0` mit
> demselben Digest `sha256:bcf63357…`. Es steht also **keine Migration der
> Datenbank-Engine an**; der Dump passt direkt. Nur der Valkey-Digest
> unterscheidet sich, was für die Daten belanglos ist.

---

## 4. Konfiguration

`/opt/immich/.env` anpassen:

```ini
# Bibliothek — Bind-Mount auf /mnt/storage/immich
UPLOAD_LOCATION=/srv/immich-data

# Datenbank — im CT-rootfs, NICHT auf dem Bind-Mount
DB_DATA_LOCATION=/opt/immich/postgres

TZ=Europe/Berlin

IMMICH_VERSION=v3

# Zufälliges Passwort, nur A-Za-z0-9
DB_PASSWORD=<hier ein generiertes Passwort einsetzen>
```

Passwort erzeugen:

```bash
tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32; echo
```

`DB_USERNAME` und `DB_DATABASE_NAME` bleiben auf den Vorgaben.

### GPU aktivieren (falls Abschnitt 1 durchgeführt)

In `docker-compose.yml` bei **`immich-server`** die `extends`-Zeilen
einkommentieren:

```yaml
  immich-server:
    extends:
      file: hwaccel.transcoding.yml
      service: quicksync
```

Und bei **`immich-machine-learning`** zusätzlich das Image-Tag auf die
OpenVINO-Variante umstellen:

```yaml
  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-release}-openvino
    extends:
      file: hwaccel.ml.yml
      service: openvino
```

`quicksync` und `openvino` reichen beide `/dev/dri` in den Container — genau das
Device, das in Abschnitt 1 an den CT durchgereicht wurde.

Nach dem Start in der Weboberfläche unter *Administration → Settings → Video
Transcoding* die Hardware-Beschleunigung noch auf **Quick Sync** stellen.

---

## 5. Starten

```bash
cd /opt/immich
docker compose up -d
docker compose ps
docker compose logs -f immich-server
```

Der erste Start dauert: Postgres initialisiert das Datenverzeichnis, das
ML-Modell wird geladen. Danach erreichbar unter `http://192.168.2.205:2283`.

Beim ersten Aufruf wird das Admin-Konto angelegt. **Bevor das passiert**, bei
vorhandenem DB-Dump erst Abschnitt 8 lesen — die Wiederherstellung wird im
Onboarding direkt angeboten.

---

## 6. Firewall

Auf dem **Host**. Wichtig ist der `[OPTIONS]`-Block — ohne `enable: 1` ist die
Datei wirkungslos, genau der Fehler, der bei CT 111 steckt:

```bash
cat > /etc/pve/firewall/104.fw <<'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 2283 -log nolog
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 22 -log nolog
IN ACCEPT -p icmp
EOF

pve-firewall status
pve-firewall compile | grep -A8 'GROUP-104\|104'
```

Gegenprüfen — von einem anderen Rechner im LAN muss 2283 offen und alles andere
zu sein:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://192.168.2.205:2283
```

---

## 7. Cloudflare Tunnel

**Kein Handgriff nötig**, sofern IP und Port wie oben gewählt wurden: die Route
`photos.rxf-sys.de → http://192.168.2.205:2283` existiert noch aus der Zeit von
CT 104.

Prüfen:

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://photos.rxf-sys.de
```

`502` vor der Installation, `200` danach. Bleibt es bei `502`, im
Cloudflare-Dashboard unter Networks → Tunnels → `rxf-sys-home` die Origin
gegenprüfen. Siehe [../../03-netzwerk/cloudflare-tunnel.md](../../03-netzwerk/cloudflare-tunnel.md).

> Immich ist damit **aus dem Internet erreichbar** — ohne Cloudflare Access
> davor, wie schon bei `pve` und `pbs`. Immich hat eine eigene
> Benutzerverwaltung, das ist also nicht dasselbe wie eine offene PVE-Konsole.
> Trotzdem gilt Maßnahme 3 aus dem Audit-Bericht auch hier: eine Access-Policy
> oder zumindest ein starkes Admin-Passwort plus aktiviertes 2FA in Immich.

---

## 8. Alte Bibliothek zurückholen

### 8.1 Restore des v2.7.5-Dumps

Der Stand ist geklärt (Abschnitt 0.1): Dump vom 3. August, Immich v2.7.5,
Postgres 14.19. Das Postgres-Image ist unverändert, es ist also ein reiner
Datenbank-Restore ohne Engine-Wechsel.

**Reihenfolge — erst v2.7.5, dann v3.** Nicht direkt auf v3 restaurieren:

1. **Dumps gesichert?** Siehe Kasten in Abschnitt 0.1. Ohne das kein Restore.

2. **Compose passend zur Dump-Version holen** statt `latest`:

   ```bash
   cd /opt/immich
   BASE=https://github.com/immich-app/immich/releases/download/v2.7.5
   curl -fsSL -o docker-compose.yml      $BASE/docker-compose.yml
   curl -fsSL -o hwaccel.transcoding.yml $BASE/hwaccel.transcoding.yml
   curl -fsSL -o hwaccel.ml.yml          $BASE/hwaccel.ml.yml
   ```

3. **In `.env` pinnen:**

   ```ini
   IMMICH_VERSION=v2.7.5
   ```

4. **Datenverzeichnis leeren und starten** — der Restore braucht eine
   uninitialisierte DB:

   ```bash
   docker compose down
   rm -rf /opt/immich/postgres
   docker compose up -d
   docker compose logs -f immich-server
   ```

5. **Restore auslösen.** Beim ersten Aufruf von `http://192.168.2.205:2283`
   bietet das Onboarding die Wiederherstellung aus einem vorhandenen Dump an —
   die Dateien unter `/data/backups` werden dort gelistet. Alternativ nach dem
   Anlegen des Admin-Kontos über *Administration → Maintenance*.

   **Kein Admin-Konto anlegen, bevor der Restore läuft**, sonst kollidiert es
   mit den Benutzern aus dem Dump.

6. **Prüfen, und zwar gründlich:** Anzahl der Assets, das älteste und das
   neueste Foto, Alben, Benutzerkonten, geteilte Links. Erst wenn das stimmt,
   weiter zu Schritt 7.

7. **Auf v3 hochziehen:**

   ```bash
   cd /opt/immich
   BASE=https://github.com/immich-app/immich/releases/latest/download
   curl -fsSL -o docker-compose.yml      $BASE/docker-compose.yml
   curl -fsSL -o hwaccel.transcoding.yml $BASE/hwaccel.transcoding.yml
   curl -fsSL -o hwaccel.ml.yml          $BASE/hwaccel.ml.yml
   sed -i 's/^IMMICH_VERSION=.*/IMMICH_VERSION=v3/' .env
   docker compose pull && docker compose up -d
   docker compose logs -f immich-server
   ```

   Die GPU-Anpassungen aus Abschnitt 4 müssen in der neu geladenen
   `docker-compose.yml` erneut gesetzt werden.

#### Zum v3-Upgrade

- **Dokumentierter Breaking Change:** v3 hebt die numpy-Version an und setzt
  damit für die ML-Komponente eine CPU auf **x86-64-v2**-Niveau voraus. Der
  i5-9500T (Coffee Lake Refresh, 2019) erfüllt das mit Abstand — `lscpu` zeigt
  `sse4_1`, `sse4_2`, `popcnt`, `ssse3`. **Kein Problem auf dieser Hardware.**
- Die übrigen Breaking Changes betreffen laut Release-Notes vor allem
  API-Endpunkte, also Drittanwendungen gegen die Immich-API.
- Es gibt einen Bugreport zu genau diesem Sprung
  ([#29445](https://github.com/immich-app/immich/issues/29445): fehlende Assets
  nach Upgrade v2.7.5 → v3.0.0). Der Report ist geschlossen, ohne dass eine
  Ursache dokumentiert wäre — Einzelfall oder Bedienfehler ist genauso möglich
  wie ein echter Defekt. Grund genug, Schritt 6 ernst zu nehmen und **die
  gesicherten Dumps bis auf Weiteres zu behalten**. Solange die existieren, ist
  das Upgrade umkehrbar.

Wer das Risiko nicht braucht: **auf v2.7.5 bleiben** ist eine legitime Wahl.
Die Bibliothek ist dann zurück und läuft; das Upgrade lässt sich jederzeit
nachholen.

### 8.2 Fallback ohne DB-Dump

Nur relevant, falls der Restore scheitert. Dann sind nur die Dateien da. Der saubere Weg ist eine **External Library**:
Immich liest das Verzeichnis, ohne die Dateien zu verschieben oder zu
verändern.

*Administration → External Libraries → Create Library*, Pfad `/data` (das ist
`UPLOAD_LOCATION` im Container), danach Scan anstoßen.

Alben, Gesichtszuordnungen und geteilte Links aus der alten Installation sind
verloren. Gesichtserkennung und Smart Search laufen beim ersten Scan neu — das
dauert bei größeren Bibliotheken Stunden und ist der Grund, die GPU-Variante aus
Abschnitt 4 zu nehmen.

---

## 9. Backup

**vzdump braucht keine Änderung.** Der Job `pbs-nightly` läuft mit `all 1`, CT
104 ist ab der nächsten Nacht 02:00 automatisch dabei.

Was gesichert wird — und was nicht:

| Inhalt | Ort | In vzdump? |
|--------|-----|------------|
| Docker-Konfiguration, Compose, `.env` | `/opt/immich` (rootfs) | ✔ |
| Postgres-Daten | `/opt/immich/postgres` (rootfs) | ✔ (aber im laufenden Betrieb, siehe 0.3) |
| **Fotobibliothek** | `/mnt/storage/immich` (Bind-Mount) | ✘ |

Bind-Mounts nimmt vzdump grundsätzlich nicht mit. Die Bibliothek ist damit
genau so ungesichert wie der Rest von `/mnt/storage` — das ist der seit
Längerem offene Punkt aus [../../01-hardware/disks.md](../../01-hardware/disks.md).

Immichs eigene DB-Dumps unter *Administration → Settings → Backup* prüfen und
aktiv lassen. Sie sind der Grund, warum die Bibliothek diesmal überhaupt
gerettet werden kann.

---

## 10. Monitoring und Doku nachziehen

- **Uptime Kuma** (CT 103): HTTP-Monitor auf `http://192.168.2.205:2283`
  anlegen, siehe [../../07-monitoring/uptime-kuma.md](../../07-monitoring/uptime-kuma.md)
- **Admin-Dashboard** (CT 101): erscheint automatisch über die PVE-API
- **Diese Doku:** nach der Installation die tatsächlich gewählten Werte
  (RAM, Disk, GPU ja/nein, Immich-Version) hier eintragen und die Einträge in
  [../README.md](../README.md), [../../README.md](../../README.md) sowie
  [../../03-netzwerk/README.md](../../03-netzwerk/README.md) ergänzen
- **Audit-Bericht:** Maßnahme 5 (`photos.rxf-sys.de` tot) abhaken

---

## Wartung

```bash
pct exec 104 -- docker compose -f /opt/immich/docker-compose.yml ps
pct exec 104 -- docker compose -f /opt/immich/docker-compose.yml logs --tail 50 immich-server

# Update: IMMICH_VERSION in .env anpassen, dann
pct exec 104 -- bash -lc 'cd /opt/immich && docker compose pull && docker compose up -d'

# Aufräumen alter Images
pct exec 104 -- docker image prune -a
```

`IMMICH_VERSION=v3` folgt dem Major-Release-Kanal. Wer keine überraschenden
Sprünge will, pinnt stattdessen eine konkrete Version (`v3.x.y`) und zieht
bewusst nach.

## Quellen

- [Immich — Docker Compose Installation](https://docs.immich.app/install/docker-compose/)
- [Immich — Backup and Restore](https://docs.immich.app/administration/backup-and-restore/)
- [Immich — Requirements](https://docs.immich.app/install/requirements/)
- Compose- und Env-Vorlagen: `https://github.com/immich-app/immich/releases/latest/download/`
