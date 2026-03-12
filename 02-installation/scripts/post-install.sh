#!/bin/bash
# =============================================================================
# Proxmox VE Post-Install Script
# Server: rxfsys
# =============================================================================

set -e

echo "=== Proxmox VE Post-Install Script ==="
echo ""

# 1. Enterprise-Repo deaktivieren
echo "[1/6] Enterprise-Repository deaktivieren..."
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
[ -f /etc/apt/sources.list.d/ceph.list ] && sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/ceph.list

# 2. No-Subscription Repo aktivieren
echo "[2/6] No-Subscription Repository aktivieren..."
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# 3. System aktualisieren
echo "[3/6] System aktualisieren..."
apt update && apt full-upgrade -y

# 4. Nuetzliche Pakete
echo "[4/6] Zusaetzliche Pakete installieren..."
apt install -y \
  vim \
  htop \
  curl \
  wget \
  smartmontools \
  ethtool \
  iotop \
  net-tools

# 5. Daten-SSD einbinden
echo "[5/6] Storage-Verzeichnisse erstellen..."
mkdir -p /mnt/storage/{shared,media/{movies,music,photos},backups}
mkdir -p /mnt/backups/proxmox
echo "HINWEIS: /etc/fstab Eintraege manuell erstellen! (siehe post-install.md)"

# 6. SMART-Test
echo "[6/6] SMART-Status pruefen..."
smartctl -H /dev/nvme0n1 2>/dev/null || echo "NVMe SMART nicht verfuegbar"
smartctl -H /dev/sda 2>/dev/null || echo "SATA SMART nicht verfuegbar"

echo ""
echo "=== Post-Install abgeschlossen ==="
echo "Naechste Schritte:"
echo "  1. /etc/fstab fuer Daten-SSD und Backup-SSD konfigurieren"
echo "  2. DuckDNS Cronjob einrichten"
echo "  3. SSH-Keys hinterlegen"
echo "  4. Container erstellen (siehe 05-container/)"
