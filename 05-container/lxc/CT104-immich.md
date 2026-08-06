# CT 104 — immich (Neuinstallation)

Anleitung für die Neuanlage von CT 104 mit Immich. Die VMID 104 und die IP
`192.168.2.205` sind seit der Auflösung des alten `docker-host` frei.

> **Warum genau 104 und .205:** Der Cloudflare Tunnel hat für
> `photos.rxf-sys.de` weiterhin die Origin `http://192.168.2.205:2283`
> eingetragen. Wer die alte VMID und IP wiederverwendet und Immich auf dem
> Standardport 2283 betreibt, bekommt den Public Hostname ohne jede Änderung in
> Cloudflare zurück — und schließt damit Maßnahme 5 aus
> [../../09-wartung/audit-2026-08-05.md](../../09-wartung/audit-2026-08-05.md).

---

## 0. Vor dem Start: drei Entscheidungen

### 0.1 Sind die alten Fotos noch da — und die Datenbank?

`/mnt/storage/immich` hat die Auflösung von CT 104 überlebt; es lag auf sda1,
nicht im Container. Die **Datenbank** lag dagegen in einem Docker-Volume im
rootfs des alten CT 104 und ist damit weg — CT-104-Snapshots sind auch aus dem
PBS-Datastore ausgelaufen.

Es gibt aber einen zweiten Weg: Immich legt **automatische Datenbank-Dumps in
`UPLOAD_LOCATION/backups`** ab (standardmäßig täglich, die letzten 14). Genau
dieses Verzeichnis liegt auf `/mnt/storage/immich` und ist damit erhalten
geblieben.

**Zuerst nachsehen:**

```bash
ls -lah /mnt/storage/immich/
ls -lah /mnt/storage/immich/backups/ 2>/dev/null | tail -20
du -sh /mnt/storage/immich
```

| Ergebnis | Bedeutung |
|----------|-----------|
| `backups/` enthält `.sql.gz`-Dateien | Bibliothek inkl. Alben, Gesichtern und Metadaten ist wiederherstellbar → Abschnitt 8 |
| `backups/` leer oder nicht vorhanden | nur die Dateien sind da. Alben, Gesichtserkennung und Metadaten sind verloren; die Fotos lassen sich als *External Library* wieder einbinden → Abschnitt 8.2 |

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

`/mnt/storage/immich` gehört auf dem Host `101000:101000`, also uid/gid 1000 im
Container. Die Docker-Container laufen als root im CT und schreiben trotzdem —
root im User-Namespace hat die nötigen Capabilities.

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

Immer die Dateien des **aktuellen Release** verwenden, nicht die aus `main` —
letztere passen möglicherweise nicht zum veröffentlichten Image.

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

> **Geändert gegenüber dem alten Setup:** Die Datenbank ist nicht mehr
> `tensorchord/pgvecto-rs`, sondern Immichs eigenes Postgres-Image mit
> VectorChord. Redis wurde durch Valkey ersetzt. Beides ist für einen
> Neuaufbau irrelevant, aber wichtig, falls ein alter Dump eingespielt werden
> soll — siehe Abschnitt 8.

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

### 8.1 Mit vorhandenem DB-Dump

Wenn in `/mnt/storage/immich/backups/` Dumps liegen, ist die vollständige
Bibliothek wiederherstellbar — inklusive Alben, Gesichtern und Metadaten.

**Zuerst herausfinden, welche Immich-Version den Dump geschrieben hat:**

```bash
ls -lt /mnt/storage/immich/backups/ | head
zcat /mnt/storage/immich/backups/<datei>.sql.gz | grep -m1 -i 'immich\|version'
```

Das ist der entscheidende Punkt: Der alte Stack war eine 1.x-Version mit
`pgvecto-rs`. Aktuell ist **v3** mit VectorChord. Ein Dump lässt sich nicht
beliebig weit nach vorne einspielen.

Vorgehen:

1. In `.env` `IMMICH_VERSION` auf **die Version des Dumps** pinnen, nicht auf `v3`.
2. `docker compose up -d`, im Onboarding die Wiederherstellung wählen —
   alternativ *Administration → Maintenance*, dort werden die Dumps mit
   Restore-Button gelistet.
3. Läuft die Bibliothek, `IMMICH_VERSION` **schrittweise** hochziehen und nach
   jedem Schritt `docker compose up -d` sowie die Logs prüfen. Immich fährt die
   Datenbankmigrationen beim Start.

Vor einem Restore muss `DB_DATA_LOCATION` leer sein:

```bash
docker compose down
rm -rf /opt/immich/postgres
docker compose up -d
```

### 8.2 Ohne DB-Dump

Dann sind nur die Dateien da. Der saubere Weg ist eine **External Library**:
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
