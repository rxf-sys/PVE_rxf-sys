#!/bin/bash
#===============================================================================
# rxfsys Home-Server Diagnose-Script
# Sammelt alle wichtigen Informationen aus Host und LXC-Containern
#===============================================================================

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Ausgabe-Datei
REPORT_FILE="/tmp/rxfsys-diagnostics-$(date +%Y%m%d-%H%M%S).txt"

# Logging-Funktion
log() {
    echo -e "$1" | tee -a "$REPORT_FILE"
}

header() {
    log "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    log "${BLUE}${BOLD}  $1${NC}"
    log "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}\n"
}

subheader() {
    log "\n${CYAN}───────────────────────────────────────────────────────────────${NC}"
    log "${CYAN}  $1${NC}"
    log "${CYAN}───────────────────────────────────────────────────────────────${NC}\n"
}

check_status() {
    if [ $1 -eq 0 ]; then
        log "${GREEN}✓ $2${NC}"
    else
        log "${RED}✗ $2${NC}"
    fi
}

warn_status() {
    log "${YELLOW}⚠ $1${NC}"
}

info_status() {
    log "${BLUE}ℹ $1${NC}"
}

#===============================================================================
# START
#===============================================================================

clear
log "${GREEN}${BOLD}"
log "  ╔═══════════════════════════════════════════════════════════════╗"
log "  ║         rxfsys Home-Server Diagnose-Script                    ║"
log "  ║         $(date '+%Y-%m-%d %H:%M:%S')                                   ║"
log "  ╚═══════════════════════════════════════════════════════════════╝"
log "${NC}"

#===============================================================================
# 1. HOST-INFORMATIONEN
#===============================================================================

header "1. PROXMOX HOST INFORMATIONEN"

subheader "System-Überblick"
log "Hostname:        $(hostname)"
log "Proxmox Version: $(pveversion 2>/dev/null || echo 'N/A')"
log "Kernel:          $(uname -r)"
log "Uptime:          $(uptime -p)"
log "Datum/Zeit:      $(date)"

subheader "CPU-Informationen"
log "CPU Model:       $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
log "CPU Cores:       $(nproc)"
log "CPU Load:        $(cat /proc/loadavg | awk '{print $1", "$2", "$3}')"

# CPU-Temperatur (falls verfügbar)
if command -v sensors &> /dev/null; then
    CPU_TEMP=$(sensors 2>/dev/null | grep -i 'core 0' | awk '{print $3}' | head -1)
    [ -n "$CPU_TEMP" ] && log "CPU Temp:        $CPU_TEMP"
fi

subheader "RAM-Nutzung"
free -h | tee -a "$REPORT_FILE"

subheader "Swap-Nutzung"
swapon --show 2>/dev/null | tee -a "$REPORT_FILE" || log "Kein Swap konfiguriert"

#===============================================================================
# 2. STORAGE-STATUS
#===============================================================================

header "2. STORAGE STATUS"

subheader "Disk-Übersicht"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL 2>/dev/null | tee -a "$REPORT_FILE"

subheader "Speicherplatz (df)"
df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs 2>/dev/null | tee -a "$REPORT_FILE"

subheader "LVM Status"
log "\n${BOLD}Volume Groups:${NC}"
vgs 2>/dev/null | tee -a "$REPORT_FILE" || log "Keine VGs gefunden"

log "\n${BOLD}Logical Volumes:${NC}"
lvs 2>/dev/null | tee -a "$REPORT_FILE" || log "Keine LVs gefunden"

subheader "Proxmox Storage"
pvesm status 2>/dev/null | tee -a "$REPORT_FILE" || log "pvesm nicht verfügbar"

subheader "SMART-Status"
for disk in /dev/sda /dev/sdb /dev/nvme0n1; do
    if [ -b "$disk" ]; then
        log "\n${BOLD}$disk:${NC}"
        SMART_HEALTH=$(smartctl -H "$disk" 2>/dev/null | grep -i "SMART overall-health\|SMART Health Status" | head -1)
        if [ -n "$SMART_HEALTH" ]; then
            if echo "$SMART_HEALTH" | grep -qi "PASSED\|OK"; then
                log "${GREEN}✓ $SMART_HEALTH${NC}"
            else
                log "${RED}✗ $SMART_HEALTH${NC}"
            fi
        else
            log "${YELLOW}⚠ SMART nicht verfügbar für $disk${NC}"
        fi
        
        # Temperatur
        TEMP=$(smartctl -A "$disk" 2>/dev/null | grep -i "Temperature" | head -1 | awk '{print $10}')
        [ -n "$TEMP" ] && log "  Temperatur: ${TEMP}°C"
        
        # Power-On Hours
        POH=$(smartctl -A "$disk" 2>/dev/null | grep -i "Power_On_Hours\|Power On Hours" | awk '{print $NF}')
        [ -n "$POH" ] && log "  Betriebsstunden: $POH"
    fi
