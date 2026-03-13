#!/bin/bash
# =============================================================================
# Proxmox Best-Practice Audit Script
# Server: rxfsys
# Prueft alle Punkte aus 09-wartung/proxmox-best-practices.md
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

PASS=0
WARN=0
FAIL=0

pass()  { echo -e "  ${GREEN}PASS${NC}  $1"; ((PASS++)); }
warn()  { echo -e "  ${YELLOW}WARN${NC}  $1"; ((WARN++)); }
fail()  { echo -e "  ${RED}FAIL${NC}  $1"; ((FAIL++)); }

echo ""
echo -e "${BOLD}=====================================================${NC}"
echo -e "${BOLD}  Proxmox Best-Practice Audit - $(date '+%d.%m.%Y %H:%M')${NC}"
echo -e "${BOLD}=====================================================${NC}"
echo ""

# ===== 1. BACKUP-STORAGE =====
echo -e "${BOLD}[1/12] Backup-Storage${NC}"

if mountpoint -q /mnt/backups 2>/dev/null; then
    pass "Backup-SSD ist gemountet"
else
    fail "Backup-SSD /mnt/backups ist NICHT gemountet"
fi

BACKUP_STORAGE=$(grep -oP 'storage \K\S+' /etc/pve/jobs.cfg 2>/dev/null | head -1)
if [ "$BACKUP_STORAGE" = "local" ]; then
    fail "Backup-Job speichert auf 'local' (System-SSD) statt Backup-SSD"
elif [ -n "$BACKUP_STORAGE" ]; then
    pass "Backup-Job nutzt Storage: $BACKUP_STORAGE"
else
    warn "Kein Backup-Job konfiguriert"
fi

BACKUP_COUNT=$(ls /mnt/backups/dump/vzdump-lxc-*.vma.zst 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 0 ]; then
    pass "Backups auf Backup-SSD vorhanden ($BACKUP_COUNT Dateien)"
else
    warn "Keine Backups auf /mnt/backups/dump/ gefunden"
fi

echo ""

# ===== 2. BACKUP-RETENTION =====
echo -e "${BOLD}[2/12] Backup-Retention${NC}"

RETENTION=$(grep 'prune-backups' /etc/pve/jobs.cfg 2>/dev/null)
if echo "$RETENTION" | grep -q 'keep-weekly'; then
    pass "Woechentliche Retention konfiguriert"
else
    fail "Keine woechentliche Retention - nur: $RETENTION"
fi
if echo "$RETENTION" | grep -q 'keep-monthly'; then
    pass "Monatliche Retention konfiguriert"
else
    fail "Keine monatliche Retention"
fi

echo ""

# ===== 3. SSH-HAERTUNG =====
echo -e "${BOLD}[3/12] SSH-Haertung${NC}"

SSH_ROOT=$(sshd -T 2>/dev/null | grep -i "^permitrootlogin" | awk '{print $2}')
if [ -z "$SSH_ROOT" ]; then
    SSH_ROOT=$(grep -E "^PermitRootLogin" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | tail -1 | awk '{print $2}')
fi
if [ "$SSH_ROOT" = "prohibit-password" ] || [ "$SSH_ROOT" = "without-password" ] || [ "$SSH_ROOT" = "no" ]; then
    pass "Root-Login nur mit SSH-Key ($SSH_ROOT)"
elif [ "$SSH_ROOT" = "yes" ]; then
    fail "Root-Login mit Passwort erlaubt (PermitRootLogin yes)"
else
    warn "PermitRootLogin-Status unklar: '$SSH_ROOT'"
fi

SSH_PASS=$(sshd -T 2>/dev/null | grep -i "^passwordauthentication" | awk '{print $2}')
if [ -z "$SSH_PASS" ]; then
    SSH_PASS=$(grep -E "^PasswordAuthentication" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | tail -1 | awk '{print $2}')
fi
if [ "$SSH_PASS" = "no" ]; then
    pass "Passwort-Authentifizierung deaktiviert"
elif [ "$SSH_PASS" = "yes" ] || [ -z "$SSH_PASS" ]; then
    fail "Passwort-Authentifizierung aktiv (default oder explizit)"
fi

if [ -s /root/.ssh/authorized_keys ]; then
    KEY_COUNT=$(grep -c "^ssh-" /root/.ssh/authorized_keys 2>/dev/null)
    pass "SSH-Keys hinterlegt ($KEY_COUNT Keys)"
else
    fail "Keine SSH-Keys in /root/.ssh/authorized_keys"
fi

echo ""

# ===== 4. FAIL2BAN =====
echo -e "${BOLD}[4/12] Fail2Ban${NC}"

if systemctl is-active --quiet fail2ban 2>/dev/null; then
    pass "Fail2ban ist aktiv"
else
    fail "Fail2ban ist nicht aktiv"
fi

if fail2ban-client status proxmox &>/dev/null; then
    pass "Proxmox-Jail konfiguriert"
else
    warn "Kein Proxmox-Jail in Fail2ban"
fi

echo ""

