#!/bin/bash
# Re-apply Subscription-Nag-Patch nach apt-Updates
# Pfad auf Host: /usr/local/sbin/repatch-no-nag.sh
# Trigger: dpkg-Hook /etc/apt/apt.conf.d/80pve-no-nag

PWT=/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
if [ -f "$PWT" ] && grep -q "data.status.toLowerCase() !== 'active'" "$PWT"; then
  sed -i "s/data\.status\.toLowerCase() !== 'active'/false/g" "$PWT"
  systemctl reload-or-restart pveproxy.service 2>/dev/null || true
  logger -t pve-no-nag "Re-applied subscription-nag patch"
fi
