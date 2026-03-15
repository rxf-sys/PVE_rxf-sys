#!/bin/bash
# =============================================================================
# Container Best-Practice Hardening Script
# Server: rxfsys
# Fuehrt alle Container-OS-Level Haertungen durch
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

echo ""
echo -e "${BOLD}=====================================================${NC}"
echo -e "${BOLD}  Container Hardening - $(date '+%d.%m.%Y %H:%M')${NC}"
echo -e "${BOLD}=====================================================${NC}"
echo ""

ALL_CTS=$(pct list | awk 'NR>1 {print $1}')

# ===== 1. POSTFIX ENTFERNEN =====
echo -e "${BOLD}[1/4] Postfix entfernen${NC}"
echo "      Postfix laeuft unnoetig auf allen Containern (Port 25)"
echo ""

for CT in $ALL_CTS; do
    NAME=$(pct exec $CT -- hostname 2>/dev/null)
    if pct exec $CT -- systemctl is-active --quiet postfix 2>/dev/null; then
        echo -e "  CT $CT ($NAME): Postfix gefunden - entferne..."
        pct exec $CT -- systemctl disable --now postfix 2>/dev/null
        pct exec $CT -- apt remove --purge -y postfix 2>/dev/null | tail -1
        pct exec $CT -- apt autoremove -y 2>/dev/null | tail -1
        echo -e "  ${GREEN}OK${NC}  CT $CT ($NAME): Postfix entfernt"
    else
        echo -e "  ${GREEN}OK${NC}  CT $CT ($NAME): Kein Postfix"
    fi
done

echo ""

# ===== 2. UNATTENDED-UPGRADES =====
echo -e "${BOLD}[2/4] Unattended-Upgrades installieren${NC}"
echo ""

for CT in $ALL_CTS; do
    NAME=$(pct exec $CT -- hostname 2>/dev/null)
    if pct exec $CT -- dpkg -l unattended-upgrades 2>/dev/null | grep -q "^ii"; then
        echo -e "  ${GREEN}OK${NC}  CT $CT ($NAME): Bereits installiert"
    else
        echo -e "  CT $CT ($NAME): Installiere unattended-upgrades..."
        pct exec $CT -- apt install -y unattended-upgrades 2>/dev/null | tail -1
        pct exec $CT -- dpkg-reconfigure -f noninteractive unattended-upgrades 2>/dev/null
        echo -e "  ${GREEN}OK${NC}  CT $CT ($NAME): Installiert und aktiviert"
    fi
done

echo ""

# ===== 3. NODE-EXPORTER =====
echo -e "${BOLD}[3/4] Node-Exporter pruefen${NC}"
echo ""

for CT in $ALL_CTS; do
    NAME=$(pct exec $CT -- hostname 2>/dev/null)
    if pct exec $CT -- ss -tlnp 2>/dev/null | grep -q ":9100"; then
        echo -e "  ${GREEN}OK${NC}  CT $CT ($NAME): Node-Exporter laeuft"
    else
        echo -e "  ${YELLOW}WARN${NC}  CT $CT ($NAME): Node-Exporter fehlt"
        echo "        Installieren: pct exec $CT -- apt install -y prometheus-node-exporter"
    fi
done

echo ""

# ===== 4. UNNOETIGE SERVICES PRUEFEN =====
echo -e "${BOLD}[4/4] Unnoetige Services pruefen${NC}"
echo ""

for CT in $ALL_CTS; do
    NAME=$(pct exec $CT -- hostname 2>/dev/null)
    SERVICES=""

    # Cron sollte laufen (fuer unattended-upgrades)
    # SSH ist OK (fuer Debugging)

    # Pruefen ob unnoetige Services laufen
    if pct exec $CT -- systemctl is-active --quiet exim4 2>/dev/null; then
        SERVICES="exim4 $SERVICES"
    fi
    if pct exec $CT -- systemctl is-active --quiet sendmail 2>/dev/null; then
        SERVICES="sendmail $SERVICES"
    fi

    if [ -n "$SERVICES" ]; then
        echo -e "  ${YELLOW}WARN${NC}  CT $CT ($NAME): Unnoetige Services: $SERVICES"
    else
        echo -e "  ${GREEN}OK${NC}  CT $CT ($NAME): Keine unnoetigen Services"
    fi
done

echo ""
echo -e "${BOLD}=====================================================${NC}"
echo -e "${BOLD}  Hardening abgeschlossen${NC}"
echo -e "${BOLD}=====================================================${NC}"
echo ""
echo "Naechste Schritte:"
echo "  1. Docker-Images aktualisieren (siehe scripts/docker-update.sh)"
echo "  2. Monitoring-Migration durchfuehren (siehe scripts/monitoring-migration.sh)"
echo ""