# ===== 5. SWAP =====
echo -e "${BOLD}[5/12] Container-Swap${NC}"

SWAP_TOTAL=0
SWAP_ISSUES=0
for CT in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
    SWAP=$(grep -w "^swap:" /etc/pve/lxc/$CT.conf 2>/dev/null | awk '{print $2}')
    if [ -z "$SWAP" ]; then
        SWAP=512  # Proxmox default
    fi
    SWAP_TOTAL=$((SWAP_TOTAL + SWAP))
    if [ "$SWAP" -gt 0 ]; then
        ((SWAP_ISSUES++))
    fi
done

if [ "$SWAP_ISSUES" -eq 0 ]; then
    pass "Alle Container haben Swap 0"
else
    fail "$SWAP_ISSUES Container haben Swap aktiv (gesamt: ${SWAP_TOTAL} MB)"
fi

echo ""

# ===== 6. KEYCTL =====
echo -e "${BOLD}[6/12] Docker-Container Features (keyctl)${NC}"

DOCKER_CTS="102 103 104 110 111"
for CT in $DOCKER_CTS; do
    if [ ! -f "/etc/pve/lxc/$CT.conf" ]; then
        continue
    fi
    NAME=$(grep "^hostname:" /etc/pve/lxc/$CT.conf | awk '{print $2}')
    FEATURES=$(grep "^features:" /etc/pve/lxc/$CT.conf 2>/dev/null | awk '{print $2}')
    if echo "$FEATURES" | grep -q "keyctl=1"; then
        pass "CT $CT ($NAME): keyctl aktiviert"
    else
        fail "CT $CT ($NAME): keyctl fehlt (features: $FEATURES)"
    fi
done

echo ""

# ===== 7. CPU-LIMITS =====
echo -e "${BOLD}[7/12] CPU-Limits${NC}"

NOLIMIT=0
for CT in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
    NAME=$(grep "^hostname:" /etc/pve/lxc/$CT.conf | awk '{print $2}')
    LIMIT=$(grep "^cpulimit:" /etc/pve/lxc/$CT.conf 2>/dev/null | awk '{print $2}')
    CORES=$(grep "^cores:" /etc/pve/lxc/$CT.conf | awk '{print $2}')
    if [ -z "$LIMIT" ] || [ "$LIMIT" = "0" ]; then
        warn "CT $CT ($NAME): Kein CPU-Limit (${CORES} Cores zugewiesen)"
        ((NOLIMIT++))
    else
        pass "CT $CT ($NAME): CPU-Limit $LIMIT"
    fi
done

