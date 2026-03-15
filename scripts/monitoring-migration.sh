#!/bin/bash
# =============================================================================
# Grafana + Prometheus Zusammenlegung
# Server: rxfsys
# Migriert Grafana von CT 107 nach CT 106 (Prometheus)
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

echo ""
echo -e "${BOLD}=====================================================${NC}"
echo -e "${BOLD}  Monitoring-Migration: CT 107 -> CT 106${NC}"
echo -e "${BOLD}  $(date '+%d.%m.%Y %H:%M')${NC}"
echo -e "${BOLD}=====================================================${NC}"
echo ""
echo -e "${YELLOW}ACHTUNG: Monitoring-Downtime waehrend der Migration (~10 Min)${NC}"
echo ""
read -p "Fortfahren? (j/n): " CONFIRM
if [ "$CONFIRM" != "j" ]; then
    echo "Abgebrochen."
    exit 0
fi

echo ""

# ===== 1. GRAFANA-DATEN SICHERN =====
echo -e "${BOLD}[1/8] Grafana-Daten aus CT 107 sichern${NC}"

pct exec 107 -- tar -czf /root/grafana-export.tar.gz \
    /var/lib/grafana/ \
    /etc/grafana/ \
    2>/dev/null

# Backup vom Container nach Host kopieren
BACKUP_PATH="/tmp/grafana-export.tar.gz"
pct pull 107 /root/grafana-export.tar.gz "$BACKUP_PATH"
echo -e "  ${GREEN}OK${NC}  Grafana-Backup erstellt: $BACKUP_PATH"

echo ""

# ===== 2. GRAFANA AUF CT 106 INSTALLIEREN =====
echo -e "${BOLD}[2/8] Grafana auf CT 106 installieren${NC}"

pct exec 106 -- bash -c '
    apt update
    apt install -y apt-transport-https gnupg
    mkdir -p /etc/apt/keyrings/
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list
    apt update
    apt install -y grafana
'
echo -e "  ${GREEN}OK${NC}  Grafana installiert auf CT 106"

echo ""

# ===== 3. GRAFANA-DATEN IMPORTIEREN =====
echo -e "${BOLD}[3/8] Grafana-Daten importieren${NC}"

pct push 106 "$BACKUP_PATH" /root/grafana-export.tar.gz

pct exec 106 -- bash -c '
    # Stoppe Grafana bevor wir Dateien ersetzen
    systemctl stop grafana-server

    # Datenbank und Plugins importieren
    tar -xzf /root/grafana-export.tar.gz -C / --strip-components=0

    # Datasource auf localhost umstellen (Prometheus ist jetzt lokal)
    mkdir -p /etc/grafana/provisioning/datasources
    cat > /etc/grafana/provisioning/datasources/datasources.yml << "DSEOF"
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
DSEOF

    # Berechtigungen fixen
    chown -R grafana:grafana /var/lib/grafana/
    chown -R grafana:grafana /etc/grafana/

    # Grafana starten
    systemctl enable --now grafana-server
'

echo -e "  ${GREEN}OK${NC}  Grafana-Daten importiert, Datasource auf localhost umgestellt"

echo ""

# ===== 4. GRAFANA TESTEN =====
echo -e "${BOLD}[4/8] Grafana testen${NC}"

sleep 5
if pct exec 106 -- curl -sf http://localhost:3000/api/health 2>/dev/null | grep -q "ok"; then
    echo -e "  ${GREEN}OK${NC}  Grafana antwortet auf CT 106:3000"
else
    echo -e "  ${RED}FAIL${NC}  Grafana antwortet nicht - Logs pruefen:"
    echo "        pct exec 106 -- journalctl -u grafana-server -n 20"
    echo "  Migration manuell abschliessen!"
    exit 1
fi

echo ""

# ===== 5. PROMETHEUS SCRAPE-CONFIG ANPASSEN =====
echo -e "${BOLD}[5/8] Prometheus Scrape-Config anpassen${NC}"

