#!/bin/bash
# =============================================================================
# VM/CT Inventar exportieren
# Server: rxfsys
# =============================================================================

echo "=== Container-Inventar rxfsys - $(date) ==="
echo ""
printf "%-5s %-15s %-17s %-6s %-5s %-8s %-10s\n" "ID" "Name" "IP" "RAM" "CPU" "Disk" "Status"
printf "%-5s %-15s %-17s %-6s %-5s %-8s %-10s\n" "----" "--------------" "----------------" "-----" "----" "-------" "---------"

for ID in $(pct list | awk 'NR>1 {print $1}'); do
    NAME=$(pct config $ID | grep "^hostname" | awk '{print $2}')
    STATUS=$(pct status $ID | awk '{print $2}')
    RAM=$(pct config $ID | grep "^memory" | awk '{print $2}')
    CPU=$(pct config $ID | grep "^cores" | awk '{print $2}')
    DISK=$(pct config $ID | grep "^rootfs" | grep -oP 'size=\K[^,]+')

    # IP ermitteln
    IP=$(pct exec $ID -- hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$IP" ] && IP="offline"

    printf "%-5s %-15s %-17s %-6s %-5s %-8s %-10s\n" "$ID" "$NAME" "$IP" "${RAM}M" "$CPU" "$DISK" "$STATUS"
done

echo ""
echo "=== Ende ==="
