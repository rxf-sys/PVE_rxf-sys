# CT 104 — Immich v2.7.5 installieren und Bibliothek zurückholen

Linearer Ablauf von oben nach unten. Ziel: CT 104 neu anlegen, Immich **v2.7.5**
aufsetzen und den Datenbank-Dump vom 3. August 2026 einspielen, sodass die alte
Bibliothek mit Alben, Benutzern und Metadaten zurück ist.

Für Hintergrund, Alternativen und das spätere v3-Upgrade siehe
[CT104-immich.md](CT104-immich.md).

## Ausgangslage

| | |
|---|---|
| Dump | `immich-db-backup-20260803T020000-v2.7.5-pg14.19.sql.gz` |
| Immich-Version | v2.7.5 |
| Postgres | 14.19 — identisches Image wie im aktuellen Release, kein Engine-Wechsel |
| Bibliothek | `/mnt/storage/immich`, 2,4 GB |
| Ziel-IP | 192.168.2.205 (Tunnel-Origin für `photos.rxf-sys.de` zeigt bereits dorthin) |

Warum v2.7.5 und nicht gleich v3: Ein Dump wird am zuverlässigsten in die
Version zurückgespielt, die ihn geschrieben hat. Immich führt Migrationen zwar
automatisch aus, aber jeder Versionssprung während eines Restores ist eine
zusätzliche Fehlerquelle. Erst die Bibliothek zurückholen, dann in Ruhe
upgraden.

---

## Schritt 0 — Dumps sichern

**Zwingend, vor allem anderen.** Es liegen genau 14 Dumps, das ist auch die
Standard-Retention. Der erste Dump eines neu gestarteten Immich verdrängt also
sofort den ältesten — und wenn die Datenbank zu dem Zeitpunkt leer ist,
schrumpft der Bestand mit jedem Tag.

```bash
mkdir -p /mnt/storage/extra-backups/immich-db-2026-08
cp -av /mnt/storage/immich/backups/*.sql.gz \
       /mnt/storage/extra-backups/immich-db-2026-08/
ls -lah /mnt/storage/extra-backups/immich-db-2026-08/
```

Erwartung: 14 Dateien, zusammen ~230 MB.

Zusätzlich die Verzeichnisstruktur festhalten, damit du sie später gegenprüfen
kannst:

```bash
ls -la /mnt/storage/immich/
```

Immich erwartet dort `backups`, `encoded-video`, `library`, `profile`, `thumbs`
und `upload`. Diese Ordner sind der Grund, warum der Restore funktioniert — der
Dump enthält nur Metadaten und Dateipfade, nicht die Bilder selbst.

---

## Schritt 1 — Container anlegen

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

`unprivileged 1` ist hier nicht optional: Die Altdaten gehören
`100000:100000`, was dem Standard-idmap eines unprivilegierten Containers
entspricht. Ein privilegierter Container würde die Rechte nicht treffen.

`nesting=1` und `keyctl=1` braucht Docker im unprivilegierten LXC — dieselbe
Kombination wie bei CT 101, 102, 103 und 109.

### Bind-Mount

```bash
pct set 104 -mp0 /mnt/storage/immich,mp=/srv/immich-data
pct exec 104 -- ls -la /srv/immich-data/
```

Die Ausgabe muss die Ordner aus Schritt 0 zeigen. Tut sie das nicht, stimmt der
Mount nicht — hier nicht weitermachen.

### GPU durchreichen (optional)

Beschleunigt Transcoding und die ML-Inferenz. Die iGPU ist bereits an CT 106
(Jellyfin) durchgereicht, mehrere Consumer sind unproblematisch.

```bash
pct set 104 -dev0 /dev/dri/renderD128,gid=44
pct reboot 104
pct exec 104 -- ls -la /dev/dri/
```

---

## Schritt 2 — Docker installieren

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

docker run --rm hello-world
```

Der `hello-world`-Lauf muss durchgehen. Scheitert er mit Berechtigungsfehlern,
fehlen `nesting` oder `keyctl` am Container.

---

## Schritt 3 — Immich v2.7.5 holen

Die Dateien **aus dem Release-Tag v2.7.5**, nicht aus `latest`:

```bash
mkdir -p /opt/immich && cd /opt/immich

BASE=https://github.com/immich-app/immich/releases/download/v2.7.5
curl -fsSL -o docker-compose.yml        $BASE/docker-compose.yml
curl -fsSL -o .env                      $BASE/example.env
curl -fsSL -o hwaccel.transcoding.yml   $BASE/hwaccel.transcoding.yml
curl -fsSL -o hwaccel.ml.yml            $BASE/hwaccel.ml.yml

