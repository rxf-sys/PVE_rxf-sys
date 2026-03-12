#!/bin/bash
# =============================================================================
# Alle Container sichern
# Server: rxfsys
# =============================================================================

set -e

STORAGE="local"
COMPRESS="zstd"
MODE="snapshot"
DATE=$(date +%Y-%m-%d)

echo "=== Backup aller Container - $DATE ==="
echo ""

CONTAINERS=$(pct list | awk 'NR>1 {print $1}')
TOTAL=$(echo "$CONTAINERS" | wc -w)
COUNT=0

for ID in $CONTAINERS; do
    COUNT=$((COUNT + 1))
    NAME=$(pct config $ID | grep hostname | awk '{print $2}')
    echo "[$COUNT/$TOTAL] Sichere CT $ID ($NAME)..."

    if vzdump $ID --storage $STORAGE --compress $COMPRESS --mode $MODE; then
        echo "  -> OK"
    else
        echo "  -> FEHLER bei CT $ID!"
    fi
    echo ""
done

echo "=== Backup abgeschlossen ==="
echo "Speicherort: $(pvesm path $STORAGE)"
echo "Belegung:"
df -h /var/lib/vz/dump/
