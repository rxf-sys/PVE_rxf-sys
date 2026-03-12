#!/bin/bash
# =============================================================================
# Taeglicher Health-Check
# Server: rxfsys
# =============================================================================

echo "=== Health-Check rxfsys - $(date) ==="
echo ""

# 1. System
echo "--- System ---"
echo "Uptime: $(uptime -p)"
echo "Load:   $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
echo ""

# 2. RAM
echo "--- RAM ---"
free -h | grep -E "Mem|Swap"
echo ""

# 3. Disk
echo "--- Disk ---"
df -h / /mnt/storage /mnt/backups 2>/dev/null | grep -v tmpfs
echo ""

# 4. LVM Thin Pool
echo "--- LVM Thin Pool ---"
lvs pve/data --noheadings -o lv_name,lv_size,data_percent 2>/dev/null || echo "LVM nicht verfuegbar"
echo ""

# 5. SMART
echo "--- SMART-Status ---"
for disk in /dev/sda /dev/nvme0n1; do
    if [ -e "$disk" ]; then
        RESULT=$(smartctl -H $disk 2>/dev/null | grep -i "result\|overall" | head -1)
        echo "$disk: ${RESULT:-N/A}"
    fi
done
# USB-SSD
if [ -e /dev/sdb ]; then
    RESULT=$(smartctl -d sat -H /dev/sdb 2>/dev/null | grep -i "result\|overall" | head -1)
    echo "/dev/sdb (USB): ${RESULT:-N/A}"
fi
echo ""

# 6. Container
echo "--- Container-Status ---"
pct list
echo ""

# 7. Fehler
echo "--- Fehler (letzte 24h) ---"
ERROR_COUNT=$(journalctl -p err --since "24 hours ago" --no-pager 2>/dev/null | wc -l)
echo "Fehlereintraege: $ERROR_COUNT"
if [ "$ERROR_COUNT" -gt 0 ]; then
    journalctl -p err --since "24 hours ago" --no-pager 2>/dev/null | tail -10
fi
echo ""

echo "=== Health-Check abgeschlossen ==="
