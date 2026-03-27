#!/bin/bash
# AmneziaWG Docker Setup Script
# Stateless container with host-based configuration

set -e

# Configuration variables
AWG_CONFIG_DIR="/opt/amnezia/awg"
AWG_PORT="${AWG_PORT:-51820}"
AWG_SUBNET_IP="${AWG_SUBNET_IP:-10.66.66.1}"
AWG_SUBNET_CIDR="${AWG_SUBNET_CIDR:-24}"
CONTAINER_NAME="amnezia-awg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

generate_obfuscation_params() {
    export JC=$(shuf -i 3-10 -n 1)
    export JMIN=$(shuf -i 50-100 -n 1)
    export JMAX=$(shuf -i 1000-1280 -n 1)
    
    export S1=$(shuf -i 15-150 -n 1)
    while true; do
        S2=$(shuf -i 15-150 -n 1)
        if [ $((S1 + 56)) -ne $S2 ] && [ $((S2 + 56)) -ne $S1 ]; then
            export S2
            break
        fi
    done
    
    export S3=$(shuf -i 15-150 -n 1)
    while true; do
        S4=$(shuf -i 15-150 -n 1)
        if [ $((S3 + 56)) -ne $S4 ] && [ $((S4 + 56)) -ne $S3 ]; then
            export S4
            break
        fi
    done
    
    local H1_START=$(shuf -i 5-536870911 -n 1)
    local H1_END=$(shuf -i $H1_START-1073741823 -n 1)
    export H1="${H1_START}-${H1_END}"
    
    local H2_START=$(shuf -i $((H1_END + 1))-1073741824 -n 1)
    local H2_END=$(shuf -i $H2_START-1610612735 -n 1)
    export H2="${H2_START}-${H2_END}"
    
    local H3_START=$(shuf -i $((H2_END + 1))-1610612736 -n 1)
    local H3_END=$(shuf -i $H3_START-2147483646 -n 1)
    export H3="${H3_START}-${H3_END}"
    
    local H4_START=$(shuf -i $((H3_END + 1))-2147483646 -n 1)
    export H4="${H4_START}-2147483647"
}

echo -e "${GREEN}=== AmneziaWG Docker Setup ===${NC}"
echo
echo "Configuration:"
echo "  VPN Subnet: ${AWG_SUBNET_IP}/${AWG_SUBNET_CIDR}"
echo "  VPN Port: ${AWG_PORT}"
echo "  Firewall: Managed by container (iptables inside)"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Run with: sudo $0"
    exit 1
fi

# Check for Docker
if ! command -v docker &>/dev/null; then
    echo -e "${YELLOW}Docker not found. Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${GREEN}✓ Docker found${NC}"
fi

# Check for conflicts with existing WireGuard
if ip link show wg0 &>/dev/null; then
    WG0_SUBNET=$(ip addr show wg0 | grep "inet " | awk '{print $2}')
    echo -e "${YELLOW}⚠ WARNING: Native WireGuard (wg0) detected with subnet: ${WG0_SUBNET}${NC}"
    echo "  Make sure your AmneziaWG subnet (${AWG_SUBNET_IP}/${AWG_SUBNET_CIDR}) doesn't conflict!"
    echo
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create DNS network
echo "[1/7] Creating Docker network..."
if ! docker network ls | grep -q amnezia-dns-net; then
    docker network create \
      --driver bridge \
      --subnet=172.29.172.0/24 \
      --opt com.docker.network.bridge.name=amn0 \
      amnezia-dns-net
    echo -e "${GREEN}✓ Network created${NC}"
else
    echo -e "${GREEN}✓ Network exists${NC}"
fi

# Create config directory
echo "[2/7] Creating configuration directory..."
mkdir -p "${AWG_CONFIG_DIR}"
chmod 700 "${AWG_CONFIG_DIR}"
echo -e "${GREEN}✓ Directory created: ${AWG_CONFIG_DIR}${NC}"

# Generate obfuscation parameters
echo "[3/7] Generating obfuscation parameters..."
generate_obfuscation_params

cat > "${AWG_CONFIG_DIR}/obfuscation-params.txt" <<PARAMS
# AmneziaWG Obfuscation Parameters
# Generated: $(date)
# IMPORTANT: These must match on server and ALL clients

Jc=${JC}
Jmin=${JMIN}
Jmax=${JMAX}
S1=${S1}
S2=${S2}
S3=${S3}
S4=${S4}
H1=${H1}
H2=${H2}
H3=${H3}
H4=${H4}
PARAMS
chmod 600 "${AWG_CONFIG_DIR}/obfuscation-params.txt"
echo -e "${GREEN}✓ Parameters generated${NC}"

# Generate server keys
echo "[4/7] Generating server keys..."
if [ ! -f "${AWG_CONFIG_DIR}/server_private.key" ]; then
    docker run --rm amneziavpn/amneziawg-go:latest awg genkey > "${AWG_CONFIG_DIR}/server_private.key"
    chmod 600 "${AWG_CONFIG_DIR}/server_private.key"
fi

if [ ! -f "${AWG_CONFIG_DIR}/server_public.key" ]; then
    docker run --rm -i amneziavpn/amneziawg-go:latest awg pubkey < "${AWG_CONFIG_DIR}/server_private.key" > "${AWG_CONFIG_DIR}/server_public.key"
    chmod 644 "${AWG_CONFIG_DIR}/server_public.key"
fi