if [ "$NOLIMIT" -gt 0 ]; then
    TOTAL_CORES=$(awk 'NR>1 {sum+=$0} END{print sum}' <(for f in /etc/pve/lxc/*.conf; do grep "^cores:" "$f" 2>/dev/null | awk '{print $2}'; done))
    PHYS_CORES=$(nproc)
    warn "Gesamt: $TOTAL_CORES Cores zugewiesen auf $PHYS_CORES physische Cores (kein Limit)"
fi

echo ""

# ===== 8. FIREWALL =====
echo -e "${BOLD}[8/12] Firewall${NC}"

FW_STATUS=$(pve-firewall status 2>/dev/null | grep -i "status:" | awk '{print $2}')
if [ "$FW_STATUS" = "enabled/running" ]; then
    pass "Cluster-Firewall aktiv"
else
    fail "Cluster-Firewall nicht aktiv: $FW_STATUS"
fi

CLUSTER_POLICY=$(grep "^policy_in:" /etc/pve/firewall/cluster.fw 2>/dev/null | awk '{print $2}')
if [ "$CLUSTER_POLICY" = "DROP" ]; then
    pass "Cluster Input-Policy: DROP"
else
    fail "Cluster Input-Policy: $CLUSTER_POLICY (sollte DROP sein)"
fi

for CT in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
    NAME=$(grep "^hostname:" /etc/pve/lxc/$CT.conf | awk '{print $2}')
    if [ -f "/etc/pve/firewall/$CT.fw" ]; then
        FW_ENABLED=$(grep "^enable:" /etc/pve/firewall/$CT.fw 2>/dev/null | awk '{print $2}')
        if [ "$FW_ENABLED" = "1" ]; then
            pass "CT $CT ($NAME): Firewall aktiv"
        else
            warn "CT $CT ($NAME): Firewall-Datei existiert, aber nicht aktiviert"
        fi
    else
        fail "CT $CT ($NAME): Keine Firewall-Regeln (/etc/pve/firewall/$CT.fw fehlt)"
    fi
done

echo ""

# ===== 9. RAM =====
echo -e "${BOLD}[9/12] RAM-Auslastung${NC}"

TOTAL_ALLOC=0
for CT in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
    MEM=$(grep "^memory:" /etc/pve/lxc/$CT.conf | awk '{print $2}')
    TOTAL_ALLOC=$((TOTAL_ALLOC + MEM))
done
HOST_TOTAL=$(free -m | awk '/Mem:/{print $2}')
ALLOC_PCT=$((TOTAL_ALLOC * 100 / HOST_TOTAL))

if [ "$ALLOC_PCT" -gt 90 ]; then
    fail "RAM: ${TOTAL_ALLOC} MB zugewiesen von ${HOST_TOTAL} MB (${ALLOC_PCT}%)"
elif [ "$ALLOC_PCT" -gt 75 ]; then
    warn "RAM: ${TOTAL_ALLOC} MB zugewiesen von ${HOST_TOTAL} MB (${ALLOC_PCT}%)"
else
    pass "RAM: ${TOTAL_ALLOC} MB zugewiesen von ${HOST_TOTAL} MB (${ALLOC_PCT}%)"
fi

HOST_USED=$(free -m | awk '/Mem:/{print $3}')
HOST_USED_PCT=$((HOST_USED * 100 / HOST_TOTAL))
if [ "$HOST_USED_PCT" -gt 80 ]; then
    fail "RAM tatsaechlich: ${HOST_USED} MB / ${HOST_TOTAL} MB (${HOST_USED_PCT}%)"
elif [ "$HOST_USED_PCT" -gt 60 ]; then
    warn "RAM tatsaechlich: ${HOST_USED} MB / ${HOST_TOTAL} MB (${HOST_USED_PCT}%)"
else
    pass "RAM tatsaechlich: ${HOST_USED} MB / ${HOST_TOTAL} MB (${HOST_USED_PCT}%)"
fi

echo ""

# ===== 10. DISK =====
echo -e "${BOLD}[10/12] Disk-Belegung${NC}"

while read -r line; do
    FS=$(echo "$line" | awk '{print $1}')
    USE_PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')
    MOUNT=$(echo "$line" | awk '{print $6}')

    if [ -z "$USE_PCT" ] || ! [[ "$USE_PCT" =~ ^[0-9]+$ ]]; then
        continue
    fi

    if [ "$USE_PCT" -gt 85 ]; then
        fail "$MOUNT: ${USE_PCT}% belegt"
    elif [ "$USE_PCT" -gt 70 ]; then
        warn "$MOUNT: ${USE_PCT}% belegt"
    else
        pass "$MOUNT: ${USE_PCT}% belegt"
    fi
done < <(df -h / /mnt/storage /mnt/backups 2>/dev/null | grep -v "^Filesystem")

echo ""

# ===== 11. PROXMOX 2FA =====
echo -e "${BOLD}[11/12] Proxmox 2FA${NC}"

if grep -q "type: oath" /etc/pve/priv/tfa.cfg 2>/dev/null || \
   grep -q '"totp"' /etc/pve/priv/tfa.cfg 2>/dev/null || \
   [ -s /etc/pve/priv/tfa.cfg ]; then
    TFA_CONTENT=$(cat /etc/pve/priv/tfa.cfg 2>/dev/null)
    if [ -n "$TFA_CONTENT" ] && [ "$TFA_CONTENT" != "{}" ]; then
        pass "2FA ist konfiguriert"
    else
        warn "2FA-Datei existiert aber moeglicherweise leer"
    fi
else
    fail "Keine 2FA fuer Proxmox Web-UI konfiguriert"
fi

echo ""

# ===== 12. KERNEL =====
echo -e "${BOLD}[12/12] Kernel${NC}"

CURRENT_KERNEL=$(uname -r)
INSTALLED_KERNELS=$(dpkg -l | grep "proxmox-kernel-.*-pve-signed" | grep "^ii" | wc -l)

pass "Laufender Kernel: $CURRENT_KERNEL"
if [ "$INSTALLED_KERNELS" -gt 2 ]; then
    warn "$INSTALLED_KERNELS Kernel installiert (2 reichen: aktuell + Fallback)"
    dpkg -l | grep "proxmox-kernel-.*-pve-signed" | grep "^ii" | awk '{print "        " $2}' | grep -v "$(echo $CURRENT_KERNEL | sed 's/-pve//')"
else
    pass "$INSTALLED_KERNELS Kernel installiert"
fi

echo ""

# ===== ZUSAMMENFASSUNG =====
TOTAL=$((PASS + WARN + FAIL))
echo -e "${BOLD}=====================================================${NC}"
echo -e "${BOLD}  ERGEBNIS${NC}"
echo -e "${BOLD}=====================================================${NC}"
echo ""
echo -e "  ${GREEN}PASS:${NC}  $PASS / $TOTAL"
echo -e "  ${YELLOW}WARN:${NC}  $WARN / $TOTAL"
echo -e "  ${RED}FAIL:${NC}  $FAIL / $TOTAL"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}Alles Best-Practice! Keine Aenderungen noetig.${NC}"
elif [ "$FAIL" -eq 0 ]; then
    echo -e "  ${YELLOW}${BOLD}Gut, aber $WARN Warnungen sollten geprueft werden.${NC}"
else
    echo -e "  ${RED}${BOLD}$FAIL kritische Punkte muessen behoben werden.${NC}"
    echo -e "  Siehe: 09-wartung/proxmox-best-practices.md"
fi
echo ""
