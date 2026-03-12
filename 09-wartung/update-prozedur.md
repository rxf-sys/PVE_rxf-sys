# Update-Prozedur

## Vor dem Update

1. Backup aller Container erstellen
2. Aktuelle Konfiguration dokumentieren
3. Proxmox Version notieren

```bash
# Aktuelle Version pruefen
pveversion -v

# Backup vor Update
for i in $(pct list | awk 'NR>1 {print $1}'); do
  vzdump $i --storage local --compress zstd --mode snapshot
done
```

## Proxmox Host Update

```bash
# 1. Paketlisten aktualisieren
apt update

# 2. Verfuegbare Updates anzeigen
apt list --upgradable

# 3. Update durchfuehren
apt full-upgrade -y

# 4. Kernel-Update pruefen
# Falls neuer Kernel installiert: Reboot noetig
uname -r                    # Aktueller Kernel
dpkg -l | grep pve-kernel   # Installierte Kernel

# 5. Reboot (falls noetig)
reboot
```

### Nach dem Reboot

```bash
# Pruefen ob alles laeuft
pveversion -v
pct list
systemctl status pveproxy
```

## Container Updates

```bash
# Alle Container aktualisieren
for i in $(pct list | awk 'NR>1 {print $1}'); do
  echo "=== Updating CT $i ==="
  pct exec $i -- apt update
  pct exec $i -- apt upgrade -y
done
```

## Docker-Images aktualisieren

Container mit Docker (CT 102, 103, 104):

```bash
# WireGuard (CT 102)
pct exec 102 -- bash -c 'cd /srv/appdata/wireguard && docker compose pull && docker compose up -d'

# Vaultwarden (CT 103)
pct exec 103 -- bash -c 'cd /srv/appdata/vaultwarden && docker compose pull && docker compose up -d'

# Nginx Proxy Manager (CT 104)
pct exec 104 -- bash -c 'cd /srv/appdata/nginx-proxy && docker compose pull && docker compose up -d'
```

## Rollback

Falls nach einem Update Probleme auftreten:

```bash
# Container aus Backup wiederherstellen
pct restore <ID> /var/lib/vz/dump/vzdump-lxc-<ID>-<DATUM>.tar.zst

# Bei Kernel-Problemen: Alten Kernel booten
# Im GRUB-Menue den vorherigen Kernel auswaehlen

# Paket-Downgrade (Notfall)
apt install <paket>=<version>
```
