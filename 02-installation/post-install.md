# Post-Install Konfiguration

## 1. Enterprise-Repository deaktivieren

```bash
# Enterprise-Repo deaktivieren (keine Lizenz)
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list

# Ceph Enterprise-Repo deaktivieren (falls vorhanden)
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/ceph.list 2>/dev/null
```

## 2. No-Subscription Repository aktivieren

```bash
# Community-Repo hinzufuegen
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
```

## 3. System aktualisieren

```bash
apt update && apt full-upgrade -y
```

## 4. Nuetzliche Pakete installieren

```bash
apt install -y \
  vim \
  htop \
  curl \
  wget \
  smartmontools \
  ethtool \
  iotop \
  net-tools
```

## 5. Subscription-Nag entfernen (optional)

```bash
# Hinweis: Muss nach jedem PVE-Update erneut ausgefuehrt werden
sed -Ezi.bak "s/(Ext\.Msg\.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy.service
```

## 6. Daten-SSD einbinden

```bash
# Partition erstellen (falls neue SSD)
fdisk /dev/sda
# -> n (neue Partition), p (primaer), Enter, Enter, w (schreiben)

# Formatieren
mkfs.ext4 /dev/sda1

# Mount-Verzeichnis erstellen
mkdir -p /mnt/storage

# UUID ermitteln
blkid /dev/sda1

# In /etc/fstab eintragen
echo "UUID=<DEINE-UUID> /mnt/storage ext4 defaults,noatime,nofail 0 2" >> /etc/fstab

# Mounten
mount -a

# Ordnerstruktur erstellen
mkdir -p /mnt/storage/{shared,media/{movies,music,photos},backups}
```

## 7. Backup-SSD einbinden

```bash
mkdir -p /mnt/backups

# UUID ermitteln
blkid /dev/sdb1

# In /etc/fstab eintragen
echo "UUID=<DEINE-UUID> /mnt/backups ext4 defaults,noatime,nofail 0 2" >> /etc/fstab

mount -a
mkdir -p /mnt/backups/proxmox
```

## 8. DuckDNS einrichten

```bash
# Cronjob fuer DuckDNS IP-Update
crontab -e
# Eintragen:
# */5 * * * * curl -s "https://www.duckdns.org/update?domains=rxfsys,vault-rxfsys&token=DEIN_TOKEN&ip=" > /dev/null
```

## 9. SSH-Key hinterlegen

```bash
# Auf dem Client:
ssh-copy-id root@192.168.2.120
```

## Automatisiert

Alternativ kann das Post-Install Script verwendet werden:

```bash
bash scripts/post-install.sh
```

Siehe [scripts/post-install.sh](scripts/post-install.sh)