grep -E '^\s+image:' docker-compose.yml
```

Die letzte Zeile muss vier Images zeigen:

```
ghcr.io/immich-app/immich-server:${IMMICH_VERSION:-release}
ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-release}
docker.io/valkey/valkey:9@sha256:3b55fbaa...
ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357...
```

---

## Schritt 4 — `.env` konfigurieren

Passwort erzeugen:

```bash
tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32; echo
```

Dann `/opt/immich/.env` bearbeiten:

```ini
# Bibliothek — Bind-Mount auf /mnt/storage/immich
UPLOAD_LOCATION=/srv/immich-data

# Datenbank — im CT-rootfs, NICHT auf dem Bind-Mount
DB_DATA_LOCATION=/opt/immich/postgres

TZ=Europe/Berlin

# Exakt die Version des Dumps
IMMICH_VERSION=v2.7.5

DB_PASSWORD=<das erzeugte Passwort>
```

`DB_USERNAME=postgres` und `DB_DATABASE_NAME=immich` bleiben unverändert — der
Dump wurde mit diesen Werten geschrieben.

Die Vorlage liefert `IMMICH_VERSION=v2`. Das wäre der v2-Kanal und würde die
jeweils neueste 2.x ziehen. Für den Restore die exakte `v2.7.5` setzen.

### GPU aktivieren (nur falls Schritt 1 mit `dev0` gemacht wurde)

In `docker-compose.yml` bei `immich-server`:

```yaml
  immich-server:
    extends:
      file: hwaccel.transcoding.yml
      service: quicksync
```

Bei `immich-machine-learning` zusätzlich das Image-Tag umstellen:

```yaml
  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-release}-openvino
    extends:
      file: hwaccel.ml.yml
      service: openvino
```

---

## Schritt 5 — Starten

```bash
cd /opt/immich
docker compose up -d
docker compose ps
docker compose logs -f immich-server
```

Der erste Start dauert ein paar Minuten: Postgres initialisiert
`/opt/immich/postgres`, die ML-Modelle werden geladen. Warte, bis der Server
meldet, dass er lauscht, dann `Strg+C` (beendet nur das Log-Following, nicht die
Container).

Erreichbarkeitstest vom Host:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://192.168.2.205:2283
```

---

## Schritt 6 — Restore über das Onboarding

Das ist der vorgesehene Weg für genau diese Situation: frische Installation,
vorhandenes `UPLOAD_LOCATION` mit `backups`-Ordner.

Im Browser `http://192.168.2.205:2283` öffnen.

1. Auf dem Willkommensbildschirm **„Restore from backup"** wählen —
   **nicht** zuerst ein Admin-Konto anlegen. Die Benutzer kommen aus dem Dump,
   ein vorab angelegtes Konto würde damit kollidieren.
2. Immich geht in den Wartungsmodus und zeigt eine **Integritätsprüfung** der
   Speicherordner. Hier siehst du, welche Ordner les- und schreibbar sind und
   wie viele Dateien sie enthalten. Das ist der Moment, in dem sich ein falscher
   Bind-Mount zeigt — die Ordner müssen gefüllt sein.
3. **Next** → Auswahl des Backups.
4. `immich-db-backup-20260803T020000-v2.7.5-pg14.19.sql.gz` auswählen. Immich
   zeigt einen Kompatibilitätsindikator; bei passender Version ist er grün.
5. **Restore**.

Immich legt vor dem Einspielen automatisch einen Wiederherstellungspunkt an,
spielt den Dump ein, führt bei Bedarf Migrationen aus und prüft anschließend die
Gesundheit. Scheitert etwas, rollt es selbstständig zurück.

### Falls das Onboarding nicht greift — CLI-Weg

```bash
cd /opt/immich
docker compose down
rm -rf /opt/immich/postgres
docker compose create
docker start immich_postgres
sleep 10

gunzip --stdout /srv/immich-data/backups/immich-db-backup-20260803T020000-v2.7.5-pg14.19.sql.gz \
| sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
| docker exec -i immich_postgres psql --dbname=immich --username=postgres \
    --single-transaction --set ON_ERROR_STOP=on

docker compose up -d
```

Die `sed`-Zeile ist kein Schönheitsfehler, sondern nötig: Ohne das Umsetzen des
`search_path` findet der Dump beim Einspielen seine eigenen Typen nicht.
`--single-transaction` mit `ON_ERROR_STOP=on` sorgt dafür, dass ein Fehler die
Datenbank nicht halb befüllt zurücklässt.

---

## Schritt 7 — Prüfen

Nimm dir dafür Zeit, bevor du weitermachst. Nach dem Login:

- [ ] **Anzahl der Assets** plausibel (mit dem alten Stand vergleichen, soweit erinnerbar)
- [ ] **Ältestes und neuestes Foto** — deckt der Zeitraum alles ab? Ein Restore, der nur bis zu einem bestimmten Datum reicht, fällt genau hier auf
- [ ] **Alben** vollständig
- [ ] **Benutzerkonten** vorhanden, Login funktioniert
- [ ] **Geteilte Links** noch da
- [ ] **Thumbnails** werden angezeigt — wenn nicht, stimmt der Pfad zur Bibliothek nicht
- [ ] Ein Original in voller Auflösung öffnen

