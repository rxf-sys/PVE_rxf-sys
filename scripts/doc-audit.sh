#!/usr/bin/env bash
# ==============================================================================
# doc-audit.sh — Read-only Inventar- & Best-Practice-Audit für rxf-sys
# ------------------------------------------------------------------------------
# Sammelt auf dem Proxmox-Host alle Fakten, die zum Abgleich mit dieser
# Dokumentation nötig sind, und prüft gleichzeitig gängige Best-Practice-Regeln.
#
#   * READ-ONLY  — das Skript ändert nichts am System (keine Writes ausser der
#                  Report-Datei, kein systemctl start/stop, kein apt).
#   * REDACTED   — Passwörter, Tokens, API-Keys und JWTs werden vor dem
#                  Schreiben aus dem Report entfernt.
#
# Aufruf (als root auf dem PVE-Host):
#     ./doc-audit.sh                    # Report nach /root/audit-<datum>.md
#     ./doc-audit.sh --stdout           # Report nach stdout
#     ./doc-audit.sh -o /tmp/a.md       # eigener Pfad
#     ./doc-audit.sh --no-net           # keine HTTP-Checks (LAN + Public)
#     ./doc-audit.sh --no-guests        # kein pct/qm exec in die Guests
#
# Laufzeit: ca. 1–3 Minuten (abhängig von Guest-Exec und Netz-Checks).
# ==============================================================================

set -uo pipefail

VERSION="1.0.0"
NODE="$(hostname -s 2>/dev/null || hostname)"
STAMP="$(date -Iseconds)"
OUT="/root/audit-$(date +%F).md"
TO_STDOUT=0
DO_NET=1
DO_GUESTS=1
CMD_TIMEOUT=25

# ------------------------------------------------------------------------------
# Erwartete Endpunkte laut Dokumentation (README.md).
# Weichen diese ab, ist entweder der Dienst weg oder die Doku veraltet.
# ------------------------------------------------------------------------------
LAN_ENDPOINTS=(
  "PVE Web-UI|https://192.168.2.200:8006"
  "PBS Web-UI|https://192.168.2.209:8007"
  "Admin-Dashboard|http://192.168.2.202"
  "Vaultwarden|http://192.168.2.203:8081"
  "Uptime Kuma|http://192.168.2.204:3001"
  "Portainer|http://192.168.2.205:9000"
  "Immich|http://192.168.2.205:2283"
  "Jellyfin|http://192.168.2.207:8096"
  "Home Assistant|http://192.168.2.208:8123"
  "Portfolio|http://192.168.2.210"
  "Welcome-Page|http://192.168.2.211"
  "Webhooks|http://192.168.2.211:9000"
  "Orynthia|http://192.168.2.212"
)

PUBLIC_ENDPOINTS=(
  admin.rxf-sys.de
  ha.rxf-sys.de
  media.rxf-sys.de
  photos.rxf-sys.de
  monitor.rxf-sys.de
  vault.rxf-sys.de
  pbs.rxf-sys.de
  portfolio.rxf-sys.de
  pve.rxf-sys.de
  www.rxf-sys.de
  orynthia.rxf-sys.de
  hooks.rxf-sys.de
)

# ------------------------------------------------------------------------------
# Argumente
# ------------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    -o|--out)     OUT="${2:-}"; shift 2 ;;
    --stdout)     TO_STDOUT=1; shift ;;
    --no-net)     DO_NET=0; shift ;;
    --no-guests)  DO_GUESTS=0; shift ;;
    -h|--help)
      sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unbekannte Option: $1 (--help für Hilfe)" >&2; exit 2 ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "WARNUNG: Nicht als root — viele Abschnitte bleiben leer." >&2
fi

BODY="$(mktemp)"
PBS_LIST="$(mktemp)"
trap 'rm -f "$BODY" "$PBS_LIST"' EXIT

# ------------------------------------------------------------------------------
# Helfer
# ------------------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

h1() { printf '\n# %s\n\n' "$*"; }
h2() { printf '\n## %s\n\n' "$*"; }
h3() { printf '\n### %s\n\n' "$*"; }
note() { printf '%s\n\n' "$*"; }

# cmd "<shell>" ["<label>"] — führt aus, Ausgabe in Code-Fence
cmd() {
  local c="$1" label="${2:-$1}" rc=0 out
  printf '`$ %s`\n\n```\n' "$label"
  out="$(timeout "$CMD_TIMEOUT" bash -c "$c" 2>&1)" || rc=$?
  if [ -n "$out" ]; then printf '%s\n' "$out"; else printf '(keine Ausgabe)\n'; fi
  [ "$rc" -ne 0 ] && printf '[exit %s]\n' "$rc"
  printf '```\n\n'
}

# dumpfile <pfad> — Datei anzeigen, falls vorhanden
dumpfile() {
  local f="$1"
  printf '`%s`\n\n```\n' "$f"
  if [ -r "$f" ]; then
    cat "$f" 2>&1
  else
    printf '(nicht vorhanden oder nicht lesbar)\n'
  fi
  printf '```\n\n'
}

# ---- Best-Practice-Checks --------------------------------------------------
CHECK_ROWS=()
N_PASS=0; N_WARN=0; N_FAIL=0; N_INFO=0
chk() {  # chk <PASS|WARN|FAIL|INFO> "<Regel>" "<Befund>"
  CHECK_ROWS+=("| $1 | $2 | $3 |")
  case "$1" in
    PASS) N_PASS=$((N_PASS+1)) ;;
    WARN) N_WARN=$((N_WARN+1)) ;;
    FAIL) N_FAIL=$((N_FAIL+1)) ;;
    *)    N_INFO=$((N_INFO+1)) ;;
  esac
}

# Wie chk, aber nur wenn überhaupt Guests gefunden wurden — verhindert,
# dass leere Listen als "bestanden" durchgehen.
chk_g() { [ -n "$ALL_IDS" ] || return 0; chk "$@"; }

# Alter einer ISO-Zeitangabe in Tagen (leer -> "")
age_days() {
  local ts="$1" epoch now
  [ -z "$ts" ] && return 0
  epoch="$(date -d "$ts" +%s 2>/dev/null)" || return 0
  now="$(date +%s)"
  echo $(( (now - epoch) / 86400 ))
}

# Guest-Listen
CT_IDS="$(pct list 2>/dev/null | awk 'NR>1 {print $1}')"
VM_IDS="$(qm list 2>/dev/null | awk 'NR>1 {print $1}')"
ALL_IDS="$(printf '%s\n%s\n' "$CT_IDS" "$VM_IDS" | grep -E '^[0-9]+$' | sort -n)"

pct_val() { pct config "$1" 2>/dev/null | awk -v k="^$2:" '$0 ~ k {sub(/^[^:]*: */,""); print; exit}'; }
qm_val()  { qm  config "$1" 2>/dev/null | awk -v k="^$2:" '$0 ~ k {sub(/^[^:]*: */,""); print; exit}'; }

# IP aus net0-Zeile ziehen
net_ip() { echo "$1" | grep -oE 'ip=[0-9./]+' | head -1 | cut -d= -f2; }

