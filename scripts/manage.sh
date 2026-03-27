#!/bin/bash
# AmneziaWG Management Script

AWG_CONFIG_DIR="/opt/amnezia/awg"
CONTAINER_NAME="amnezia-awg"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

show_usage() {
    cat <<USAGE
AmneziaWG Management Tool

Usage: $0 <command>

Commands:
  status              Show server status and active connections
  list                List all configured clients
  show                Show server configuration details
  logs                Show container logs
  restart             Restart the VPN container
  stop                Stop the VPN container
  start               Start the VPN container
  backup              Backup configuration to tar.gz
  
Examples:
  $0 status
  $0 list
  $0 logs
  $0 backup

USAGE
}

check_setup() {
    if [ ! -d "$AWG_CONFIG_DIR" ]; then
        echo -e "${RED}Error: Configuration directory $AWG_CONFIG_DIR does not exist${NC}"
        echo "Run setup.sh first"
        exit 1
    fi
}

cmd_status() {
    echo -e "${GREEN}=== AmneziaWG Server Status ===${NC}"
    echo
    
    # Container status
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${GREEN}Container: RUNNING${NC}"
        UPTIME=$(docker inspect -f '{{.State.StartedAt}}' ${CONTAINER_NAME} | cut -d'.' -f1)
        echo "Started: $UPTIME"
    else
        echo -e "${RED}Container: STOPPED${NC}"
        return 1
    fi
    
    echo
    echo "--- Interface Status ---"
    docker exec ${CONTAINER_NAME} awg show awg0 2>/dev/null || echo "Interface not found"
    
    echo
    echo "--- Active Peers ---"
    PEER_COUNT=$(docker exec ${CONTAINER_NAME} awg show awg0 peers 2>/dev/null | wc -l)
    echo "Total peers configured: $PEER_COUNT"
    
    if [ $PEER_COUNT -gt 0 ]; then
        docker exec ${CONTAINER_NAME} awg show awg0 dump 2>/dev/null | tail -n +2 | while read -r line; do
            PUB_KEY=$(echo "$line" | awk '{print $1}' | cut -c1-20)
            ENDPOINT=$(echo "$line" | awk '{print $3}')
            RX=$(echo "$line" | awk '{print $6}')
            TX=$(echo "$line" | awk '{print $7}')
            HANDSHAKE=$(echo "$line" | awk '{print $5}')
            
            if [ "$ENDPOINT" != "(none)" ]; then
                echo -e "  ${GREEN}✓${NC} Peer: $PUB_KEY... | Endpoint: $ENDPOINT | RX: $RX | TX: $TX"
            else
                echo -e "  ${YELLOW}○${NC} Peer: $PUB_KEY... | Not connected"
            fi
        done
    fi
    
    echo
    echo "--- Port Binding ---"
    docker port ${CONTAINER_NAME} 2>/dev/null || echo "No ports published"
}

cmd_list() {
    echo -e "${GREEN}=== Configured Clients ===${NC}"
    echo
    
    if [ ! -d "${AWG_CONFIG_DIR}/clients" ] || [ -z "$(ls -A ${AWG_CONFIG_DIR}/clients 2>/dev/null)" ]; then
        echo "No clients configured yet"
        echo
        echo "Add a client with:"
        echo "  sudo bash add-client.sh <name>"
        return
    fi
    
    for conf in ${AWG_CONFIG_DIR}/clients/*.conf; do
        if [ -f "$conf" ]; then
            CLIENT_NAME=$(basename "$conf" .conf)
            CLIENT_IP=$(grep "^Address = " "$conf" | awk '{print $3}' | cut -d'/' -f1)
            echo "  - $CLIENT_NAME (IP: $CLIENT_IP)"
        fi
    done
}

cmd_show() {
    echo -e "${GREEN}=== Server Configuration ===${NC}"
    echo
    echo "Config directory: ${AWG_CONFIG_DIR}"
    echo
    
    if [ -f "${AWG_CONFIG_DIR}/awg0.conf" ]; then
        echo "Listen Port: $(grep '^ListenPort = ' ${AWG_CONFIG_DIR}/awg0.conf | awk '{print $3}')"
        echo "Server IP: $(grep '^Address = ' ${AWG_CONFIG_DIR}/awg0.conf | awk '{print $3}')"
        echo
        echo "Obfuscation Parameters:"
        grep -E '^(Jc|Jmin|Jmax|S1|S2|S3|S4|H1|H2|H3|H4) = ' ${AWG_CONFIG_DIR}/awg0.conf | sed 's/^/  /'
    else
        echo "Server config not found"
    fi
}

cmd_logs() {
    echo -e "${GREEN}=== Container Logs (last 50 lines) ===${NC}"
    docker logs --tail 50 ${CONTAINER_NAME}
}

cmd_restart() {
    echo "Restarting AmneziaWG container..."
    docker restart ${CONTAINER_NAME}
    echo -e "${GREEN}✓ Container restarted${NC}"
}

cmd_stop() {
    echo "Stopping AmneziaWG container..."
    docker stop ${CONTAINER_NAME}
    echo -e "${GREEN}✓ Container stopped${NC}"
}

cmd_start() {
    echo "Starting AmneziaWG container..."
    docker start ${CONTAINER_NAME}
    echo -e "${GREEN}✓ Container started${NC}"
}

cmd_backup() {
    BACKUP_FILE="amneziawg-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    echo "Creating backup: $BACKUP_FILE"
    tar -czf "$BACKUP_FILE" -C "${AWG_CONFIG_DIR}" .
    echo -e "${GREEN}✓ Backup created: $(pwd)/$BACKUP_FILE${NC}"
    echo
    echo "To restore:"
    echo "  tar -xzf $BACKUP_FILE -C ${AWG_CONFIG_DIR}"
    echo "  docker restart ${CONTAINER_NAME}"
}

# Main
case "${1:-}" in
    status)
        check_setup
        cmd_status
        ;;
    list)
        check_setup
        cmd_list
        ;;
    show)
        check_setup
        cmd_show
        ;;
    logs)
        cmd_logs
        ;;
    restart)
        cmd_restart
        ;;
    stop)
        cmd_stop
        ;;
    start)
        cmd_start
        ;;
    backup)
        check_setup
        cmd_backup
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