```bash
docker compose logs --tail 100 immich-server | grep -iE 'error|warn'
```

Erst wenn das passt, ist der Restore durch.

---

## Schritt 8 — Firewall

Auf dem **Host**. Der `[OPTIONS]`-Block ist der entscheidende Teil — ohne
`enable: 1` ist die Datei wirkungslos, genau der Fehler, der bei CT 111 steckt:

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
```

Von einem anderen LAN-Rechner gegenprüfen: 2283 offen, alles andere zu.

---

## Schritt 9 — Cloudflare Tunnel

Kein Handgriff nötig, die Route existiert noch aus CT-104-Zeiten:

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://photos.rxf-sys.de
```

`502` vorher, `200` jetzt. Bleibt es bei `502`, im Cloudflare-Dashboard unter
Networks → Tunnels → `rxf-sys-home` die Origin gegenprüfen.

Damit ist Maßnahme 5 aus
[../../09-wartung/audit-2026-08-05.md](../../09-wartung/audit-2026-08-05.md)
erledigt.

> Immich ist damit aus dem Internet erreichbar. Es bringt eine eigene
> Benutzerverwaltung mit, das ist also nicht dasselbe wie eine offene
> PVE-Konsole — trotzdem: starkes Admin-Passwort, und 2FA in Immich aktivieren.

---

## Schritt 10 — Nacharbeiten

- **Backup-Einstellungen prüfen:** *Administration → Settings → Backup*.
  Zeitplan und Retention müssen aktiv sein — diese Dumps sind der Grund, warum
  die Bibliothek diesmal zu retten war.
- **vzdump:** keine Änderung nötig, der Job läuft mit `all 1` und nimmt CT 104
  ab der nächsten Nacht 02:00 automatisch mit. Der Bind-Mount mit der
  Bibliothek ist dabei **nicht** enthalten — das bleibt der offene Punkt aus
  [../../01-hardware/disks.md](../../01-hardware/disks.md).
- **Uptime Kuma** (CT 103): HTTP-Monitor auf `http://192.168.2.205:2283`.
- **Doku:** die tatsächlich gewählten Werte in [CT104-immich.md](CT104-immich.md)
  eintragen und die Zeilen in [../README.md](../README.md),
  [../../README.md](../../README.md) sowie
  [../../03-netzwerk/README.md](../../03-netzwerk/README.md) von „geplant" auf
  den Ist-Zustand setzen.
- **Gesicherte Dumps behalten**, mindestens bis ein späteres v3-Upgrade
  bestätigt sauber gelaufen ist.

---

## Wenn etwas schiefgeht

| Symptom | Ursache | Vorgehen |
|---------|---------|----------|
| Onboarding zeigt keine Backups | `UPLOAD_LOCATION` falsch oder Bind-Mount leer | `docker exec immich_server ls /data/backups` |
| Integritätsprüfung meldet leere Ordner | Bind-Mount zeigt woanders hin | `pct config 104 \| grep mp0` |
| Thumbnails fehlen nach Restore | Ordner `thumbs` nicht am erwarteten Ort | Struktur unter `/srv/immich-data` gegen Schritt 0 prüfen |
| Postgres startet nicht | `DB_DATA_LOCATION` nicht leer beim CLI-Restore | `docker compose down && rm -rf /opt/immich/postgres` |
| `docker run hello-world` scheitert | `nesting`/`keyctl` fehlen | `pct set 104 --features nesting=1,keyctl=1 && pct reboot 104` |

Ganz von vorn anfangen geht jederzeit — die Dumps aus Schritt 0 liegen außerhalb
des Containers:

```bash
pct stop 104 && pct destroy 104
```

Danach zurück zu Schritt 1. Die Bibliothek unter `/mnt/storage/immich` bleibt
davon unberührt, weil sie ein Bind-Mount ist und nicht zum Container gehört.

---

## Später: Upgrade auf v3

Nicht Teil dieser Anleitung, bewusst. Wenn die Bibliothek stabil läuft, steht
der Weg in [CT104-immich.md, Abschnitt 8.1](CT104-immich.md#zum-v3-upgrade) —
inklusive des Hinweises auf einen Bugreport zu genau diesem Versionssprung.
Auf v2.7.5 zu bleiben ist ebenfalls eine tragfähige Entscheidung.

## Quellen

- [Immich v2.7.5 — Backup and Restore](https://raw.githubusercontent.com/immich-app/immich/v2.7.5/docs/docs/administration/backup-and-restore.md)
- [Immich — Docker Compose Installation](https://docs.immich.app/install/docker-compose/)
- Release-Dateien: `https://github.com/immich-app/immich/releases/download/v2.7.5/`