pct exec 106 -- bash -c '
    # Alten Grafana-Target (192.168.2.128) entfernen, localhost hinzufuegen
    cat > /etc/prometheus/prometheus.yml << "PROMEOF"
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "proxmox-host"
    static_configs:
      - targets: ["192.168.2.120:9100"]
        labels:
          instance: "rxfsys-host"

  - job_name: "containers"
    static_configs:
      - targets:
          - "192.168.2.121:9100"  # CT 100 - Samba
          - "192.168.2.122:9100"  # CT 101 - Pi-hole
          - "192.168.2.123:9100"  # CT 102 - WireGuard
          - "192.168.2.124:9100"  # CT 103 - Vaultwarden
          - "192.168.2.125:9100"  # CT 104 - Nginx PM
          - "192.168.2.126:9100"  # CT 105 - Jellyfin
          - "localhost:9100"      # CT 106 - Monitoring (lokal)
          - "192.168.2.129:9100"  # CT 108 - PBS
          - "192.168.2.130:9100"  # CT 109 - Home Assistant
          - "192.168.2.131:9100"  # CT 110 - Paperless
          - "192.168.2.132:9100"  # CT 111 - Finanzguru
        labels:
          environment: "homeserver"
PROMEOF

    # Prometheus neustarten
    systemctl restart prometheus
'

echo -e "  ${GREEN}OK${NC}  Prometheus-Config aktualisiert (CT 107/128 entfernt)"

echo ""

# ===== 6. FIREWALL ANPASSEN =====
echo -e "${BOLD}[6/8] Firewall CT 106 anpassen (Port 3000 hinzufuegen)${NC}"

cat > /etc/pve/firewall/106.fw << 'FWEOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Prometheus Web-UI (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 9090 -log nolog

# Grafana Web-UI (LAN)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 3000 -log nolog

# Node-Exporter (Monitoring)
IN ACCEPT -source 192.168.2.0/24 -p tcp -dport 9100 -log nolog

# ICMP/Ping
IN ACCEPT -p icmp
FWEOF

echo -e "  ${GREEN}OK${NC}  Firewall CT 106: Port 9090 + 3000 + 9100"

echo ""

# ===== 7. DNS ANPASSEN =====
echo -e "${BOLD}[7/8] Pi-hole DNS anpassen${NC}"

# grafana.home auf CT 106 IP umleiten
pct exec 101 -- bash -c '
    sed -i "s/192.168.2.128 grafana.home/192.168.2.127 grafana.home monitoring.home/" /etc/pihole/custom.list
    pihole restartdns
'

echo -e "  ${GREEN}OK${NC}  grafana.home -> 192.168.2.127 (CT 106)"

echo ""

# ===== 8. CT 107 HERUNTERFAHREN =====
echo -e "${BOLD}[8/8] CT 107 herunterfahren${NC}"

echo -e "  ${YELLOW}INFO${NC}  CT 107 wird gestoppt (nicht geloescht)"
echo "  Zum endgueltigen Entfernen:"
echo "    pct stop 107"
echo "    pct destroy 107 --purge"
echo ""

read -p "CT 107 jetzt stoppen? (j/n): " STOP_107
if [ "$STOP_107" = "j" ]; then
    pct stop 107
    pct set 107 --onboot 0
    echo -e "  ${GREEN}OK${NC}  CT 107 gestoppt und Autostart deaktiviert"
else
    echo -e "  ${YELLOW}SKIP${NC}  CT 107 laeuft weiter - manuell stoppen wenn fertig"
fi

echo ""
echo -e "${BOLD}=====================================================${NC}"
echo -e "${BOLD}  Migration abgeschlossen!${NC}"
echo -e "${BOLD}=====================================================${NC}"
echo ""
echo "  Grafana:    http://monitoring.home:3000"
echo "  Prometheus: http://monitoring.home:9090"
echo ""
echo "  Verifizierung:"
echo "    curl -sf http://192.168.2.127:3000/api/health"
echo "    curl -sf http://192.168.2.127:9090/-/healthy"
echo ""
