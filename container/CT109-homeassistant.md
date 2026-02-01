# CT 109 - Home Assistant (Smart Home)

## Übersicht

| Parameter | Wert |
|-----------|------|
| **VMID** | 109 |
| **Hostname** | homeassistant |
| **IP-Adresse** | 192.168.2.130 |
| **RAM** | 2048 MB |
| **CPU** | 2 Cores |
| **Disk** | 10 GB |
| **OS** | Debian Trixie |
| **Dienst** | Home Assistant Core |

---

## Funktion

Home Assistant ist eine Open-Source-Plattform für Smart-Home-Automatisierung. Es integriert verschiedene Geräte und Dienste in einer einheitlichen Oberfläche.

---

## Zugriff

| Dienst | URL |
|--------|-----|
| Web-Interface | http://192.168.2.130:8123 |
| Mit lokalem DNS | http://homeassistant.home:8123 |

### Zugangsdaten

| Parameter | Wert |
|-----------|------|
| Benutzer | `___________________` |
| Passwort | `___________________` |

---

## Container-Konfiguration

**Datei:** `/etc/pve/lxc/109.conf`

```ini
arch: amd64
cores: 2
features: nesting=1
hostname: homeassistant
memory: 2048
net0: name=eth0,bridge=vmbr0,firewall=1,gw=192.168.2.1,ip=192.168.2.130/24,type=veth
onboot: 1
ostype: debian
rootfs: local-lvm:vm-109-disk-0,size=10G
swap: 2048
unprivileged: 1
```

---

## Installation (Home Assistant Core)

```bash
# Python-Umgebung
apt install -y python3 python3-dev python3-venv python3-pip \
    libffi-dev libssl-dev libjpeg-dev zlib1g-dev autoconf \
    build-essential libopenjp2-7 libtiff5 libturbojpeg0-dev \
    tzdata ffmpeg liblapack3 liblapack-dev libatlas-base-dev

# Benutzer erstellen
useradd -rm homeassistant -G dialout,gpio,i2c

# Virtual Environment
mkdir /srv/homeassistant
chown homeassistant:homeassistant /srv/homeassistant

sudo -u homeassistant -H -s
cd /srv/homeassistant
python3 -m venv .
source bin/activate
pip install wheel
pip install homeassistant
exit
```

---

## Service-Konfiguration

**Datei:** `/etc/systemd/system/home-assistant@homeassistant.service`

```ini
[Unit]
Description=Home Assistant
After=network-online.target

[Service]
Type=simple
User=homeassistant
WorkingDirectory=/srv/homeassistant
ExecStart=/srv/homeassistant/bin/hass -c "/home/homeassistant/.homeassistant"
Restart=on-failure
RestartForceExitStatus=100

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable home-assistant@homeassistant
systemctl start home-assistant@homeassistant
```

---

## Verwaltung

```bash
# Status prüfen
pct exec 109 -- systemctl status home-assistant@homeassistant

# Neustarten
pct exec 109 -- systemctl restart home-assistant@homeassistant

# Logs anzeigen
pct exec 109 -- journalctl -u home-assistant@homeassistant -n 50

# Home Assistant aktualisieren
pct exec 109 -- sudo -u homeassistant -H -s << 'EOF'
cd /srv/homeassistant
source bin/activate
pip install --upgrade homeassistant
EOF
pct exec 109 -- systemctl restart home-assistant@homeassistant
```

---

## Konfiguration

**Hauptkonfiguration:** `/home/homeassistant/.homeassistant/configuration.yaml`

```yaml
homeassistant:
  name: Home
  latitude: !secret latitude
  longitude: !secret longitude
  elevation: !secret elevation
  unit_system: metric
  time_zone: Europe/Berlin

# Web-Interface
http:
  server_host: 0.0.0.0
  server_port: 8123

# Logger
logger:
  default: info

# Recorder (Datenbank)
recorder:
  db_url: sqlite:////home/homeassistant/.homeassistant/home-assistant_v2.db
  purge_keep_days: 10

# Integrationen
# Weitere Integrationen über Web-UI hinzufügen
```

---

## Integrationen hinzufügen

1. **Settings** → **Devices & Services** → **Add Integration**
2. Nach Dienst/Gerät suchen
3. Konfiguration durchführen

### Beliebte Integrationen

- **Philips Hue** - Smarte Beleuchtung
- **MQTT** - IoT-Protokoll
- **Shelly** - Smarte Schalter
- **Zigbee (ZHA)** - Zigbee-Geräte
- **Google Cast** - Chromecast, Google Home
- **Spotify** - Musik-Integration

---

## Automatisierungen

### Beispiel: Licht bei Sonnenuntergang

```yaml
automation:
  - alias: "Licht bei Sonnenuntergang"
    trigger:
      - platform: sun
        event: sunset
        offset: "-00:30:00"
    action:
      - service: light.turn_on
        target:
          entity_id: light.wohnzimmer
        data:
          brightness_pct: 80
```

---

## Firewall

**Datei:** `/etc/pve/firewall/109.fw`

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Home Assistant Web-UI (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 8123 -log nolog

# mDNS für Geräte-Discovery
IN ACCEPT -source 192.168.2.0/24 -p udp -dport 5353 -log nolog

# ICMP/Ping
IN ACCEPT -p icmp
```

---

## USB-Geräte durchreichen (optional)

Für Zigbee/Z-Wave Sticks:

```bash
# Am Host: USB-Gerät finden
lsusb

# Container-Konfiguration anpassen
# /etc/pve/lxc/109.conf
lxc.cgroup2.devices.allow: c 188:* rwm
lxc.mount.entry: /dev/ttyUSB0 dev/ttyUSB0 none bind,optional,create=file
```

---

## Wichtige Pfade

| Pfad | Beschreibung |
|------|--------------|
| `/home/homeassistant/.homeassistant/` | Konfiguration |
| `/home/homeassistant/.homeassistant/configuration.yaml` | Hauptkonfig |
| `/home/homeassistant/.homeassistant/secrets.yaml` | Sensible Daten |
| `/home/homeassistant/.homeassistant/automations.yaml` | Automatisierungen |
| `/srv/homeassistant/` | Virtual Environment |

---

## Backup

```bash
# Container-Backup
vzdump 109 --storage local --compress zstd --mode snapshot

# Nur Konfiguration
pct exec 109 -- tar -czf /root/ha-config.tar.gz /home/homeassistant/.homeassistant/
```

### Wichtig zu sichern

- `configuration.yaml`
- `secrets.yaml`
- `automations.yaml`
- `scripts.yaml`
- `scenes.yaml`
- `.storage/` (Integrationen, Geräte)

---

## Troubleshooting

### Home Assistant startet nicht

```bash
# Konfiguration prüfen
pct exec 109 -- sudo -u homeassistant -H -s << 'EOF'
cd /srv/homeassistant
source bin/activate
hass --script check_config -c /home/homeassistant/.homeassistant
EOF
```

### Langsame Performance

- RAM erhöhen (4 GB empfohlen bei vielen Integrationen)
- Recorder-Datenbank regelmäßig bereinigen
- `purge_keep_days` reduzieren

---

*CT 109 - Home Assistant | Server rxfsys*