done

#===============================================================================
# 3. NETZWERK-STATUS
#===============================================================================

header "3. NETZWERK STATUS"

subheader "Netzwerk-Interfaces"
ip -br addr 2>/dev/null | tee -a "$REPORT_FILE"

subheader "Bridge-Status"
brctl show 2>/dev/null | tee -a "$REPORT_FILE" || log "brctl nicht verfügbar"

subheader "Routing-Tabelle"
ip route | tee -a "$REPORT_FILE"

subheader "DNS-Konfiguration (Host)"
cat /etc/resolv.conf 2>/dev/null | grep -v "^#" | tee -a "$REPORT_FILE"

subheader "Externe Konnektivität"
if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    check_status 0 "Internet erreichbar (8.8.8.8)"
else
    check_status 1 "Internet NICHT erreichbar (8.8.8.8)"
fi

if ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
    check_status 0 "Cloudflare DNS erreichbar (1.1.1.1)"
else
    check_status 1 "Cloudflare DNS NICHT erreichbar (1.1.1.1)"
fi

#===============================================================================
# 4. FIREWALL-STATUS
#===============================================================================

header "4. FIREWALL STATUS"

subheader "Proxmox Firewall"
pve-firewall status 2>/dev/null | tee -a "$REPORT_FILE" || log "pve-firewall nicht verfügbar"

subheader "Cluster Firewall Regeln"
if [ -f /etc/pve/firewall/cluster.fw ]; then
    log "\n${BOLD}/etc/pve/firewall/cluster.fw:${NC}"
    cat /etc/pve/firewall/cluster.fw 2>/dev/null | head -30 | tee -a "$REPORT_FILE"
else
    log "Keine Cluster-Firewall konfiguriert"
fi

#===============================================================================
# 5. CONTAINER-ÜBERSICHT
#===============================================================================

header "5. LXC CONTAINER ÜBERSICHT"

subheader "Alle Container"
pct list 2>/dev/null | tee -a "$REPORT_FILE"

# Detaillierte Container-Infos
log "\n${BOLD}Detaillierte Ressourcen:${NC}"
printf "%-6s %-15s %-8s %-18s %-8s %-8s %-8s\n" "VMID" "NAME" "STATUS" "IP" "RAM" "CPU" "DISK" | tee -a "$REPORT_FILE"
printf "%s\n" "────────────────────────────────────────────────────────────────────────────" | tee -a "$REPORT_FILE"

