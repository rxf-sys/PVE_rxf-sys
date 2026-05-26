#!/bin/bash
# Tägliches lokales Config-Backup → /mnt/storage/host-configs
# Pfad auf Host: /usr/local/sbin/backup-host-config.sh
# Trigger: systemd-Timer backup-host-config.timer (daily 01:30)

set -euo pipefail

BACKUP_DIR="/mnt/storage/host-configs"
RETENTION_DAYS=30
DATE=$(date +%F-%H%M)
OUT="${BACKUP_DIR}/rxf-sys-config-${DATE}.tar.zst"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

mkdir -p "$BACKUP_DIR" "$TMP/snapshots"

# Snapshots als Textfiles für Recovery-Cheatsheet
pveversion -v                              > "$TMP/snapshots/pveversion.txt" 2>&1 || true
dpkg --get-selections                      > "$TMP/snapshots/dpkg-selections.txt"
lsblk -fJ                                  > "$TMP/snapshots/lsblk.json"
pvesm status                               > "$TMP/snapshots/pvesm-status.txt" 2>&1 || true
pct list                                   > "$TMP/snapshots/pct-list.txt"     2>&1 || true
qm list                                    > "$TMP/snapshots/qm-list.txt"      2>&1 || true
ip -j a                                    > "$TMP/snapshots/ip-a.json"        2>&1 || true
ip -j r                                    > "$TMP/snapshots/ip-r.json"        2>&1 || true
pve-firewall status                        > "$TMP/snapshots/firewall-status.txt" 2>&1 || true
systemctl list-unit-files --state=enabled  > "$TMP/snapshots/systemd-enabled.txt" 2>&1 || true
date -Iseconds                             > "$TMP/snapshots/_generated.txt"

# Tar + zstd
tar -cf - \
  --warning=no-file-changed \
  --exclude='/var/lib/dpkg/lock*' \
  --exclude='/var/lib/dpkg/triggers/Lock' \
  /etc \
  /var/lib/pve-cluster \
  /var/lib/rrdcached/db \
  /var/lib/dpkg \
  /usr/local/bin \
  /usr/local/sbin \
  /var/spool/cron \
  /root/.ssh \
  /var/backups \
  -C "$TMP" snapshots \
  2>/dev/null \
  | zstd -T0 -10 -o "$OUT" 2>/dev/null

chmod 600 "$OUT"

# Retention: ältere als $RETENTION_DAYS löschen
find "$BACKUP_DIR" -name 'rxf-sys-config-*.tar.zst' -mtime +$RETENTION_DAYS -delete

SIZE=$(du -sh "$OUT" | awk '{print $1}')
COUNT=$(ls "$BACKUP_DIR"/rxf-sys-config-*.tar.zst 2>/dev/null | wc -l)
echo "Created: $OUT ($SIZE). Total in retention: $COUNT files."
