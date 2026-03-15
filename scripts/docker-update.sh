#!/bin/bash
# =============================================================================
# Docker Image-Pinning und Hardening
# Server: rxfsys
# Aktualisiert alle Docker-Container auf gepinnte Versionen
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

echo ""
echo -e "${BOLD}=====================================================${NC}"
echo -e "${BOLD}  Docker Image Update - $(date '+%d.%m.%Y %H:%M')${NC}"
echo -e "${BOLD}=====================================================${NC}"
echo ""

# ===== 1. PAPERLESS DB-FIX (CT 110) =====
echo -e "${BOLD}[1/5] Paperless DB-Passwort fixen (CT 110)${NC}"
echo ""

if pct exec 110 -- docker ps --format '{{.Names}}' 2>/dev/null | grep -q paperless-db; then
    echo "  PostgreSQL-Passwort wird korrigiert..."
    # Passwort in PostgreSQL anpassen (muss zum PAPERLESS_DBPASS in docker-compose passen)
    DBPASS=$(pct exec 110 -- bash -c 'grep PAPERLESS_DBPASS /srv/appdata/paperless/docker-compose.yml | head -1 | sed "s/.*PAPERLESS_DBPASS: //"' 2>/dev/null)
    if [ -n "$DBPASS" ]; then
        pct exec 110 -- docker exec paperless-db psql -U paperless -c "ALTER USER paperless PASSWORD '$DBPASS';" 2>/dev/null
        pct exec 110 -- docker restart paperless-ngx 2>/dev/null
        sleep 5
        if pct exec 110 -- docker ps --format '{{.Status}}' --filter name=paperless-ngx 2>/dev/null | grep -q "Up"; then
            echo -e "  ${GREEN}OK${NC}  Paperless laeuft wieder"
        else
            echo -e "  ${RED}FAIL${NC}  Paperless startet nicht - Logs pruefen:"
            echo "        pct exec 110 -- docker logs paperless-ngx --tail 10"
        fi
    else
        echo -e "  ${YELLOW}WARN${NC}  Konnte DBPASS nicht aus docker-compose lesen"
    fi
else
    echo -e "  ${YELLOW}WARN${NC}  paperless-db Container nicht gefunden"
fi

echo ""

# ===== 2. WG-EASY MIGRATION (CT 102) =====
echo -e "${BOLD}[2/5] WireGuard wg-easy Migration (CT 102)${NC}"
echo ""

CURRENT_IMAGE=$(pct exec 102 -- docker inspect wg-easy --format '{{.Config.Image}}' 2>/dev/null)
echo "  Aktuelles Image: $CURRENT_IMAGE"

if echo "$CURRENT_IMAGE" | grep -q "weejewel"; then
    echo ""
    echo -e "  ${YELLOW}ACHTUNG:${NC} Migration von weejewel/wg-easy -> ghcr.io/wg-easy/wg-easy:14"
    echo "  Dies erfordert manuelle Schritte:"
    echo ""
    echo "  1. Neues Passwort hashen:"
    echo "     docker run --rm ghcr.io/wg-easy/wg-easy wgpw 'DEIN_PASSWORT'"
    echo ""
    echo "  2. docker-compose.yml aktualisieren:"
    echo "     - image: ghcr.io/wg-easy/wg-easy:14"
    echo "     - PASSWORD -> PASSWORD_HASH (bcrypt)"
    echo ""
    echo "  3. Migration durchfuehren:"
    echo "     pct exec 102 -- bash -c 'cd /srv/appdata/wireguard && docker compose down'"
    echo "     pct exec 102 -- bash -c 'cd /srv/appdata/wireguard && docker compose pull'"
    echo "     pct exec 102 -- bash -c 'cd /srv/appdata/wireguard && docker compose up -d'"
    echo ""
    echo "  4. Alte Images aufraeumen:"
    echo "     pct exec 102 -- docker image prune -a"
    echo ""
    echo -e "  ${YELLOW}SKIP${NC}  Manuelle Migration erforderlich (VPN-Ausfall!)"
else
    echo -e "  ${GREEN}OK${NC}  Bereits auf neuem Image"
fi

echo ""

# ===== 3. VAULTWARDEN UPDATE (CT 103) =====
echo -e "${BOLD}[3/5] Vaultwarden (CT 103)${NC}"
echo ""

CURRENT_IMAGE=$(pct exec 103 -- docker inspect vaultwarden --format '{{.Config.Image}}' 2>/dev/null)
echo "  Aktuelles Image: $CURRENT_IMAGE"
echo "  Empfohlenes Image: vaultwarden/server:1.33.2"
echo ""
echo "  Update-Befehle:"
echo "    pct exec 103 -- bash -c 'cd /srv/appdata/vaultwarden && sed -i \"s|vaultwarden/server:latest|vaultwarden/server:1.33.2|\" docker-compose.yml'"
echo "    pct exec 103 -- bash -c 'cd /srv/appdata/vaultwarden && docker compose pull && docker compose up -d'"

echo ""

# ===== 4. NGINX PM UPDATE (CT 104) =====
echo -e "${BOLD}[4/5] Nginx Proxy Manager (CT 104)${NC}"
echo ""

CURRENT_IMAGE=$(pct exec 104 -- docker inspect npm --format '{{.Config.Image}}' 2>/dev/null)
echo "  Aktuelles Image: $CURRENT_IMAGE"
echo "  Empfohlenes Image: jc21/nginx-proxy-manager:2.13.2"
echo ""
echo "  Update-Befehle:"
echo "    pct exec 104 -- bash -c 'cd /srv/appdata/npm && sed -i \"s|jc21/nginx-proxy-manager:latest|jc21/nginx-proxy-manager:2.13.2|\" docker-compose.yml'"
echo "    pct exec 104 -- bash -c 'cd /srv/appdata/npm && docker compose pull && docker compose up -d'"

echo ""

# ===== 5. PAPERLESS IMAGE PINNING (CT 110) =====
echo -e "${BOLD}[5/5] Paperless Image-Pinning (CT 110)${NC}"
echo ""

echo "  Empfohlene Images:"
echo "    paperless-ngx: ghcr.io/paperless-ngx/paperless-ngx:2.14"
echo "    postgres:      postgres:15-alpine"
echo "    redis:          redis:7-alpine"
echo ""
echo "  Update-Befehle:"
echo "    pct exec 110 -- bash -c 'cd /srv/appdata/paperless && \\"
echo "      sed -i \"s|ghcr.io/paperless-ngx/paperless-ngx:latest|ghcr.io/paperless-ngx/paperless-ngx:2.14|\" docker-compose.yml && \\"
echo "      sed -i \"s|postgres:15|postgres:15-alpine|\" docker-compose.yml && \\"
echo "      sed -i \"s|redis:7|redis:7-alpine|\" docker-compose.yml && \\"
echo "      docker compose pull && docker compose up -d'"

echo ""
echo -e "${BOLD}=====================================================${NC}"
echo -e "${BOLD}  Docker Update Script abgeschlossen${NC}"
echo -e "${BOLD}=====================================================${NC}"
echo ""