for VMID in $(pct list 2>/dev/null | awk 'NR>1 {print $1}' | sort -n); do
    NAME=$(pct config $VMID 2>/dev/null | grep "^hostname:" | awk '{print $2}')
    STATUS=$(pct status $VMID 2>/dev/null | awk '{print $2}')
    
    if [ "$STATUS" = "running" ]; then
        IP=$(pct exec $VMID -- hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")
        RAM=$(pct config $VMID 2>/dev/null | grep "^memory:" | awk '{print $2}')
        CPU=$(pct config $VMID 2>/dev/null | grep "^cores:" | awk '{print $2}')
        DISK=$(pct config $VMID 2>/dev/null | grep "^rootfs:" | grep -oP 'size=\K[^,]+')
        STATUS_COLOR="${GREEN}running${NC}"
    else
        IP="-"
        RAM=$(pct config $VMID 2>/dev/null | grep "^memory:" | awk '{print $2}')
        CPU=$(pct config $VMID 2>/dev/null | grep "^cores:" | awk '{print $2}')
        DISK=$(pct config $VMID 2>/dev/null | grep "^rootfs:" | grep -oP 'size=\K[^,]+')
        STATUS_COLOR="${RED}stopped${NC}"
    fi
    
    printf "%-6s %-15s ${STATUS_COLOR}  %-18s %-8s %-8s %-8s\n" "$VMID" "$NAME" "$IP" "${RAM}MB" "${CPU}" "$DISK" | tee -a "$REPORT_FILE"
done

#===============================================================================
# 6. CONTAINER-DETAILS
#===============================================================================

header "6. DETAILLIERTE CONTAINER-DIAGNOSE"

#-------------------------------------------------------------------------------
# CT 100 - NAS (Samba)
#-------------------------------------------------------------------------------
if pct status 100 &>/dev/null; then
    subheader "CT 100 - NAS (Samba)"
    
    STATUS=$(pct status 100 | awk '{print $2}')
    if [ "$STATUS" = "running" ]; then
        check_status 0 "Container läuft"
        
        # Samba Service
        if pct exec 100 -- systemctl is-active smbd &>/dev/null; then
            check_status 0 "Samba-Dienst (smbd) aktiv"
        else
            check_status 1 "Samba-Dienst (smbd) NICHT aktiv"
        fi
        
        if pct exec 100 -- systemctl is-active nmbd &>/dev/null; then
            check_status 0 "NetBIOS-Dienst (nmbd) aktiv"
        else
            check_status 1 "NetBIOS-Dienst (nmbd) NICHT aktiv"
        fi
        
        # Freigaben prüfen
        log "\n${BOLD}Samba-Freigaben:${NC}"
        pct exec 100 -- smbclient -L localhost -N 2>/dev/null | grep -E "^\s+(shared|media|backups)" | tee -a "$REPORT_FILE" || log "Keine Freigaben gefunden"
        
        # Mount-Points
        log "\n${BOLD}Mount-Points:${NC}"
        pct exec 100 -- df -h /srv/shared /srv/media /srv/backups 2>/dev/null | tee -a "$REPORT_FILE" || log "Mount-Points nicht verfügbar"
        
        # Aktive Verbindungen
        CONNECTIONS=$(pct exec 100 -- smbstatus -b 2>/dev/null | grep -c "^[0-9]" || echo "0")
        info_status "Aktive Samba-Verbindungen: $CONNECTIONS"
    else
        check_status 1 "Container gestoppt"
    fi
fi

#-------------------------------------------------------------------------------
# CT 101 - Pi-hole
#-------------------------------------------------------------------------------
if pct status 101 &>/dev/null; then
    subheader "CT 101 - Pi-hole (DNS/DHCP)"
    
    STATUS=$(pct status 101 | awk '{print $2}')
    if [ "$STATUS" = "running" ]; then
        check_status 0 "Container läuft"
        
        # Pi-hole Status
        PIHOLE_STATUS=$(pct exec 101 -- pihole status 2>/dev/null | head -5)
        log "\n${BOLD}Pi-hole Status:${NC}"
        echo "$PIHOLE_STATUS" | tee -a "$REPORT_FILE"
        
        # DNS-Test
        if pct exec 101 -- dig @127.0.0.1 google.com +short &>/dev/null; then
            check_status 0 "DNS-Auflösung funktioniert"
        else
            check_status 1 "DNS-Auflösung fehlgeschlagen"
        fi
        
        # DHCP-Leases
        LEASE_COUNT=$(pct exec 101 -- wc -l < /etc/pihole/dhcp.leases 2>/dev/null || echo "0")
        info_status "Aktive DHCP-Leases: $LEASE_COUNT"
        
        # Statistiken
        log "\n${BOLD}Letzte 24h Statistiken:${NC}"
        pct exec 101 -- pihole -c -e 2>/dev/null | head -10 | tee -a "$REPORT_FILE" || log "Statistiken nicht verfügbar"
        
        # Lokale DNS-Einträge
        log "\n${BOLD}Lokale DNS-Einträge (/etc/pihole/custom.list):${NC}"
        pct exec 101 -- cat /etc/pihole/custom.list 2>/dev/null | tee -a "$REPORT_FILE" || log "Keine lokalen DNS-Einträge"
    else
        check_status 1 "Container gestoppt"
    fi
fi

#-------------------------------------------------------------------------------
# CT 102 - WireGuard
#-------------------------------------------------------------------------------
if pct status 102 &>/dev/null; then
    subheader "CT 102 - WireGuard VPN"
    
    STATUS=$(pct status 102 | awk '{print $2}')
    if [ "$STATUS" = "running" ]; then
        check_status 0 "Container läuft"
        
        # Docker Status
        if pct exec 102 -- docker ps --format "{{.Names}}" 2>/dev/null | grep -q "wg-easy"; then
            check_status 0 "wg-easy Docker-Container läuft"
            
            # WireGuard Interface
            log "\n${BOLD}WireGuard Interface:${NC}"
            pct exec 102 -- docker exec wg-easy wg show 2>/dev/null | tee -a "$REPORT_FILE" || log "WG Interface nicht verfügbar"
            
            # Aktive Peers
            PEER_COUNT=$(pct exec 102 -- docker exec wg-easy wg show wg0 peers 2>/dev/null | wc -l || echo "0")
            info_status "Konfigurierte Peers: $PEER_COUNT"
            
            # Letzte Handshakes
            log "\n${BOLD}Letzte Handshakes:${NC}"
            pct exec 102 -- docker exec wg-easy wg show wg0 latest-handshakes 2>/dev/null | tee -a "$REPORT_FILE" || log "Keine Handshake-Daten"
        else
            check_status 1 "wg-easy Docker-Container läuft NICHT"
            log "\n${BOLD}Docker-Container:${NC}"
            pct exec 102 -- docker ps -a 2>/dev/null | tee -a "$REPORT_FILE"
        fi
    else
        check_status 1 "Container gestoppt"
    fi
fi

#-------------------------------------------------------------------------------
# CT 103 - Vaultwarden
#-------------------------------------------------------------------------------
if pct status 103 &>/dev/null; then
    subheader "CT 103 - Vaultwarden"
    
    STATUS=$(pct status 103 | awk '{print $2}')
    if [ "$STATUS" = "running" ]; then
        check_status 0 "Container läuft"
        
        # Docker Status
        if pct exec 103 -- docker ps --format "{{.Names}}" 2>/dev/null | grep -q "vaultwarden"; then
            check_status 0 "Vaultwarden Docker-Container läuft"
            
            # HTTP-Check
            if pct exec 103 -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 2>/dev/null | grep -q "200"; then
                check_status 0 "Vaultwarden Web-Interface erreichbar (Port 8081)"
            else
                warn_status "Vaultwarden Web-Interface nicht erreichbar"
            fi
            
            # Datenbank-Größe
            DB_SIZE=$(pct exec 103 -- du -h /srv/appdata/vaultwarden/db.sqlite3 2>/dev/null | awk '{print $1}' || echo "N/A")
            info_status "Datenbank-Größe: $DB_SIZE"
            
            # Container-Logs (letzte Fehler)
            log "\n${BOLD}Letzte Container-Logs:${NC}"
            pct exec 103 -- docker logs vaultwarden --tail 5 2>&1 | tee -a "$REPORT_FILE"
        else
            check_status 1 "Vaultwarden Docker-Container läuft NICHT"
            log "\n${BOLD}Docker-Container:${NC}"
            pct exec 103 -- docker ps -a 2>/dev/null | tee -a "$REPORT_FILE"
        fi
    else
        check_status 1 "Container gestoppt"
    fi
fi

#-------------------------------------------------------------------------------
# CT 104 - Nginx Proxy Manager
#-------------------------------------------------------------------------------
if pct status 104 &>/dev/null; then
    subheader "CT 104 - Nginx Proxy Manager"
    
    STATUS=$(pct status 104 | awk '{print $2}')
    if [ "$STATUS" = "running" ]; then
        check_status 0 "Container läuft"
        
        # Docker Status
        if pct exec 104 -- docker ps --format "{{.Names}}" 2>/dev/null | grep -q "npm"; then
            check_status 0 "NPM Docker-Container läuft"
            
            # Port-Check
            for PORT in 80 443 81; do
                if pct exec 104 -- ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
                    check_status 0 "Port $PORT lauscht"
                else
                    check_status 1 "Port $PORT lauscht NICHT"
                fi
            done
            
            # Nginx Config Test
            if pct exec 104 -- docker exec npm nginx -t &>/dev/null; then
                check_status 0 "Nginx-Konfiguration valide"
            else
                check_status 1 "Nginx-Konfiguration FEHLERHAFT"
            fi
            
            # SSL-Zertifikate
            log "\n${BOLD}SSL-Zertifikate:${NC}"
            pct exec 104 -- find /srv/appdata/nginx-proxy/letsencrypt/live -name "cert.pem" -exec dirname {} \; 2>/dev/null | while read cert_dir; do
                DOMAIN=$(basename "$cert_dir")
                EXPIRY=$(pct exec 104 -- openssl x509 -enddate -noout -in "$cert_dir/cert.pem" 2>/dev/null | cut -d= -f2)
                if [ -n "$EXPIRY" ]; then
                    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s 2>/dev/null)
                    NOW_EPOCH=$(date +%s)
                    DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
                    if [ "$DAYS_LEFT" -lt 7 ]; then
                        log "  ${RED}✗ $DOMAIN: Läuft ab in $DAYS_LEFT Tagen ($EXPIRY)${NC}"
                    elif [ "$DAYS_LEFT" -lt 30 ]; then
                        log "  ${YELLOW}⚠ $DOMAIN: Läuft ab in $DAYS_LEFT Tagen ($EXPIRY)${NC}"
                    else
                        log "  ${GREEN}✓ $DOMAIN: Gültig für $DAYS_LEFT Tage ($EXPIRY)${NC}"
                    fi
                fi
            done
        else
            check_status 1 "NPM Docker-Container läuft NICHT"
        fi
    else
        check_status 1 "Container gestoppt"
    fi
