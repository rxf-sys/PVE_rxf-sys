#!/bin/bash
# Wöchentlich Config-Backup → PBS (host backup-type)
# Pfad auf Host: /usr/local/sbin/backup-host-config-pbs.sh
# Trigger: systemd-Timer backup-host-config-pbs.timer (Sun 01:00)

set -euo pipefail

FINGERPRINT=$(awk '/^pbs:/{f=1} f && /fingerprint/{print $2; exit}' /etc/pve/storage.cfg)

export PBS_REPOSITORY='root@pam!pve-host@192.168.2.209:backups'
export PBS_PASSWORD="$(cat /etc/pve/priv/storage/pbs.pw)"
export PBS_FINGERPRINT="$FINGERPRINT"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

mkdir -p "$TMP/snapshots"
pveversion -v                              > "$TMP/snapshots/pveversion.txt" 2>&1 || true
dpkg --get-selections                      > "$TMP/snapshots/dpkg-selections.txt"
lsblk -fJ                                  > "$TMP/snapshots/lsblk.json"
pvesm status                               > "$TMP/snapshots/pvesm-status.txt" 2>&1 || true
pct list                                   > "$TMP/snapshots/pct-list.txt"     2>&1 || true
qm list                                    > "$TMP/snapshots/qm-list.txt"      2>&1 || true
ip -j a                                    > "$TMP/snapshots/ip-a.json"        2>&1 || true
date -Iseconds                             > "$TMP/snapshots/_generated.txt"

proxmox-backup-client backup \
  etc.pxar:/etc \
  pve-cluster.pxar:/var/lib/pve-cluster \
  rrdcached.pxar:/var/lib/rrdcached/db \
  dpkg.pxar:/var/lib/dpkg \
  snapshots.pxar:"$TMP/snapshots" \
  --backup-type host \
  --backup-id rxf-sys-config 2>&1