# ==============================================================================
# DATENSAMMLUNG
# ==============================================================================
collect() {

# ---------------------------------------------------------------- 01 Hardware
h1 "01 — Hardware & Host"

cmd "hostnamectl" "hostnamectl"
cmd "pveversion -v" "pveversion -v"
cmd "uptime; echo; who -b" "uptime"
if have dmidecode; then
  cmd "dmidecode -s system-manufacturer; dmidecode -s system-product-name; dmidecode -s bios-version; dmidecode -s bios-release-date" "dmidecode (System/BIOS)"
fi
cmd "lscpu | grep -E 'Model name|^CPU\\(s\\)|Thread|Core\\(s\\)|Socket|MHz|Virtualization|Flags' | head -20" "lscpu"
cmd "free -h" "free -h"
cmd "cat /proc/meminfo | grep -E 'MemTotal|SwapTotal|Hugepage'" "meminfo"
cmd "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,ROTA,TRAN" "lsblk"
if have mokutil; then cmd "mokutil --sb-state" "Secure Boot"; fi
cmd "cat /proc/cmdline" "Kernel-Cmdline"
cmd "lspci -nn | grep -iE 'vga|display|ethernet|nvme|sata'" "lspci (relevant)"
cmd "ls -l /dev/dri 2>/dev/null" "GPU-Devices (/dev/dri)"

h2 "SMART"
if have smartctl; then
  for dev in $(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}'); do
    h3 "/dev/$dev"
    cmd "smartctl -H -i /dev/$dev | grep -iE 'Model|Serial|Capacity|Firmware|health|SMART support' | sed 's/\\(Serial Number:\\s*\\).*/\\1<REDACTED>/I'" "smartctl -H -i /dev/$dev"
    cmd "smartctl -A /dev/$dev | grep -iE 'Power_On_Hours|Power_Cycle|Wear_Leveling|Percentage Used|Temperature|Media_Wearout|Total_LBAs_Written|Data Units Written|Available Spare|Reallocated|Pending|Uncorrect|Error' | head -20" "smartctl -A /dev/$dev"
    cmd "smartctl -l selftest /dev/$dev | head -8" "Selftest-Log /dev/$dev"
  done
else
  note "_smartctl nicht installiert (\`apt install smartmontools\`)._"
fi

# ------------------------------------------------------------ 02 Installation
h1 "02 — Installation, Repos & Updates"

cmd "ls -la /etc/apt/sources.list.d/ 2>/dev/null; echo; cat /etc/apt/sources.list 2>/dev/null" "APT sources"
cmd "grep -rsE '^[^#]*(deb|Types|URIs)' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null" "Aktive Repo-Einträge"
cmd "apt list --upgradable 2>/dev/null | grep -v '^Listing'" "apt list --upgradable"
cmd "dpkg -l 'proxmox-kernel-*' 2>/dev/null | awk '/^ii/{print \$2, \$3}'" "Installierte Kernel"
cmd "uname -r" "Laufender Kernel"
cmd "ls -la /var/run/reboot-required* 2>/dev/null || echo 'kein reboot-required Flag'" "Reboot-Flag"
cmd "systemctl is-enabled unattended-upgrades 2>/dev/null; cat /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null" "Unattended-Upgrades"
cmd "ls -la /etc/apt/apt.conf.d/ | grep -iE 'no-nag|pve'" "Nag-Patch dpkg-Hook"
cmd "grep -c 'data.status.toLowerCase() !== .active.' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js 2>/dev/null || echo 'Muster nicht gefunden (Patch bereits aktiv oder Datei geändert)'" "Nag-Patch Status"
cmd "pvesubscription get 2>/dev/null | grep -vi key" "Subscription-Status"

# ---------------------------------------------------------------- 03 Netzwerk
h1 "03 — Netzwerk"

cmd "ip -br addr" "ip -br addr"
cmd "ip route" "ip route"
dumpfile /etc/network/interfaces
dumpfile /etc/hosts
dumpfile /etc/resolv.conf
cmd "bridge link 2>/dev/null" "bridge link"
cmd "ss -tulpnH | sort -k5 | sed 's/users:((\\(\"[^\"]*\"\\).*/users:(\\1)/'" "Offene Ports auf dem Host"
cmd "cat /proc/sys/net/ipv4/ip_forward; sysctl -a 2>/dev/null | grep -E 'net.ipv4.ip_forward|net.bridge.bridge-nf' | head" "Forwarding/Bridge-Sysctls"

if [ "$DO_NET" -eq 1 ] && have curl; then
  h2 "Erreichbarkeit LAN-Endpunkte (laut Doku)"
  printf '| Dienst | URL | HTTP |\n|---|---|---|\n'
  for e in "${LAN_ENDPOINTS[@]}"; do
    name="${e%%|*}"; url="${e##*|}"
    code="$(curl -k -s -m 6 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)"
    [ -z "$code" ] || [ "$code" = "000" ] && code="unreachable"
    printf '| %s | %s | %s |\n' "$name" "$url" "$code"
  done
  printf '\n'

  h2 "Erreichbarkeit Public-Hostnames (Cloudflare Tunnel)"
  printf '| Hostname | HTTP | CF-Ray vorhanden |\n|---|---|---|\n'
  for hn in "${PUBLIC_ENDPOINTS[@]}"; do
    hdr="$(curl -s -m 8 -o /dev/null -D - "https://$hn" 2>/dev/null)"
    code="$(printf '%s' "$hdr" | awk '/^HTTP/{c=$2} END{print c}')"
    ray="$(printf '%s' "$hdr" | grep -ic '^cf-ray' 2>/dev/null || echo 0)"
    [ -z "$code" ] && code="unreachable"
    printf '| %s | %s | %s |\n' "$hn" "$code" "$([ "$ray" -gt 0 ] && echo ja || echo nein)"
  done
  printf '\n'
fi

# ----------------------------------------------------------------- 04 Storage
h1 "04 — Storage"

cmd "pvesm status" "pvesm status"
cmd "df -hT | grep -vE 'tmpfs|udev|efivarfs|fuse'" "df -hT"
cmd "vgs; echo; lvs -o lv_name,vg_name,lv_size,data_percent,metadata_percent,lv_attr; echo; pvs" "LVM"
cmd "findmnt -t ext4,xfs,vfat,btrfs -o TARGET,SOURCE,FSTYPE,OPTIONS" "Mounts"
dumpfile /etc/fstab
dumpfile /etc/pve/storage.cfg
cmd "ls -la /mnt/ 2>/dev/null; echo; ls -la /mnt/storage/ 2>/dev/null" "/mnt"
cmd "du -sh --max-depth=1 /mnt/storage 2>/dev/null | sort -h" "Belegung /mnt/storage"
cmd "systemctl status fstrim.timer --no-pager 2>/dev/null | head -5" "fstrim.timer"
cmd "pvesm list local-lvm 2>/dev/null; echo; pvesm list local 2>/dev/null" "Volumes local/local-lvm"

# --------------------------------------------------------------- 05 Container
h1 "05 — Container & VMs"

cmd "pct list" "pct list"
cmd "qm list" "qm list"

h2 "Guest-Übersicht (Ist-Zustand)"
printf '| ID | Typ | Name | IP | RAM (MB) | Cores | Disk | onboot | unpriv | Features | FW | Tags | Status |\n'
printf '|---|---|---|---|---|---|---|---|---|---|---|---|---|\n'
for id in $CT_IDS; do
  cfg="$(pct config "$id" 2>/dev/null)"
  name="$(printf '%s' "$cfg" | awk '/^hostname:/{print $2}')"
  mem="$(printf '%s' "$cfg" | awk '/^memory:/{print $2}')"
  cores="$(printf '%s' "$cfg" | awk '/^cores:/{print $2}')"
  rootfs="$(printf '%s' "$cfg" | awk '/^rootfs:/{sub(/^rootfs: */,""); print}')"
  disk="$(printf '%s' "$rootfs" | grep -oE 'size=[^,]+' | cut -d= -f2)"
  net0="$(printf '%s' "$cfg" | awk '/^net0:/{sub(/^net0: */,""); print}')"
  ip="$(net_ip "$net0")"
  fw="$(printf '%s' "$net0" | grep -oE 'firewall=[01]' | cut -d= -f2)"
  onboot="$(printf '%s' "$cfg" | awk '/^onboot:/{print $2}')"
  unpriv="$(printf '%s' "$cfg" | awk '/^unprivileged:/{print $2}')"
  feat="$(printf '%s' "$cfg" | awk '/^features:/{sub(/^features: */,""); print}')"
  tags="$(printf '%s' "$cfg" | awk '/^tags:/{sub(/^tags: */,""); print}')"
  st="$(pct status "$id" 2>/dev/null | awk '{print $2}')"
  printf '| %s | LXC | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n' \
    "$id" "${name:--}" "${ip:--}" "${mem:--}" "${cores:--}" "${disk:--}" \
    "${onboot:-0}" "${unpriv:-0}" "${feat:--}" "${fw:--}" "${tags:--}" "${st:--}"
done
for id in $VM_IDS; do
  cfg="$(qm config "$id" 2>/dev/null)"
  name="$(printf '%s' "$cfg" | awk '/^name:/{print $2}')"
  mem="$(printf '%s' "$cfg" | awk '/^memory:/{print $2}')"
  cores="$(printf '%s' "$cfg" | awk '/^cores:/{print $2}')"
  disk="$(printf '%s' "$cfg" | grep -oE '(scsi|virtio|sata|ide)[0-9]+: [^,]+,?.*size=[^,]+' | grep -oE 'size=[^,]+' | cut -d= -f2 | paste -sd'+' -)"
  net0="$(printf '%s' "$cfg" | awk '/^net0:/{sub(/^net0: */,""); print}')"
  fw="$(printf '%s' "$net0" | grep -oE 'firewall=[01]' | cut -d= -f2)"
  onboot="$(printf '%s' "$cfg" | awk '/^onboot:/{print $2}')"
  tags="$(printf '%s' "$cfg" | awk '/^tags:/{sub(/^tags: */,""); print}')"
  st="$(qm status "$id" 2>/dev/null | awk '{print $2}')"
  ip=""
  if [ "$st" = "running" ]; then
    ip="$(timeout 8 qm agent "$id" network-get-interfaces 2>/dev/null \
          | grep -oE '"ip-address" : "192\.168\.[0-9.]+"' | head -1 | grep -oE '192\.168\.[0-9.]+')"
  fi
  printf '| %s | VM | %s | %s | %s | %s | %s | %s | - | - | %s | %s | %s |\n' \
    "$id" "${name:--}" "${ip:--}" "${mem:--}" "${cores:--}" "${disk:--}" \
    "${onboot:-0}" "${fw:--}" "${tags:--}" "${st:--}"
done
printf '\n'

h2 "Volle Guest-Configs"
for id in $CT_IDS; do
  h3 "CT $id"
  cmd "pct config $id" "pct config $id"
done
for id in $VM_IDS; do
  h3 "VM $id"
  cmd "qm config $id" "qm config $id"
done

if [ "$DO_GUESTS" -eq 1 ]; then
  h2 "Innensicht der laufenden Container"
  for id in $CT_IDS; do
    st="$(pct status "$id" 2>/dev/null | awk '{print $2}')"
    [ "$st" = "running" ] || { h3 "CT $id — $st (übersprungen)"; continue; }
    h3 "CT $id"
    cmd "pct exec $id -- bash -lc 'grep PRETTY_NAME /etc/os-release; uptime; echo; echo \"-- upgradable:\"; apt list --upgradable 2>/dev/null | grep -v Listing | wc -l; echo \"-- failed units:\"; systemctl --failed --no-legend 2>/dev/null; echo \"-- disk:\"; df -h / | tail -1'" "CT $id — OS/Updates/Health"
    cmd "pct exec $id -- bash -lc 'command -v docker >/dev/null && docker ps --format \"{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}\" || echo \"kein Docker\"'" "CT $id — Docker-Container"
    cmd "pct exec $id -- bash -lc 'ss -tulpnH 2>/dev/null | awk \"{print \\\$1, \\\$5}\" | sort -u | head -25'" "CT $id — Listening Ports"
  done

  h2 "Innensicht der VMs (Guest-Agent)"
  for id in $VM_IDS; do
    st="$(qm status "$id" 2>/dev/null | awk '{print $2}')"
    [ "$st" = "running" ] || { h3 "VM $id — $st (übersprungen)"; continue; }
    h3 "VM $id"
    cmd "timeout 10 qm agent $id ping >/dev/null 2>&1 && echo 'guest-agent: OK' || echo 'guest-agent: nicht erreichbar'" "VM $id — Agent"
  done
fi

# ------------------------------------------------------------------ 06 Backup
h1 "06 — Backup"

dumpfile /etc/pve/jobs.cfg
dumpfile /etc/vzdump.conf
cmd "pvesm status | grep -iE 'pbs|Name'" "PBS-Storage-Status"

pvesm list pbs > "$PBS_LIST" 2>/dev/null
h2 "Letztes Backup je Guest (aus PBS-Datastore)"
printf '| Guest | Typ | Letztes Backup | Alter (Tage) | Snapshots gesamt |\n|---|---|---|---|---|\n'
for id in $ALL_IDS; do
  last="$(awk -v id="$id" '{split($1,a,"/"); if (a[3]==id) print a[4]}' "$PBS_LIST" | sort | tail -1)"
  typ="$(awk -v id="$id" '{split($1,a,"/"); if (a[3]==id) {print a[2]; exit}}' "$PBS_LIST")"
  cnt="$(awk -v id="$id" '{split($1,a,"/"); if (a[3]==id) c++} END{print c+0}' "$PBS_LIST")"
  agev="$(age_days "$last")"
  printf '| %s | %s | %s | %s | %s |\n' "$id" "${typ:--}" "${last:-KEIN BACKUP}" "${agev:--}" "$cnt"
done
printf '\n'

cmd "wc -l < '$PBS_LIST'" "Snapshots im PBS-Datastore (Zeilen)"
cmd "pvesh get /nodes/$NODE/tasks --limit 25 --typefilter vzdump 2>/dev/null" "Letzte vzdump-Tasks"
cmd "systemctl list-timers --all 2>/dev/null | grep -iE 'backup-host-config|NEXT' " "Host-Config-Backup-Timer"
cmd "systemctl status backup-host-config.service --no-pager 2>/dev/null | head -12" "backup-host-config.service"
cmd "systemctl status backup-host-config-pbs.service --no-pager 2>/dev/null | head -12" "backup-host-config-pbs.service"
cmd "ls -lah /mnt/storage/host-configs/ 2>/dev/null | tail -12" "Host-Config-Backups"
cmd "ls -l /usr/local/sbin/ 2>/dev/null" "Skripte in /usr/local/sbin"

h2 "PBS-VM (201) — GC / Prune / Verify"
cmd "timeout 20 qm guest exec 201 -- proxmox-backup-manager datastore list 2>/dev/null" "PBS datastore list"
cmd "timeout 20 qm guest exec 201 -- proxmox-backup-manager garbage-collection list 2>/dev/null" "PBS GC-Jobs"
cmd "timeout 20 qm guest exec 201 -- proxmox-backup-manager prune-job list 2>/dev/null" "PBS Prune-Jobs"
cmd "timeout 20 qm guest exec 201 -- proxmox-backup-manager verify-job list 2>/dev/null" "PBS Verify-Jobs"
cmd "timeout 20 qm guest exec 201 -- df -h 2>/dev/null" "PBS Disk-Belegung"

# -------------------------------------------------------------- 07 Monitoring
h1 "07 — Monitoring & Notifications"

dumpfile /etc/pve/notifications.cfg
cmd "grep -oE '^[a-z-]+:|^\\s+(comment|mailto|mode|origin|server|from-address|username|target|matcher-field|matcher-severity)' /etc/pve/priv/notifications.cfg 2>/dev/null" "priv/notifications.cfg (nur Schlüssel)"
cmd "pvesh get /cluster/notifications/endpoints 2>/dev/null" "Notification-Endpoints"
cmd "pvesh get /cluster/notifications/matchers 2>/dev/null" "Notification-Matcher"
cmd "journalctl -u pvescheduler --since '7 days ago' --no-pager 2>/dev/null | grep -iE 'error|fail|notif' | tail -15" "pvescheduler — Fehler letzte 7 Tage"
cmd "journalctl --since '7 days ago' --no-pager 2>/dev/null | grep -iE 'smtp|sendmail|postfix' | tail -15" "Mail-Versand letzte 7 Tage"

# --------------------------------------------------------------- 08 Sicherheit
h1 "08 — Sicherheit"

cmd "pve-firewall status" "pve-firewall status"
dumpfile /etc/pve/firewall/cluster.fw
dumpfile "/etc/pve/nodes/$NODE/host.fw"
h2 "Guest-Firewall-Regeln"
for f in /etc/pve/firewall/*.fw; do
  case "$f" in */cluster.fw) continue ;; esac
  dumpfile "$f"