fi

#-------------------------------------------------------------------------------
# CT 105 - Jellyfin
#-------------------------------------------------------------------------------
if pct status 105 &>/dev/null; then
    subheader "CT 105 - Jellyfin"
    
    STATUS=$(pct status 105 | awk '{print $2}')
    if [ "$STATUS" = "running" ]; then
        check_status 0 "Container läuft"
        
        # Jellyfin Service
        if pct exec 105 -- systemctl is-active jellyfin &>/dev/null; then
            check_status 0 "Jellyfin-Dienst aktiv"
        else
            check_status 1 "Jellyfin-Dienst NICHT aktiv"
        fi
        
        # HTTP-Check
        HTTP_CODE=$(pct exec 105 -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8096 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
            check_status 0 "Web-Interface erreichbar (Port 8096)"
        else
            warn_status "Web-Interface nicht erreichbar (HTTP $HTTP_CODE)"
        fi
        
        # Media-Mount
        log "\n${BOLD}Media-Mount:${NC}"
        pct exec 105 -- df -h /media 2>/dev/null | tee -a "$REPORT_FILE" || log "Media nicht gemountet"
        
        # Media-Inhalt
        log "\n${BOLD}Media-Verzeichnisse:${NC}"
        pct exec 105 -- ls -la /media 2>/dev/null | tee -a "$REPORT_FILE" || log "Verzeichnis nicht zugänglich"
        
        # Bibliotheks-Statistiken
        if pct exec 105 -- ls /media/movies &>/dev/null; then
            MOVIE_COUNT=$(pct exec 105 -- ls -1 /media/movies 2>/dev/null | wc -l || echo "0")
            info_status "Filme: $MOVIE_COUNT"
        fi
        if pct exec 105 -- ls /media/music &>/dev/null; then
            MUSIC_COUNT=$(pct exec 105 -- ls -1 /media/music 2>/dev/null | wc -l || echo "0")
            info_status "Musik-Ordner: $MUSIC_COUNT"
        fi
    else
        check_status 1 "Container gestoppt"
    fi
fi

#-------------------------------------------------------------------------------
# CT 106 - Prometheus (falls vorhanden)
#-------------------------------------------------------------------------------
if pct status 106 &>/dev/null; then
    subheader "CT 106 - Prometheus"
    
    STATUS=$(pct status 106 | awk '{print $2}')
    if [ "$STATUS" = "running" ]; then
        check_status 0 "Container läuft"
        
        if pct exec 106 -- systemctl is-active prometheus &>/dev/null; then
            check_status 0 "Prometheus-Dienst aktiv"
        else
            check_status 1 "Prometheus-Dienst NICHT aktiv"
        fi
        
        # HTTP-Check
        HTTP_CODE=$(pct exec 106 -- curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ]; then
            check_status 0 "Prometheus Health-Check OK (Port 9090)"
        else
            warn_status "Prometheus Health-Check fehlgeschlagen"
        fi
        
        # Targets Status
        log "\n${BOLD}Scrape-Targets:${NC}"
        pct exec 106 -- curl -s http://localhost:9090/api/v1/targets 2>/dev/null | grep -oP '"health":"\K[^"]+' | sort | uniq -c | tee -a "$REPORT_FILE" || log "Targets nicht abrufbar"
    else
        check_status 1 "Container gestoppt"
    fi
fi

#-------------------------------------------------------------------------------
# CT 107 - Grafana (falls vorhanden)
#-------------------------------------------------------------------------------
if pct status 107 &>/dev/null; then
    subheader "CT 107 - Grafana"
    
    STATUS=$(pct status 107 | awk '{print $2}')
    if [ "$STATUS" = "running" ]; then
        check_status 0 "Container läuft"
        
        if pct exec 107 -- systemctl is-active grafana-server &>/dev/null; then
            check_status 0 "Grafana-Dienst aktiv"
        else
            check_status 1 "Grafana-Dienst NICHT aktiv"
        fi
        
        # HTTP-Check
        HTTP_CODE=$(pct exec 107 -- curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ]; then
            check_status 0 "Grafana Health-Check OK (Port 3000)"
        else
            warn_status "Grafana Health-Check fehlgeschlagen"
        fi
    else
        check_status 1 "Container gestoppt"
    fi
fi

#-------------------------------------------------------------------------------
# CT 108 - Proxmox Backup Server (falls vorhanden)
#-------------------------------------------------------------------------------
if pct status 108 &>/dev/null; then
    subheader "CT 108 - Proxmox Backup Server"
    
    STATUS=$(pct status 108 | awk '{print $2}')
    if [ "$STATUS" = "running" ]; then
        check_status 0 "Container läuft"
        
        if pct exec 108 -- systemctl is-active proxmox-backup-proxy &>/dev/null; then
            check_status 0 "PBS-Proxy-Dienst aktiv"
        else
            check_status 1 "PBS-Proxy-Dienst NICHT aktiv"
        fi
        
        if pct exec 108 -- systemctl is-active proxmox-backup &>/dev/null; then
            check_status 0 "PBS-Dienst aktiv"
        else
            check_status 1 "PBS-Dienst NICHT aktiv"
        fi
        
        # Port-Check
        if pct exec 108 -- ss -tlnp 2>/dev/null | grep -q ":8007 "; then
            check_status 0 "Web-Interface erreichbar (Port 8007)"
        else
            warn_status "Port 8007 lauscht nicht"
        fi
    else
        check_status 1 "Container gestoppt"
    fi
fi

#===============================================================================
# 7. EXTERNE ERREICHBARKEIT
#===============================================================================

header "7. EXTERNE ERREICHBARKEIT"

subheader "DuckDNS-Domains"

# DuckDNS IP-Check
log "\n${BOLD}Öffentliche IP:${NC}"
PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "Nicht ermittelbar")
log "Aktuelle öffentliche IP: $PUBLIC_IP"

