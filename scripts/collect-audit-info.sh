#!/bin/bash
# collect-audit-info.sh — Read-only Infosammlung für Best-Practice-Audit
#
# KEINE Änderungen am System. Gibt KEINE Secrets aus (keine .env-Inhalte,
# keine Token, keine Passwörter — nur Konfiguration, Status und Metriken).
#
# Aufruf auf dem PVE-Host als root:
#   bash collect-audit-info.sh > /tmp/audit-info-$(date +%F).md 2>&1
#
# Danach Inhalt von /tmp/audit-info-<datum>.md hier einfügen.

set +e
SEP() { echo; echo "---"; echo; }
H()   { echo; echo "## $1"; echo; }
H3()  { echo; echo "### $1"; echo; }
CODE(){ echo '```'; }

echo "# rxf-sys Audit-Infosammlung — $(date -Iseconds)"

# ============================================================ 1. SYSTEM
H "1. System & Versionen"
CODE
pveversion -v 2>/dev/null | head -8
uname -a
uptime
CODE

# ============================================================ 2. CPU / POWER
H "2. CPU, Governor, Microcode"
CODE
echo "Governor:   $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
echo "Driver:     $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null)"
echo "Turbo/Boost: no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null)"
dpkg -l intel-microcode 2>/dev/null | tail -1
journalctl -k -b 2>/dev/null | grep -i microcode | head -3
grep -E 'non-free-firmware' /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null | head -3
CODE

# ============================================================ 3. RAM / SWAP / KSM
H "3. RAM, Swap, KSM"
CODE
free -h
echo
echo "vm.swappiness = $(sysctl -n vm.swappiness)"
echo
echo "KSM pages_sharing:  $(cat /sys/kernel/mm/ksm/pages_sharing 2>/dev/null)"
echo "KSM pages_shared:   $(cat /sys/kernel/mm/ksm/pages_shared 2>/dev/null)"
systemctl is-active ksmtuned 2>/dev/null | xargs echo "ksmtuned:"
CODE

# ============================================================ 4. STORAGE
H "4. Storage, LVM-Thin, Mounts, TRIM"
CODE
pvesm status 2>/dev/null
echo
lvs -o lv_name,vg_name,lv_size,data_percent,metadata_percent,lv_attr 2>/dev/null
echo
df -hT | grep -vE 'tmpfs|udev|efivar|fuse'
echo
echo "Mount-Optionen / und /mnt/storage:"
findmnt -no OPTIONS / /mnt/storage 2>/dev/null
echo
systemctl list-timers fstrim.timer --no-pager 2>/dev/null | head -3
echo
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
CODE

# ============================================================ 5. SMART / SSD-WEAR
H "5. SMART & SSD-Verschleiß"
CODE
echo "=== nvme0n1 ==="
smartctl -H /dev/nvme0n1 2>/dev/null | grep -i overall
smartctl -A /dev/nvme0n1 2>/dev/null | grep -Ei 'percentage used|data units written|power on|temperature|media.*errors|unsafe'
echo
echo "=== sda ==="
smartctl -H /dev/sda 2>/dev/null | grep -i overall
smartctl -A /dev/sda 2>/dev/null | grep -Ei 'Reallocated_Sector|Wear_Leveling|Total_LBAs_Written|Power_On|Temperature_Cel|Pending'
echo
echo "smartd: $(systemctl is-enabled smartd 2>/dev/null) / $(systemctl is-active smartd 2>/dev/null)"
grep -v '^#' /etc/smartd.conf 2>/dev/null | grep -v '^$' | head -5
CODE

# ============================================================ 6. DIENSTE
H "6. Dienste-Status (Host)"
CODE
for s in pve-ha-lrm pve-ha-crm corosync pvesr.timer smartd chrony fail2ban \
         fstrim.timer backup-host-config.timer backup-host-config-pbs.timer; do
  printf "%-30s enabled=%-10s active=%s\n" "$s" \
    "$(systemctl is-enabled $s 2>/dev/null)" "$(systemctl is-active $s 2>/dev/null)"