done
cmd "iptables -L PVEFW-HOST-IN -n -v 2>/dev/null | head -25" "PVEFW-HOST-IN"
cmd "iptables -L -n 2>/dev/null | grep -c '^' " "iptables Regelzeilen gesamt"

h2 "SSH"
cmd "sshd -T 2>/dev/null | grep -iE '^(port|listenaddress|permitrootlogin|passwordauthentication|pubkeyauthentication|permitemptypasswords|maxauthtries|x11forwarding|allowusers|allowgroups|kbdinteractiveauthentication)' | sort" "sshd effektive Config"
cmd "ls -lL /root/.ssh/authorized_keys 2>/dev/null; awk 'NF>=2 {print \$1, (NF>2 ? \$NF : \"(kein Kommentar)\")}' /root/.ssh/authorized_keys 2>/dev/null" "authorized_keys (nur Typ + Kommentar, kein Key-Material)"

h2 "fail2ban"
cmd "systemctl is-active fail2ban; fail2ban-client status 2>/dev/null" "fail2ban status"
cmd "for j in \$(fail2ban-client status 2>/dev/null | awk -F: '/Jail list/{print \$2}' | tr -d ' ' | tr ',' ' '); do echo \"--- \$j\"; fail2ban-client status \$j 2>/dev/null; done" "fail2ban Jails"