for DOMAIN in rxfsys.duckdns.org vault-rxfsys.duckdns.org; do
    RESOLVED_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -1)
    if [ -n "$RESOLVED_IP" ]; then
        if [ "$RESOLVED_IP" = "$PUBLIC_IP" ]; then
            check_status 0 "$DOMAIN → $RESOLVED_IP (korrekt)"
        else
            warn_status "$DOMAIN → $RESOLVED_IP (erwartet: $PUBLIC_IP)"
        fi
    else
        check_status 1 "$DOMAIN konnte nicht aufgelöst werden"
    fi
done

subheader "Port-Forwarding Test"
info_status "Hinweis: Externe Port-Tests können nur von außen durchgeführt werden"
log "Konfigurierte Port-Weiterleitungen (laut Dokumentation):"
log "  • 51820/UDP → 192.168.2.123 (WireGuard)"
log "  • 80/TCP   → 192.168.2.125 (Nginx - Let's Encrypt)"
log "  • 443/TCP  → 192.168.2.125 (Nginx - HTTPS)"

#===============================================================================
# 8. DOCKER-ÜBERSICHT
#===============================================================================

header "8. DOCKER-CONTAINER ÜBERSICHT"

for VMID in 102 103 104; do
    if pct status $VMID &>/dev/null && [ "$(pct status $VMID | awk '{print $2}')" = "running" ]; then
        NAME=$(pct config $VMID | grep "^hostname:" | awk '{print $2}')
        log "\n${BOLD}CT $VMID ($NAME):${NC}"
        pct exec $VMID -- docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | tee -a "$REPORT_FILE" || log "Docker nicht verfügbar"
    fi
