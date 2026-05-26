#!/bin/bash
# Read-only Health-Check für rxf-sys.
# Liefert Markdown-Report auf stdout. Kein State-Change.

set +H
echo "# rxf-sys Health Check — $(date -Iseconds)"
echo

echo "## Uptime + Kernel"
uptime
echo
uname -r
pveversion | head -1
echo

echo "## Guests"
pct list
echo
qm list
echo

echo "## Storage"
pvesm status
echo

echo "## Disk"
df -hT | grep -vE 'tmpfs|udev|efivars|fuse'
echo

echo "## Failed Services (sollte leer sein)"
systemctl --failed --no-legend
echo

echo "## Firewall"
pve-firewall status
echo

echo "## Backup-Job"
grep -E '^vzdump|schedule|all|exclude' /etc/pve/jobs.cfg
echo

echo "## Updates"
echo "Host: $(apt list --upgradable 2>/dev/null | grep -v '^Listing' | wc -l) upgradable packages"
echo

echo "## PBS Datastore"
pvesm list pbs 2>&1 | wc -l | awk '{print $1" Snapshots in pbs"}'
echo

echo "## SMART"
for dev in nvme0n1 sda; do
  STATUS=$(smartctl -H /dev/$dev 2>/dev/null | awk '/SMART overall-health/{print $NF}')
  echo "$dev: $STATUS"
done
echo

echo "## dmesg Errors letzte 24h"
dmesg --since "24 hours ago" 2>&1 | grep -iE 'error|fail' | grep -ivE 'audit|firewire' | head -10