h2 "Benutzer, Tokens & Rechte"
cmd "pveum user list 2>/dev/null" "pveum user list"
cmd "for u in \$(pveum user list 2>/dev/null | awk -F'│' 'NR>2 {gsub(/ /,\"\",\$2); if (\$2 ~ /@/) print \$2}'); do echo \"--- \$u\"; pveum user token list \$u 2>/dev/null; done" "API-Tokens je User"
cmd "pveum acl list 2>/dev/null" "pveum acl list"
cmd "grep -c 'totp\\|^tfa' /etc/pve/user.cfg 2>/dev/null; grep -oE '^user:[^:]*' /etc/pve/user.cfg 2>/dev/null" "2FA / user.cfg (Auszug)"
cmd "openssl x509 -noout -subject -enddate -in /etc/pve/local/pve-ssl.pem 2>/dev/null" "PVE-Zertifikat"

h2 "Härtung allgemein"
cmd "aa-status 2>/dev/null | grep -E 'module is loaded|profiles are loaded|enforce mode|complain mode'" "AppArmor"
cmd "sysctl kernel.dmesg_restrict kernel.kptr_restrict fs.protected_hardlinks fs.protected_symlinks net.ipv4.conf.all.rp_filter 2>/dev/null" "Kernel-Härtung (Sysctls)"
cmd "last -n 12 2>/dev/null" "Letzte Logins"
cmd "lastb -n 10 2>/dev/null | head -12 || echo '(btmp nicht vorhanden)'" "Fehlgeschlagene Logins"
cmd "journalctl -u ssh -u sshd --since '7 days ago' --no-pager 2>/dev/null | grep -ciE 'failed password|invalid user' || true" "SSH-Fehlversuche (7 Tage, Anzahl)"

# ----------------------------------------------------------------- 09 Wartung
h1 "09 — Wartung & Systemzustand"

cmd "systemctl --failed --no-legend" "Failed Units"
cmd "systemctl list-timers --all --no-pager 2>/dev/null" "Alle Timer"
cmd "timedatectl" "timedatectl"
cmd "systemctl is-active chrony chronyd systemd-timesyncd 2>/dev/null" "Zeitsynchronisation"
cmd "journalctl -p err -b --no-pager 2>/dev/null | tail -40" "Fehler seit Boot (journal, err)"
cmd "dmesg --level=err,crit,alert,emerg 2>/dev/null | tail -25" "dmesg Fehler"
cmd "journalctl --disk-usage 2>/dev/null; grep -E '^[^#]*(SystemMaxUse|Storage)' /etc/systemd/journald.conf 2>/dev/null || echo '(kein SystemMaxUse gesetzt — Journal waechst unbegrenzt bis 10% der Partition)'" "Journald"
cmd "cat /proc/pressure/cpu /proc/pressure/io /proc/pressure/memory 2>/dev/null" "PSI (Pressure Stall Info)"
cmd "sysctl vm.swappiness; swapon --show 2>/dev/null" "Swap"
cmd "sensors 2>/dev/null | head -20 || echo '(lm-sensors nicht installiert)'" "Temperaturen"

# -------------------------------------------------------- 10 Disaster Recovery
h1 "10 — Disaster Recovery"

