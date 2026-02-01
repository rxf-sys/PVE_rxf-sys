#!/bin/bash
#===============================================================================
# rxfsys Auto-Update Script
# Aktualisiert Host, alle LXC-Container und Docker-Images
# 
# Installation:
#   cp rxfsys-autoupdate.sh /usr/local/bin/
#   chmod +x /usr/local/bin/rxfsys-autoupdate.sh
#
# Cronjob (jeden Sonntag 04:00):
#   echo "0 4 * * 0 /usr/local/bin/rxfsys-autoupdate.sh >> /var/log/rxfsys-update.log 2>&1" | crontab -
#
# Manuell ausführen:
#   /usr/local/bin/rxfsys-autoupdate.sh
#===============================================================================

set -e

# Konfiguration
LOG_FILE="/var/log/rxfsys-update.log"
DOCKER_CONTAINERS="102 103 104"  # WireGuard, Vaultwarden, Nginx PM
NOTIFY_ON_ERROR=false            # Optional: E-Mail bei Fehler

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}✗${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
}

#===============================================================================
# START
#===============================================================================

log "═══════════════════════════════════════════════════════════════"
log "rxfsys Auto-Update gestartet"
log "═══════════════════════════════════════════════════════════════"

#===============================================================================
# 1. PROXMOX HOST UPDATE
#===============================================================================

log ""
log ">>> Proxmox Host aktualisieren..."

if apt update >> "$LOG_FILE" 2>&1; then
    log_success "apt update erfolgreich"
else
    log_error "apt update fehlgeschlagen"
fi

UPGRADES=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo "0")
if [ "$UPGRADES" -gt 0 ]; then
    log "  $UPGRADES Pakete verfügbar"
    if apt upgrade -y >> "$LOG_FILE" 2>&1; then
        log_success "Host-Upgrade erfolgreich"
    else
        log_error "Host-Upgrade fehlgeschlagen"
    fi
else
    log "  Keine Updates verfügbar"
fi

#===============================================================================
# 2. LXC CONTAINER UPDATES
#===============================================================================

log ""
log ">>> LXC Container aktualisieren..."

for VMID in $(pct list 2>/dev/null | awk 'NR>1 {print $1}' | sort -n); do
    NAME=$(pct config $VMID 2>/dev/null | grep "^hostname:" | awk '{print $2}')
    STATUS=$(pct status $VMID 2>/dev/null | awk '{print $2}')
    
    if [ "$STATUS" != "running" ]; then
        log_warn "CT $VMID ($NAME) - übersprungen (nicht gestartet)"
        continue
    fi
    
    log "  CT $VMID ($NAME)..."
    
    # apt update
    if pct exec $VMID -- apt update >> "$LOG_FILE" 2>&1; then
        # Anzahl verfügbarer Updates
        UPGRADES=$(pct exec $VMID -- apt list --upgradable 2>/dev/null | grep -c upgradable || echo "0")
        
        if [ "$UPGRADES" -gt 0 ]; then
            if pct exec $VMID -- apt upgrade -y >> "$LOG_FILE" 2>&1; then
                log_success "CT $VMID ($NAME) - $UPGRADES Pakete aktualisiert"
            else
                log_error "CT $VMID ($NAME) - Upgrade fehlgeschlagen"
            fi
        else
            log_success "CT $VMID ($NAME) - bereits aktuell"
        fi
    else
        log_error "CT $VMID ($NAME) - apt update fehlgeschlagen"
    fi
done

#===============================================================================
# 3. DOCKER IMAGE UPDATES
#===============================================================================

log ""
log ">>> Docker Images aktualisieren..."

for VMID in $DOCKER_CONTAINERS; do
    NAME=$(pct config $VMID 2>/dev/null | grep "^hostname:" | awk '{print $2}')
    STATUS=$(pct status $VMID 2>/dev/null | awk '{print $2}')
    
    if [ "$STATUS" != "running" ]; then
        log_warn "CT $VMID ($NAME) - übersprungen (nicht gestartet)"
        continue
    fi
    
    # Docker-Compose Verzeichnis finden
    COMPOSE_DIR=$(pct exec $VMID -- find /srv/appdata -name "docker-compose.yml" -printf "%h\n" 2>/dev/null | head -1)
    
    if [ -z "$COMPOSE_DIR" ]; then
        log_warn "CT $VMID ($NAME) - kein docker-compose.yml gefunden"
        continue
    fi
    
    log "  CT $VMID ($NAME) - Docker pull..."
    
    # Pull neue Images
    if pct exec $VMID -- bash -c "cd $COMPOSE_DIR && docker compose pull" >> "$LOG_FILE" 2>&1; then
        # Container mit neuen Images neu starten
        if pct exec $VMID -- bash -c "cd $COMPOSE_DIR && docker compose up -d" >> "$LOG_FILE" 2>&1; then
            log_success "CT $VMID ($NAME) - Docker aktualisiert"
        else
            log_error "CT $VMID ($NAME) - docker compose up fehlgeschlagen"
        fi
    else
        log_error "CT $VMID ($NAME) - docker pull fehlgeschlagen"
    fi