done
echo
echo "Failed units:"
systemctl --failed --no-legend
CODE

# ============================================================ 7. ZEIT
H "7. Zeitsynchronisation"
CODE
timedatectl 2>/dev/null | grep -E 'Local time|synchronized|NTP service'
chronyc tracking 2>/dev/null | grep -E 'Reference|Stratum|System time|Last offset' || echo "chronyc nicht verfügbar"
CODE

# ============================================================ 8. MAIL / NOTIFICATIONS
H "8. Root-Mail & Notifications"
CODE
grep -E '^root' /etc/aliases 2>/dev/null || echo "kein root-Alias in /etc/aliases"
command -v proxmox-mail-forward >/dev/null && echo "proxmox-mail-forward: vorhanden"
echo
echo "datacenter.cfg:"
cat /etc/pve/datacenter.cfg 2>/dev/null
echo
echo "Notification-Endpoints (Namen):"
pvesh get /cluster/notifications/endpoints/smtp --output-format json 2>/dev/null | grep -o '"name":"[^"]*"'
CODE

# ============================================================ 9. JOURNALD / LOGS
H "9. Journald"
CODE
grep -vE '^#|^$' /etc/systemd/journald.conf 2>/dev/null || echo "(alles default)"
echo
echo "Persistent journal: $([ -d /var/log/journal ] && echo ja || echo NEIN)"
journalctl --disk-usage 2>/dev/null
CODE

# ============================================================ 10. NETZWERK / IPv6
H "10. Netzwerk & IPv6"
CODE
ip -br a
echo
echo "IPv6-Routen:"
ip -6 route 2>/dev/null | head -5
echo
echo "resolv.conf:"
grep -v '^#' /etc/resolv.conf
echo
sysctl net.ipv6.conf.all.disable_ipv6 net.ipv4.conf.all.rp_filter 2>/dev/null
CODE

# ============================================================ 11. SSH
H "11. SSH-Konfiguration (effektiv)"
CODE
sshd -T 2>/dev/null | grep -Ei '^(permitrootlogin|passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication|maxauthtries|x11forwarding|allowtcpforwarding) '
echo
echo "authorized_keys (Anzahl): $(grep -c . /root/.ssh/authorized_keys 2>/dev/null || echo 0)"
CODE

# ============================================================ 12. FAIL2BAN
H "12. fail2ban"
CODE
fail2ban-client status 2>/dev/null
fail2ban-client status sshd 2>/dev/null | grep -E 'Currently|Total'
CODE

# ============================================================ 13. APT
H "13. APT-Repos & Updates"
CODE
grep -rh --include='*.list' --include='*.sources' -E '^(deb |URIs|Suites|Components)' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
echo
echo "Upgradable: $(apt list --upgradable 2>/dev/null | grep -vc '^Listing')"
echo "unattended-upgrades (Host): $(dpkg -l unattended-upgrades 2>/dev/null | tail -1 | awk '{print $1}')"
CODE