cmd "ls -la /etc/pve/ 2>/dev/null" "/etc/pve"
cmd "pvecm status 2>/dev/null || echo '(kein Cluster — Standalone)'" "Cluster-Status"
cmd "ls -la /var/lib/pve-cluster/ 2>/dev/null" "pve-cluster DB"
cmd "efibootmgr -v 2>/dev/null | head -10 || echo '(efibootmgr nicht installiert)'" "EFI-Booteinträge"
cmd "proxmox-boot-tool status 2>/dev/null || echo '(proxmox-boot-tool nicht aktiv)'" "proxmox-boot-tool"

}

# ==============================================================================
# BEST-PRACTICE-CHECKS
# ==============================================================================
run_checks() {

  # --- Plausibilität der Datenbasis ----------------------------------------
  # Ohne diese Vorbedingungen wären viele Checks "leer bestanden".
  if have pveversion; then
    chk PASS "Läuft auf einem Proxmox-Host" "$(pveversion 2>/dev/null | head -1)"
  else
    chk FAIL "Läuft auf einem Proxmox-Host" "pveversion nicht gefunden — Report unbrauchbar, Skript auf dem PVE-Host ausführen"
  fi
  if [ -n "$ALL_IDS" ]; then
    chk INFO "Gefundene Guests" "$(echo "$CT_IDS" | grep -c .) LXC + $(echo "$VM_IDS" | grep -c .) VM"
  else
    chk FAIL "Gefundene Guests" "keine — pct/qm liefern nichts"
  fi

  # --- Repos / Updates ------------------------------------------------------
  local ent nosub upg
  ent="$(grep -slE '^[^#]*enterprise\.proxmox\.com' /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null | tr '\n' ' ')"
  if [ -n "$ent" ]; then
    chk WARN "Enterprise-Repo deaktiviert" "aktiv in: $ent — ohne Subscription schlägt apt update fehl"
  else
    chk PASS "Enterprise-Repo deaktiviert" "kein aktiver Enterprise-Eintrag"
  fi
  nosub="$(grep -slE '^[^#]*(pve-no-subscription|no-subscription)' /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null | head -1)"
  [ -n "$nosub" ] && chk PASS "No-Subscription-Repo konfiguriert" "$nosub" \
                  || chk WARN "No-Subscription-Repo konfiguriert" "nicht gefunden — keine Updates?"

  upg="$(apt list --upgradable 2>/dev/null | grep -vc '^Listing')"
  upg="${upg:-0}"
  if   [ "$upg" -eq 0 ];  then chk PASS "Host aktuell" "0 ausstehende Pakete"
  elif [ "$upg" -le 15 ]; then chk WARN "Host aktuell" "$upg ausstehende Pakete"
  else                         chk FAIL "Host aktuell" "$upg ausstehende Pakete — Update überfällig"
  fi

  # --- Kernel / Reboot ------------------------------------------------------
  local running newest
  running="$(uname -r)"
  newest="$(dpkg -l 'proxmox-kernel-*-pve*' 2>/dev/null | awk '/^ii/{print $2}' \
            | sed -e 's/^proxmox-kernel-//' -e 's/-signed$//' | sort -V -u | tail -1)"
  if [ -n "$newest" ] && [ "$running" != "$newest" ]; then
    chk WARN "Neuester Kernel aktiv" "läuft $running, installiert ist $newest — Reboot ausstehend"
  else
    chk PASS "Neuester Kernel aktiv" "$running"
  fi
  [ -e /var/run/reboot-required ] && chk WARN "Kein Reboot ausstehend" "/var/run/reboot-required vorhanden" \
                                  || chk PASS "Kein Reboot ausstehend" "-"

  # --- Systemzustand --------------------------------------------------------
  local failed
  failed="$(systemctl --failed --no-legend 2>/dev/null | wc -l)"
  [ "$failed" -eq 0 ] && chk PASS "Keine failed Units" "0" \
                      || chk FAIL "Keine failed Units" "$failed: $(systemctl --failed --no-legend 2>/dev/null | awk '{print $1}' | paste -sd, -)"

  # --- Speicherplatz --------------------------------------------------------
  local rootpct
  rootpct="$(df --output=pcent / 2>/dev/null | tail -1 | tr -dc '0-9')"
  if   [ "${rootpct:-0}" -lt 75 ]; then chk PASS "Root-FS < 75% belegt" "${rootpct}%"
  elif [ "${rootpct:-0}" -lt 90 ]; then chk WARN "Root-FS < 75% belegt" "${rootpct}%"
  else                                  chk FAIL "Root-FS < 75% belegt" "${rootpct}% — kritisch"
  fi

  local thin
  thin="$(lvs --noheadings -o data_percent pve/data 2>/dev/null | tr -d ' %' | cut -d. -f1)"
  if [ -n "$thin" ]; then
    if   [ "$thin" -lt 75 ]; then chk PASS "Thin-Pool local-lvm < 75%" "${thin}%"
    elif [ "$thin" -lt 90 ]; then chk WARN "Thin-Pool local-lvm < 75%" "${thin}% — Snapshots/Backups prüfen"
    else                          chk FAIL "Thin-Pool local-lvm < 75%" "${thin}% — Überlauf droht (Pool wird read-only)"
    fi
  fi

  local metap
  metap="$(lvs --noheadings -o metadata_percent pve/data 2>/dev/null | tr -d ' %' | cut -d. -f1)"
  if [ -n "$metap" ]; then
    [ "$metap" -lt 80 ] && chk PASS "Thin-Pool Metadata < 80%" "${metap}%" \
                        || chk FAIL "Thin-Pool Metadata < 80%" "${metap}% — Pool kann korrupt werden"
  fi

  local stopct
  stopct="$(df --output=pcent /mnt/storage 2>/dev/null | tail -1 | tr -dc '0-9')"
  if [ -n "$stopct" ]; then
    if   [ "$stopct" -lt 80 ]; then chk PASS "/mnt/storage < 80% belegt" "${stopct}%"
    elif [ "$stopct" -lt 92 ]; then chk WARN "/mnt/storage < 80% belegt" "${stopct}%"
    else                            chk FAIL "/mnt/storage < 80% belegt" "${stopct}%"
    fi
  fi

  # --- SMART ----------------------------------------------------------------
  if have smartctl; then
    local bad="" dev st
    for dev in $(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}'); do
      st="$(smartctl -H "/dev/$dev" 2>/dev/null | grep -iE 'overall-health|SMART Health Status' | awk '{print $NF}')"
      case "$st" in PASSED|OK) ;; *) bad="$bad $dev(${st:-?})" ;; esac
    done
    [ -z "$bad" ] && chk PASS "SMART-Health aller Disks OK" "alle PASSED" \
                  || chk FAIL "SMART-Health aller Disks OK" "Auffällig:$bad"

    local wear
    wear="$(smartctl -A /dev/nvme0n1 2>/dev/null | awk -F: '/Percentage Used/{gsub(/[ %]/,"",$2); print $2}')"
    if [ -n "$wear" ]; then
      if   [ "$wear" -lt 50 ]; then chk PASS "NVMe-Abnutzung < 50%" "${wear}%"
      elif [ "$wear" -lt 80 ]; then chk WARN "NVMe-Abnutzung < 50%" "${wear}%"
      else                          chk FAIL "NVMe-Abnutzung < 50%" "${wear}% — Ersatz planen"
      fi
    fi
  else
    chk WARN "SMART-Überwachung verfügbar" "smartmontools nicht installiert"
  fi

  # --- Firewall -------------------------------------------------------------
  local fwstat cl_en cl_pol host_en
  fwstat="$(pve-firewall status 2>/dev/null | head -1)"
  case "$fwstat" in
    *enabled*|*running*) chk PASS "PVE-Firewall aktiv" "$fwstat" ;;
    *)                   chk FAIL "PVE-Firewall aktiv" "${fwstat:-unbekannt}" ;;
  esac

  cl_en="$(awk -F: '/^enable:/{gsub(/ /,"",$2); print $2; exit}' /etc/pve/firewall/cluster.fw 2>/dev/null)"
  cl_pol="$(awk -F: '/^policy_in:/{gsub(/ /,"",$2); print $2; exit}' /etc/pve/firewall/cluster.fw 2>/dev/null)"
  [ "$cl_en" = "1" ] && chk PASS "Cluster-Firewall enabled" "enable: 1" \
                     || chk FAIL "Cluster-Firewall enabled" "enable: ${cl_en:-nicht gesetzt}"
  [ "$cl_pol" = "DROP" ] && chk PASS "Default-Policy IN = DROP" "$cl_pol" \
                         || chk FAIL "Default-Policy IN = DROP" "${cl_pol:-ACCEPT (Default)} — alles offen"

  host_en="$(awk -F: '/^enable:/{gsub(/ /,"",$2); print $2; exit}' "/etc/pve/nodes/$NODE/host.fw" 2>/dev/null)"
  [ "$host_en" = "1" ] && chk PASS "Host-Firewall enabled" "enable: 1" \
                       || chk WARN "Host-Firewall enabled" "enable: ${host_en:-nicht gesetzt}"

  local nofw=""
  for id in $CT_IDS; do
    case "$(pct config "$id" 2>/dev/null | awk '/^net0:/{print}')" in
      *firewall=1*) ;;
      *) nofw="$nofw $id" ;;
    esac
  done
  for id in $VM_IDS; do
    case "$(qm config "$id" 2>/dev/null | awk '/^net0:/{print}')" in
      *firewall=1*) ;;
      *) nofw="$nofw $id" ;;
    esac
  done
  [ -z "$nofw" ] && chk_g PASS "Firewall auf allen Guest-NICs aktiv" "alle Guests firewall=1" \
                 || chk_g WARN "Firewall auf allen Guest-NICs aktiv" "ohne firewall=1:$nofw"

  local guestfw
  guestfw="$(ls /etc/pve/firewall/*.fw 2>/dev/null | grep -vc cluster.fw)"
  chk INFO "Guest-Firewall-Regelsätze" "${guestfw:-0} .fw-Dateien vorhanden"

  # Ein fehlender oder nicht aktivierter Regelsatz heisst: der Guest laeuft
  # ungefiltert, auch wenn firewall=1 an der NIC steht.
  local nofile="" noenable=""
  for id in $ALL_IDS; do
    if [ ! -r "/etc/pve/firewall/$id.fw" ]; then
      nofile="$nofile $id"
    elif [ "$(awk -F: '/^enable:/{gsub(/ /,"",$2); print $2; exit}' "/etc/pve/firewall/$id.fw" 2>/dev/null)" != "1" ]; then
      noenable="$noenable $id"
    fi
  done
  [ -z "$nofile" ] && chk_g PASS "Regelsatz je Guest vorhanden" "alle Guests haben eine .fw" \
                   || chk_g WARN "Regelsatz je Guest vorhanden" "ohne .fw:$nofile — nur Cluster-Policy greift"
  [ -z "$noenable" ] && chk_g PASS "Guest-Regelsätze aktiviert" "alle mit enable: 1" \
                     || chk_g WARN "Guest-Regelsätze aktiviert" "ohne enable: 1:$noenable — Regeln ohne Wirkung"

  # --- fail2ban -------------------------------------------------------------
  if systemctl is-active --quiet fail2ban 2>/dev/null; then
    chk PASS "fail2ban aktiv" "$(fail2ban-client status 2>/dev/null | awk -F: '/Jail list/{print "Jails:"$2}')"
  else
    chk WARN "fail2ban aktiv" "nicht aktiv"
  fi

  # --- SSH ------------------------------------------------------------------
  local prl pwa pka
  prl="$(sshd -T 2>/dev/null | awk '/^permitrootlogin/{print $2}')"
  pwa="$(sshd -T 2>/dev/null | awk '/^passwordauthentication/{print $2}')"
  pka="$(sshd -T 2>/dev/null | awk '/^pubkeyauthentication/{print $2}')"
  if [ "$pwa" = "no" ]; then
    chk PASS "SSH Passwort-Auth deaktiviert" "passwordauthentication no"
  else
    chk WARN "SSH Passwort-Auth deaktiviert" "passwordauthentication ${pwa:-?} — laut Doku bewusste Abweichung (LAN-only)"
  fi
  case "$prl" in
    no|prohibit-password) chk PASS "SSH Root-Login eingeschränkt" "permitrootlogin $prl" ;;
    *)                    chk WARN "SSH Root-Login eingeschränkt" "permitrootlogin ${prl:-?} — laut Doku bewusste Abweichung" ;;
  esac
  [ "$pka" = "yes" ] && chk PASS "SSH Pubkey-Auth aktiv" "yes" \
                     || chk WARN "SSH Pubkey-Auth aktiv" "${pka:-?}"

  # --- Backup ---------------------------------------------------------------
  local jobs_en excl
  jobs_en="$(awk '/^vzdump:/{j=1} j && /^[[:space:]]*enabled/{print $2; exit}' /etc/pve/jobs.cfg 2>/dev/null)"
  if [ ! -r /etc/pve/jobs.cfg ] || ! grep -q '^vzdump:' /etc/pve/jobs.cfg 2>/dev/null; then
    chk FAIL "vzdump-Job vorhanden" "kein vzdump-Job in /etc/pve/jobs.cfg"
  elif [ "${jobs_en:-1}" = "1" ]; then
    chk PASS "vzdump-Job aktiviert" "enabled 1, schedule $(awk '/^[[:space:]]*schedule/{print $2; exit}' /etc/pve/jobs.cfg 2>/dev/null)"
  else
    chk FAIL "vzdump-Job aktiviert" "enabled $jobs_en"
  fi
  excl="$(awk '/^[[:space:]]*exclude /{sub(/^[[:space:]]*exclude /,""); print}' /etc/pve/jobs.cfg 2>/dev/null | tr '\n' ' ')"
  [ -n "$excl" ] && chk INFO "Vom Backup ausgeschlossen" "$excl"

  local nobk="" old="" a l
  for id in $ALL_IDS; do
    case " $excl " in *" $id "*) continue ;; esac
    l="$(awk -v id="$id" '{split($1,a,"/"); if (a[3]==id) print a[4]}' "$PBS_LIST" | sort | tail -1)"
    if [ -z "$l" ]; then nobk="$nobk $id"; continue; fi
    a="$(age_days "$l")"
    [ -n "$a" ] && [ "$a" -gt 3 ] && old="$old $id(${a}d)"
  done
  [ -z "$nobk" ] && chk_g PASS "Jeder Guest hat ein Backup" "alle abgedeckt" \
                 || chk_g FAIL "Jeder Guest hat ein Backup" "ohne Backup:$nobk"
  [ -z "$old" ] && chk_g PASS "Backups jünger als 3 Tage" "alle aktuell" \
                || chk_g WARN "Backups jünger als 3 Tage" "veraltet:$old"

  local lasttask
  lasttask="$(pvesh get "/nodes/$NODE/tasks" --limit 10 --typefilter vzdump --output-format json 2>/dev/null \
              | grep -oE '"status":"[^"]*"' | head -1 | cut -d'"' -f4)"
  if [ -n "$lasttask" ]; then
    [ "$lasttask" = "OK" ] && chk PASS "Letzter vzdump-Task OK" "OK" \
                           || chk FAIL "Letzter vzdump-Task OK" "$lasttask"
  fi

  local pbsact
  pbsact="$(pvesm status 2>/dev/null | awk '$1=="pbs"{print $3}')"
  [ "$pbsact" = "active" ] && chk PASS "PBS-Storage erreichbar" "active" \
                           || chk FAIL "PBS-Storage erreichbar" "${pbsact:-nicht gefunden}"

  local hcfg hcage
  hcfg="$(ls -t /mnt/storage/host-configs/* 2>/dev/null | head -1)"
  if [ -n "$hcfg" ]; then
    hcage=$(( ( $(date +%s) - $(stat -c %Y "$hcfg") ) / 86400 ))
    [ "$hcage" -le 2 ] && chk PASS "Host-Config-Backup aktuell" "letztes vor ${hcage}d" \
                       || chk WARN "Host-Config-Backup aktuell" "letztes vor ${hcage}d — Timer prüfen"
  else
    chk FAIL "Host-Config-Backup aktuell" "keine Dateien in /mnt/storage/host-configs/"
  fi

  for t in backup-host-config.timer backup-host-config-pbs.timer; do
    systemctl is-active --quiet "$t" 2>/dev/null \
      && chk PASS "Timer $t aktiv" "active" \
      || chk WARN "Timer $t aktiv" "$(systemctl is-active "$t" 2>/dev/null || echo nicht_vorhanden)"
  done

  # --- Notifications --------------------------------------------------------
  local ep mt
  ep="$(grep -cE '^(smtp|sendmail|gotify|webhook):' /etc/pve/notifications.cfg 2>/dev/null)"
  mt="$(grep -cE '^matcher:' /etc/pve/notifications.cfg 2>/dev/null)"
  [ "${ep:-0}" -gt 0 ] && chk PASS "Notification-Endpoint konfiguriert" "$ep Endpoint(s)" \
                       || chk FAIL "Notification-Endpoint konfiguriert" "keiner — Backup-Fehler bleiben unbemerkt"
  [ "${mt:-0}" -gt 0 ] && chk PASS "Notification-Matcher konfiguriert" "$mt Matcher" \
                       || chk WARN "Notification-Matcher konfiguriert" "keiner"

  # --- Zeit / Trim ----------------------------------------------------------
  if timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes; then
    chk PASS "Zeit synchronisiert" "NTPSynchronized=yes"
  else
    chk WARN "Zeit synchronisiert" "NTP nicht synchron — bricht Backups/TOTP/Zertifikate"
  fi
  systemctl is-active --quiet fstrim.timer 2>/dev/null \
    && chk PASS "fstrim.timer aktiv" "active (SSD-Trim wöchentlich)" \
    || chk WARN "fstrim.timer aktiv" "inaktiv — SSD-Performance leidet langfristig"

  # --- Ressourcen -----------------------------------------------------------
  local sum=0 m ram_mb
  for id in $CT_IDS; do m="$(pct config "$id" 2>/dev/null | awk '/^memory:/{print $2}')"; sum=$((sum + ${m:-0})); done
  for id in $VM_IDS; do m="$(qm  config "$id" 2>/dev/null | awk '/^memory:/{print $2}')"; sum=$((sum + ${m:-0})); done
  ram_mb="$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)"
  if [ "$ram_mb" -gt 0 ] && [ -n "$ALL_IDS" ]; then
    local pct_ram=$(( sum * 100 / ram_mb ))
    if   [ "$pct_ram" -lt 80 ];  then chk PASS "RAM nicht überbucht" "${sum} MB zugewiesen / ${ram_mb} MB physisch (${pct_ram}%)"
    elif [ "$pct_ram" -lt 100 ]; then chk WARN "RAM nicht überbucht" "${sum}/${ram_mb} MB (${pct_ram}%) — wenig Reserve für den Host"
    else                              chk FAIL "RAM nicht überbucht" "${sum}/${ram_mb} MB (${pct_ram}%) — überbucht"
    fi
  fi

  local swapu
  swapu="$(free -m | awk '/^Swap:/{print $3}')"
  [ "${swapu:-0}" -lt 512 ] && chk PASS "Kaum Swap-Nutzung" "${swapu:-0} MB" \
                            || chk WARN "Kaum Swap-Nutzung" "${swapu} MB in Verwendung — RAM-Druck"

  # --- Container-Härtung ----------------------------------------------------
  local priv="" nest=""
  for id in $CT_IDS; do
    [ "$(pct config "$id" 2>/dev/null | awk '/^unprivileged:/{print $2}')" = "1" ] || priv="$priv $id"
    pct config "$id" 2>/dev/null | grep -q 'features:.*nesting=1' && nest="$nest $id"
  done
  [ -z "$priv" ] && chk_g PASS "Alle LXC unprivileged" "alle" \
                 || chk_g WARN "Alle LXC unprivileged" "privilegiert:$priv — nur wenn nötig (z.B. GPU-Passthrough)"
  [ -n "$nest" ] && chk INFO "nesting=1 aktiv" "$nest (nötig für Docker-in-LXC)"

  local noboot=""
  for id in $ALL_IDS; do
    local ob
    if echo "$CT_IDS" | grep -qx "$id"; then ob="$(pct config "$id" 2>/dev/null | awk '/^onboot:/{print $2}')"
    else ob="$(qm config "$id" 2>/dev/null | awk '/^onboot:/{print $2}')"; fi
    [ "${ob:-0}" = "1" ] || noboot="$noboot $id"
  done
  [ -z "$noboot" ] && chk_g PASS "Autostart (onboot) für alle Guests" "alle onboot=1" \
                   || chk_g WARN "Autostart (onboot) für alle Guests" "ohne onboot:$noboot — starten nach Reboot nicht"

  local noagent=""
  for id in $VM_IDS; do
    qm config "$id" 2>/dev/null | grep -qE '^agent: *1' || noagent="$noagent $id"
  done
  [ -z "$noagent" ] && chk_g PASS "QEMU-Guest-Agent auf allen VMs" "alle agent=1" \
                    || chk_g WARN "QEMU-Guest-Agent auf allen VMs" "ohne agent=1:$noagent — kein sauberer Shutdown/Snapshot"

  # --- Verwaiste Volumes ----------------------------------------------------
  local orphan=""
  for v in $(pvesm list local-lvm 2>/dev/null | awk 'NR>1{print $1}'); do
    local vid
    vid="$(echo "$v" | grep -oE 'vm-[0-9]+-' | grep -oE '[0-9]+')"
    [ -z "$vid" ] && continue
    echo "$ALL_IDS" | grep -qx "$vid" || orphan="$orphan $v"
  done
  [ -z "$orphan" ] && chk PASS "Keine verwaisten Volumes" "local-lvm sauber" \
                   || chk WARN "Keine verwaisten Volumes" "$orphan"

  # --- Zertifikat -----------------------------------------------------------
  local certend certdays
  certend="$(openssl x509 -noout -enddate -in /etc/pve/local/pve-ssl.pem 2>/dev/null | cut -d= -f2)"
  if [ -n "$certend" ]; then
    certdays=$(( ( $(date -d "$certend" +%s) - $(date +%s) ) / 86400 ))
    [ "$certdays" -gt 30 ] && chk PASS "PVE-Zertifikat gültig" "noch ${certdays} Tage" \
                           || chk WARN "PVE-Zertifikat gültig" "läuft in ${certdays} Tagen ab"
  fi

  # --- AppArmor -------------------------------------------------------------
  if aa-status --enabled 2>/dev/null; then
    chk PASS "AppArmor aktiv" "$(aa-status --profiled 2>/dev/null) Profile geladen"
  else
    chk WARN "AppArmor aktiv" "nicht aktiv — LXC-Isolation geschwächt"
  fi

  # --- Guest-Updates --------------------------------------------------------
  if [ "$DO_GUESTS" -eq 1 ]; then
    local stale=""
    for id in $CT_IDS; do
      [ "$(pct status "$id" 2>/dev/null | awk '{print $2}')" = "running" ] || continue
      local n
      n="$(timeout 30 pct exec "$id" -- bash -lc 'apt list --upgradable 2>/dev/null | grep -vc "^Listing"' 2>/dev/null | tr -dc '0-9')"
      [ -n "$n" ] && [ "$n" -gt 20 ] && stale="$stale $id($n)"
    done
    [ -z "$stale" ] && chk_g PASS "Container-Updates im Rahmen" "kein CT mit >20 offenen Paketen" \
                    || chk_g WARN "Container-Updates im Rahmen" "viele offene Pakete:$stale"
  fi

  # --- Endpunkte laut Doku --------------------------------------------------
  if [ "$DO_NET" -eq 1 ] && have curl; then
    local down=""
    for e in "${LAN_ENDPOINTS[@]}"; do
      local nm="${e%%|*}" url="${e##*|}" code
      code="$(curl -k -s -m 6 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)"
      [ "${code:-000}" = "000" ] && down="$down $nm"
    done
    [ -z "$down" ] && chk PASS "Alle dokumentierten LAN-Dienste erreichbar" "${#LAN_ENDPOINTS[@]} Endpunkte" \
                   || chk WARN "Alle dokumentierten LAN-Dienste erreichbar" "nicht erreichbar:$down (Dienst weg oder Doku veraltet)"

    local pdown=""
    for hn in "${PUBLIC_ENDPOINTS[@]}"; do
      local code
      code="$(curl -s -m 8 -o /dev/null -w '%{http_code}' "https://$hn" 2>/dev/null)"
      [ "${code:-000}" = "000" ] && pdown="$pdown $hn"
    done
    [ -z "$pdown" ] && chk PASS "Alle Public-Hostnames erreichbar" "${#PUBLIC_ENDPOINTS[@]} Hostnames über Tunnel" \
                    || chk WARN "Alle Public-Hostnames erreichbar" "nicht erreichbar:$pdown"
  fi
}