done

#===============================================================================
# 4. DOCKER CLEANUP
#===============================================================================

log ""
log ">>> Docker Cleanup (alte Images entfernen)..."

for VMID in $DOCKER_CONTAINERS; do
    STATUS=$(pct status $VMID 2>/dev/null | awk '{print $2}')
    
    if [ "$STATUS" = "running" ]; then
        pct exec $VMID -- docker image prune -f >> "$LOG_FILE" 2>&1
    fi
done
log_success "Docker Cleanup abgeschlossen"

#===============================================================================
# 5. SPEICHERPLATZ PRÜFEN
#===============================================================================

log ""
log ">>> Speicherplatz prüfen..."

# Host
ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$ROOT_USAGE" -gt 80 ]; then
    log_error "Host Root-Partition: ${ROOT_USAGE}% (kritisch!)"
else
    log_success "Host Root-Partition: ${ROOT_USAGE}%"
fi

# Storage
STORAGE_USAGE=$(df /mnt/storage 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%' || echo "0")
if [ "$STORAGE_USAGE" -gt 80 ]; then
    log_error "Storage: ${STORAGE_USAGE}% (kritisch!)"
elif [ "$STORAGE_USAGE" -gt 0 ]; then
    log_success "Storage: ${STORAGE_USAGE}%"
fi

#===============================================================================
# 6. SERVICES HEALTH CHECK
#===============================================================================

log ""
log ">>> Service Health Checks..."

# Pi-hole
if pct exec 101 -- systemctl is-active pihole-FTL &>/dev/null; then
    log_success "Pi-hole - läuft"
else
    log_error "Pi-hole - nicht aktiv!"
fi

# WireGuard
if pct exec 102 -- docker ps --format '{{.Names}}' 2>/dev/null | grep -q "wg-easy"; then
    log_success "WireGuard - läuft"
else
    log_error "WireGuard - nicht aktiv!"
fi

# Vaultwarden
if pct exec 103 -- docker ps --format '{{.Names}}' 2>/dev/null | grep -q "vaultwarden"; then
    log_success "Vaultwarden - läuft"
else
    log_error "Vaultwarden - nicht aktiv!"
fi

# Nginx
if pct exec 104 -- docker ps --format '{{.Names}}' 2>/dev/null | grep -q "npm"; then
    log_success "Nginx PM - läuft"
else
    log_error "Nginx PM - nicht aktiv!"
fi

# Jellyfin
if pct exec 105 -- systemctl is-active jellyfin &>/dev/null; then
    log_success "Jellyfin - läuft"
else
    log_error "Jellyfin - nicht aktiv!"
fi

# Prometheus
if pct exec 106 -- systemctl is-active prometheus &>/dev/null; then
    log_success "Prometheus - läuft"
else
    log_error "Prometheus - nicht aktiv!"
fi

# Grafana
if pct exec 107 -- systemctl is-active grafana-server &>/dev/null; then
    log_success "Grafana - läuft"
else
    log_error "Grafana - nicht aktiv!"
fi

# PBS
if pct exec 108 -- systemctl is-active proxmox-backup &>/dev/null; then
    log_success "PBS - läuft"
else
    log_error "PBS - nicht aktiv!"
fi

#===============================================================================
# ABSCHLUSS
#===============================================================================

log ""
log "═══════════════════════════════════════════════════════════════"
log "rxfsys Auto-Update abgeschlossen"
log "═══════════════════════════════════════════════════════════════"
log ""

# Optional: Reboot-Hinweis bei Kernel-Updates
if [ -f /var/run/reboot-required ]; then
    log_warn "NEUSTART ERFORDERLICH (Kernel-Update)"
fi

exit 0