# ============================================================ 14. FIREWALL
H "14. Firewall"
CODE
pve-firewall status
echo
echo "Vorhandene FW-Dateien:"
ls -la /etc/pve/firewall/ 2>/dev/null
ls -la /etc/pve/nodes/*/host.fw 2>/dev/null
CODE

# ============================================================ 15. VZDUMP
H "15. vzdump-Konfiguration"
CODE
echo "=== /etc/vzdump.conf (aktiv) ==="
grep -vE '^#|^$' /etc/vzdump.conf 2>/dev/null || echo "(alles default)"
echo
echo "=== jobs.cfg ==="
cat /etc/pve/jobs.cfg 2>/dev/null
echo
echo "Encryption-Key für pbs-Storage: $([ -f /etc/pve/priv/storage/pbs.enc ] && echo VORHANDEN || echo FEHLT)"
CODE

# ============================================================ 16. GUESTS ÜBERSICHT
H "16. Gäste-Übersicht"
CODE
pct list
echo
qm list
CODE

# ============================================================ 17. CT-CONFIGS + ONBOOT/STARTUP/PROTECTION
H "17. LXC-Configs (vollständig)"
for id in $(pct list 2>/dev/null | awk 'NR>1{print $1}'); do
  H3 "CT $id"
  CODE
  pct config "$id"
  CODE
done

H "17b. onboot / startup / protection — Übersicht"
CODE
grep -H -E '^(onboot|startup|protection)' /etc/pve/lxc/*.conf /etc/pve/qemu-server/*.conf 2>/dev/null
CODE

# ============================================================ 18. CT-INNENLEBEN
H "18. CT-Innenleben (nur laufende CTs)"
for id in $(pct list 2>/dev/null | awk 'NR>1 && $2=="running"{print $1}'); do
  H3 "CT $id intern"
  CODE
  timeout 15 pct exec "$id" -- sh -c '
    echo "Timezone:   $(cat /etc/timezone 2>/dev/null)"
    echo "Swap:       $(free -m | awk "/Swap/{print \$3\" / \"\$2\" MB used\"}")"
    echo "Disk /:     $(df -h / | awk "NR==2{print \$3\" / \"\$2\" (\"\$5\")\"}")"
    echo "Failed:     $(systemctl --failed --no-legend 2>/dev/null | wc -l) units"
    echo "unattended: $(dpkg -l unattended-upgrades 2>/dev/null | tail -1 | awk "{print \$1}")"
    if command -v docker >/dev/null 2>&1; then
      echo "Docker Storage-Driver: $(docker info -f "{{.Driver}}" 2>/dev/null)"
      echo "Docker-Container:"
      docker ps --format "  {{.Names}}: {{.Image}} ({{.Status}})" 2>/dev/null
    fi
  ' 2>&1
  CODE
done

# ============================================================ 19. VM-CONFIGS
H "19. VM-Configs"
for id in $(qm list 2>/dev/null | awk 'NR>1{print $1}'); do
  H3 "VM $id"
  CODE
  qm config "$id"
  CODE
done

# ============================================================ 20. PBS-VM INNEN
H "20. PBS-VM (201) intern"
CODE
timeout 20 qm guest exec 201 -- df -h /mnt/backups 2>/dev/null | sed 's/\\n/\n/g'
echo
echo "=== Datastore-Konfig (inkl. verify-new / gc-schedule) ==="
timeout 20 qm guest exec 201 -- proxmox-backup-manager datastore show backups 2>/dev/null | sed 's/\\n/\n/g'
echo
echo "=== Prune-Jobs ==="
timeout 20 qm guest exec 201 -- proxmox-backup-manager prune-job list 2>/dev/null | sed 's/\\n/\n/g'
echo
echo "=== Verify-Jobs ==="
timeout 20 qm guest exec 201 -- proxmox-backup-manager verify-job list 2>/dev/null | sed 's/\\n/\n/g'
echo
echo "=== Sync-Jobs (Off-Site) ==="
timeout 20 qm guest exec 201 -- proxmox-backup-manager sync-job list 2>/dev/null | sed 's/\\n/\n/g'
CODE

# ============================================================ 21. SECRETS-HYGIENE (nur Permissions!)
H "21. Secret-Datei-Permissions (keine Inhalte)"
CODE
ls -la /etc/pve/priv/storage/ 2>/dev/null
stat -c '%a %U:%G %n' /etc/pve/priv/notifications.cfg 2>/dev/null
ls -la /mnt/storage/host-configs/ 2>/dev/null | tail -3
CODE

SEP
echo "_Ende der Infosammlung. Diese Ausgabe enthält keine Secrets und kann geteilt werden._"