# ==============================================================================
# AUSFÜHRUNG
# ==============================================================================
echo "[*] Sammle Systemdaten ..." >&2
collect > "$BODY" 2>/dev/null
echo "[*] Prüfe Best-Practice-Regeln ..." >&2
run_checks
echo "[*] Schreibe Report ..." >&2

assemble() {
  cat <<EOF
# rxf-sys — Audit-Report

| | |
|---|---|
| **Node** | $NODE |
| **Erstellt** | $STAMP |
| **Skript** | doc-audit.sh v$VERSION |
| **PVE** | $(pveversion 2>/dev/null | head -1) |
| **Kernel** | $(uname -r) |
| **Uptime** | $(uptime -p 2>/dev/null) |
| **Optionen** | net=$DO_NET guests=$DO_GUESTS |

> Read-only erhoben. Passwörter, Tokens und Keys sind im Report maskiert.

---

# Best-Practice-Zusammenfassung

**$N_PASS PASS · $N_WARN WARN · $N_FAIL FAIL · $N_INFO INFO**

| Status | Regel | Befund |
|---|---|---|
EOF
  printf '%s\n' "${CHECK_ROWS[@]}"
  cat <<'EOF'

**Legende:** `PASS` = Regel erfüllt · `WARN` = Abweichung, bewusst oder zu prüfen ·
`FAIL` = Handlungsbedarf · `INFO` = nur zur Kenntnis, keine Wertung.

---
EOF
  cat "$BODY"
  cat <<'EOF'

---

## Nächster Schritt

Diesen Report vollständig an Claude geben mit der Bitte, ihn gegen die
Dokumentation in `PVE_rxf-sys` abzugleichen (Abweichungen in README, 01–10,
configs/) und die offenen `WARN`/`FAIL` zu bewerten.
EOF
}