done

#===============================================================================
# 9. SYSTEM-LOGS (Fehler der letzten Stunde)
#===============================================================================

header "9. AKTUELLE SYSTEM-FEHLER"

subheader "Host-Fehler (letzte Stunde)"
journalctl -p err --since "1 hour ago" --no-pager 2>/dev/null | tail -20 | tee -a "$REPORT_FILE" || log "Keine Fehler gefunden"

subheader "Container-Fehler"
for VMID in $(pct list 2>/dev/null | awk 'NR>1 {print $1}' | sort -n); do
    if [ "$(pct status $VMID | awk '{print $2}')" = "running" ]; then
        NAME=$(pct config $VMID | grep "^hostname:" | awk '{print $2}')
        ERRORS=$(pct exec $VMID -- journalctl -p err --since "1 hour ago" --no-pager 2>/dev/null | head -5)
        if [ -n "$ERRORS" ]; then
            log "\n${BOLD}CT $VMID ($NAME):${NC}"
            echo "$ERRORS" | tee -a "$REPORT_FILE"
        fi
    fi
done

#===============================================================================
# 10. BACKUP-STATUS
#===============================================================================

header "10. BACKUP-STATUS"

subheader "Letzte Backups"
ls -lth /var/lib/vz/dump/*.tar.zst 2>/dev/null | head -10 | tee -a "$REPORT_FILE" || log "Keine lokalen Backups gefunden"

subheader "Backup-Speicherplatz"
du -sh /var/lib/vz/dump/ 2>/dev/null | tee -a "$REPORT_FILE" || log "Backup-Verzeichnis nicht zugänglich"

#===============================================================================
# ZUSAMMENFASSUNG
#===============================================================================

header "ZUSAMMENFASSUNG"

# Zähle Container-Status
TOTAL_CT=$(pct list 2>/dev/null | awk 'NR>1' | wc -l)
RUNNING_CT=$(pct list 2>/dev/null | awk 'NR>1 && $2=="running"' | wc -l)
STOPPED_CT=$((TOTAL_CT - RUNNING_CT))

log "${BOLD}Container:${NC}"
log "  Total: $TOTAL_CT | ${GREEN}Running: $RUNNING_CT${NC} | ${RED}Stopped: $STOPPED_CT${NC}"

# Speicher-Warnung
ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
STORAGE_USAGE=$(df /mnt/storage 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%' || echo "0")

log "\n${BOLD}Speicherauslastung:${NC}"
if [ "$ROOT_USAGE" -gt 80 ]; then
    log "  ${RED}✗ Root-Partition: ${ROOT_USAGE}% (kritisch!)${NC}"
elif [ "$ROOT_USAGE" -gt 60 ]; then
    log "  ${YELLOW}⚠ Root-Partition: ${ROOT_USAGE}%${NC}"
else
    log "  ${GREEN}✓ Root-Partition: ${ROOT_USAGE}%${NC}"
fi

if [ "$STORAGE_USAGE" -gt 80 ]; then
    log "  ${RED}✗ Storage: ${STORAGE_USAGE}% (kritisch!)${NC}"
elif [ "$STORAGE_USAGE" -gt 60 ]; then
    log "  ${YELLOW}⚠ Storage: ${STORAGE_USAGE}%${NC}"
else
    log "  ${GREEN}✓ Storage: ${STORAGE_USAGE}%${NC}"
fi

# RAM-Nutzung
RAM_USAGE=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
log "\n${BOLD}RAM-Auslastung:${NC}"
if [ "$RAM_USAGE" -gt 80 ]; then
    log "  ${RED}✗ RAM: ${RAM_USAGE}% (kritisch!)${NC}"
elif [ "$RAM_USAGE" -gt 60 ]; then
    log "  ${YELLOW}⚠ RAM: ${RAM_USAGE}%${NC}"
else
    log "  ${GREEN}✓ RAM: ${RAM_USAGE}%${NC}"
fi

#===============================================================================
# REPORT SPEICHERN
#===============================================================================

log "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
log "${GREEN}Report gespeichert unter: $REPORT_FILE${NC}"
log "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Optional: Report nach /mnt/storage kopieren
if [ -d "/mnt/storage" ]; then
    cp "$REPORT_FILE" "/mnt/storage/backups/diagnostics/" 2>/dev/null && \
    log "${GREEN}Report auch kopiert nach: /mnt/storage/backups/diagnostics/${NC}" || true
fi

exit 0