if [ ! -f "${AWG_CONFIG_DIR}/preshared.key" ]; then
    docker run --rm amneziavpn/amneziawg-go:latest awg genpsk > "${AWG_CONFIG_DIR}/preshared.key"
    chmod 600 "${AWG_CONFIG_DIR}/preshared.key"
fi
echo -e "${GREEN}✓ Keys generated${NC}"

# Create server configuration
echo "[5/7] Creating server configuration..."
SERVER_PRIV_KEY=$(cat "${AWG_CONFIG_DIR}/server_private.key")

cat > "${AWG_CONFIG_DIR}/awg0.conf" <<SERVERCONF
[Interface]
PrivateKey = ${SERVER_PRIV_KEY}
Address = ${AWG_SUBNET_IP}/${AWG_SUBNET_CIDR}
ListenPort = ${AWG_PORT}
Jc = ${JC}
Jmin = ${JMIN}
Jmax = ${JMAX}
S1 = ${S1}
S2 = ${S2}
S3 = ${S3}
S4 = ${S4}
H1 = ${H1}
H2 = ${H2}
H3 = ${H3}
H4 = ${H4}

# Clients will be added below this line
SERVERCONF
chmod 600 "${AWG_CONFIG_DIR}/awg0.conf"
echo -e "${GREEN}✓ Server config created${NC}"

# Create startup script
echo "[6/7] Creating container startup script..."
cat > "${AWG_CONFIG_DIR}/start.sh" <<'STARTSCRIPT'
#!/bin/bash
set -e

echo "Starting AmneziaWG container..."

# Get VPN subnet from config
VPN_SUBNET=$(grep "^Address" /opt/amnezia/awg/awg0.conf | awk '{print $3}')
echo "VPN Subnet: ${VPN_SUBNET}"

# Bring down interface if already up
awg-quick down /opt/amnezia/awg/awg0.conf 2>/dev/null || true

# Start AWG interface
awg-quick up /opt/amnezia/awg/awg0.conf

# Configure firewall rules inside container
echo "Configuring firewall rules..."

# Allow traffic on awg0
iptables -A INPUT -i awg0 -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i awg0 -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -o awg0 -j ACCEPT 2>/dev/null || true

# Allow forwarding from awg0 to container's network interfaces
iptables -A FORWARD -i awg0 -o eth0 -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i awg0 -o eth1 -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -o awg0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

# NAT for VPN clients (to both eth0 and eth1 for multi-network containers)
iptables -t nat -A POSTROUTING -s ${VPN_SUBNET} -o eth0 -j MASQUERADE 2>/dev/null || true
iptables -t nat -A POSTROUTING -s ${VPN_SUBNET} -o eth1 -j MASQUERADE 2>/dev/null || true

echo "AmneziaWG started successfully"
echo "Listening on port ${AWG_PORT:-51820}"
echo "VPN subnet: ${VPN_SUBNET}"

# Keep container running
tail -f /dev/null
STARTSCRIPT
chmod +x "${AWG_CONFIG_DIR}/start.sh"
echo -e "${GREEN}✓ Startup script created${NC}"

# Enable IP forwarding
echo "[7/7] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null
if [ ! -f /etc/sysctl.d/99-amneziawg.conf ] || ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.d/99-amneziawg.conf 2>/dev/null; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/99-amneziawg.conf
fi
echo -e "${GREEN}✓ IP forwarding enabled${NC}"

# Pull Docker image
echo
echo "Pulling AmneziaWG Docker image..."
docker pull amneziavpn/amneziawg-go:latest

# Stop and remove existing container if it exists
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm ${CONTAINER_NAME} 2>/dev/null || true

# Run container
echo
echo "Starting AmneziaWG container..."
docker run -d \
  --name ${CONTAINER_NAME} \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  --privileged \
  -p ${AWG_PORT}:${AWG_PORT}/udp \
  -v /lib/modules:/lib/modules:ro \
  -v ${AWG_CONFIG_DIR}:/opt/amnezia/awg:rw \
  -e AWG_PORT=${AWG_PORT} \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  amneziavpn/amneziawg-go:latest \
  /opt/amnezia/awg/start.sh

# Connect to DNS network
docker network connect amnezia-dns-net ${CONTAINER_NAME} 2>/dev/null || true

# Wait for container to start
sleep 3

# Check if container is running
if docker ps | grep -q ${CONTAINER_NAME}; then
    echo -e "${GREEN}✓ Container started successfully${NC}"
else
    echo -e "${RED}✗ Container failed to start${NC}"
    echo "Check logs with: docker logs ${CONTAINER_NAME}"
    exit 1
fi

echo
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo
echo "Configuration directory: ${AWG_CONFIG_DIR}"
echo "Server listening on port: ${AWG_PORT}"
echo "VPN subnet: ${AWG_SUBNET_IP}/${AWG_SUBNET_CIDR}"
echo
echo -e "${YELLOW}⚠ FIREWALL CONFIGURATION REQUIRED:${NC}"
echo
echo "If using external firewall (cloud provider), configure:"
echo "  • Allow UDP port ${AWG_PORT} (inbound)"
echo
echo "The container handles NAT/forwarding automatically."
echo
echo -e "${GREEN}Next steps:${NC}"
echo "  1. Add a client:"
echo "     sudo bash add-client.sh laptop"
echo
echo "  2. Check server status:"
echo "     sudo bash manage.sh status"
echo
echo "  3. View container logs:"
echo "     docker logs ${CONTAINER_NAME}"
echo