# Redaktion von Geheimnissen (wird auf den gesamten Report angewendet)
redact() {
  sed -E \
    -e 's/((password|passwd|secret|token|apikey|api_key|api-key|privatekey|private_key|credential|psk|pre-?shared-?key)[[:space:]]*[:=][[:space:]]*)[^[:space:],;"]+/\1<REDACTED>/Ig' \
    -e 's/^([[:space:]]*(password|passwd|secret|token|apitoken|api-token|authkey|auth-key|key)[[:space:]]+)[^[:space:]].*/\1<REDACTED>/I' \
    -e 's/(PVEAPIToken=[^=]+=)[A-Za-z0-9-]{16,}/\1<REDACTED>/g' \
    -e 's/eyJ[A-Za-z0-9_\/+=.-]{30,}/<REDACTED-JWT>/g' \
    -e 's/(Serial Number:[[:space:]]*).*/\1<REDACTED>/I' \
    -e 's/-----BEGIN [A-Z ]*PRIVATE KEY-----/<REDACTED-PRIVATE-KEY>/g' \
    -e 's#b3BlbnNzaC1rZXktdjE[A-Za-z0-9+/=]+#<REDACTED-PRIVATE-KEY>#g' \
    -e 's#(ssh-(rsa|dss|ed25519)|ecdsa-sha2-[a-z0-9-]+)[[:space:]]+[A-Za-z0-9+/=]{80,}#\1 <REDACTED-KEY>#g'
}

if [ "$TO_STDOUT" -eq 1 ]; then
  assemble | redact
else
  assemble | redact > "$OUT"
  chmod 600 "$OUT" 2>/dev/null
  echo "[*] Fertig: $OUT" >&2
  echo "[*] $N_PASS PASS / $N_WARN WARN / $N_FAIL FAIL / $N_INFO INFO" >&2
fi
