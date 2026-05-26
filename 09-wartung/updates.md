# Updates

## Update-Reihenfolge

1. **Host** (rxf-sys) — `apt update && apt -y dist-upgrade`
2. **PBS-VM** (201) — analog innerhalb VM
3. **LXCs in Risiko-Reihenfolge**:
   - Tier 1 (low-risk, nativ/keine Docker): 106 jellyfin, 107 portfolio, 108 welcome-page, 100 nas
   - Tier 2 (Docker, mittleres Risiko): 109 orynthia, 103 uptime-kuma, 102 vaultwarden
   - Tier 3 (kritische Services): 101 admin-dashboard, **104 docker-host** (cloudflared!) zuletzt
4. **VM 200** (HA OS) — via HA-UI: Settings → System → Updates

## Skripte für Bulk-Updates

```bash
# Alle CTs sequenziell
for id in 106 107 108 100 109 103 102 101 104; do
  echo "==== CT $id ===="
  pct exec $id -- bash -c '
    export DEBIAN_FRONTEND=noninteractive
    apt update
    apt -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" dist-upgrade
    apt -y autoremove
    systemctl --failed --no-legend
  '
done
```

PBS-VM:
```bash
ssh root@192.168.2.209 'apt update && apt -y dist-upgrade && systemctl --failed'
```

## Kernel-Updates auf Host

```bash
# Welcher Kernel läuft?
uname -r

# Welche sind installiert?
dpkg -l | grep proxmox-kernel | head

# Nach Kernel-Update: Reboot
systemctl reboot
```

GRUB-Default = höchster installierter Kernel (kein proxmox-boot-tool, klassisches GRUB).

## Updates in PBS-VM

```bash
ssh root@192.168.2.209
apt update
apt list --upgradable
apt -y dist-upgrade
# falls Kernel-Update:
systemctl reboot      # PBS-Storage ~30s nicht verfügbar
```

## Docker-Updates (in den CTs)

Docker-Container-Updates erfolgen NICHT via apt — sondern:
```bash
pct exec 104 -- bash -c 'cd /var/lib/docker/volumes/portainer_data/_data/compose/6 && docker compose pull && docker compose up -d'
# (Stack 6 = immich; analog für andere Stacks)
```

## Nag-Patch nach Updates

Der dpkg-Hook `/etc/apt/apt.conf.d/80pve-no-nag` re-patcht den Subscription-Nag nach jedem `apt`-Run automatisch.

## Update-Mail

Updates werden NICHT proaktiv benachrichtigt. Manuell prüfen:
```bash
apt list --upgradable 2>/dev/null | grep -v '^Listing'
```

Optional: cron-Job einrichten der wöchentlich `apt list --upgradable` per Mail schickt.
