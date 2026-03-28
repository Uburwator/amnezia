#!/bin/bash
# AmneziaWG Add Client Script
# Adds new VPN clients with hot reload (no container restart)
# Generates working QR codes (Format 12 - iOS/Android compatible)

set -e

AWG_CONFIG_DIR="/opt/amnezia/awg"
CONTAINER_NAME="amnezia-awg"
CLIENT_NAME="${1}"
SERVER_ENDPOINT="${SERVER_ENDPOINT:-}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "$CLIENT_NAME" ]; then
    cat <<USAGE
Usage: $0 <client-name>

Environment variables:
  SERVER_ENDPOINT  Server IP or DNS name (auto-detected if not set)

Examples:
  $0 laptop
  SERVER_ENDPOINT=vpn.example.com $0 laptop
  SERVER_ENDPOINT=203.0.113.5 $0 laptop
USAGE
    exit 1
fi

if ! [[ "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "${RED}Error: Client name must contain only letters, numbers, dash, and underscore${NC}"
    exit 1
fi

if [ ! -d "$AWG_CONFIG_DIR" ]; then
    echo -e "${RED}Error: Config directory $AWG_CONFIG_DIR does not exist${NC}"
    echo "Run setup.sh first"
    exit 1
fi

if [ -f "${AWG_CONFIG_DIR}/clients/${CLIENT_NAME}.conf" ]; then
    echo -e "${RED}Error: Client '$CLIENT_NAME' already exists${NC}"
    echo
    echo "Existing clients:"
    ls -1 ${AWG_CONFIG_DIR}/clients/*.conf 2>/dev/null | xargs -n1 basename -s .conf | sed 's/^/  - /' || echo "  (none)"
    exit 1
fi

mkdir -p "${AWG_CONFIG_DIR}/clients"
chmod 700 "${AWG_CONFIG_DIR}/clients"

echo -e "${GREEN}=== Adding AmneziaWG Client: $CLIENT_NAME ===${NC}"
echo

# Read obfuscation parameters from server config
echo "[*] Reading server configuration..."
JC=$(grep "^Jc = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}')
JMIN=$(grep "^Jmin = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}')
JMAX=$(grep "^Jmax = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}')
S1=$(grep "^S1 = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}')
S2=$(grep "^S2 = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}')
S3=$(grep "^S3 = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}')
S4=$(grep "^S4 = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}')
H1=$(grep "^H1 = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}')
H2=$(grep "^H2 = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}')
H3=$(grep "^H3 = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}')
H4=$(grep "^H4 = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}')

if [ -z "$JC" ] || [ -z "$S1" ] || [ -z "$H1" ]; then
    echo -e "${RED}Error: Could not read obfuscation parameters${NC}"
    exit 1
fi

echo "    ✓ Obfuscation params loaded"

# Read server keys and config
SERVER_PUB_KEY=$(cat "${AWG_CONFIG_DIR}/server_public.key")
PSK_KEY=$(cat "${AWG_CONFIG_DIR}/preshared.key")
AWG_PORT=$(grep "^ListenPort = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}')
SUBNET_IP=$(grep "^Address = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}' | cut -d'/' -f1)

# Determine server endpoint
if [ -z "$SERVER_ENDPOINT" ]; then
    echo
    echo "Server endpoint not set. How would you like to proceed?"
    echo "  1) Auto-detect from network interface (IPv4 only)"
    echo "  2) Enter manually (IP or DNS name)"
    echo
    read -p "Choose [1/2]: " CHOICE
    
    if [ "$CHOICE" = "1" ]; then
        echo "[*] Auto-detecting IPv4 address from network interface..."
        # Get IPv4 from primary interface (avoid IPv6)
        SERVER_ENDPOINT=$(ip -4 addr show scope global | grep inet | head -1 | awk '{print $2}' | cut -d'/' -f1)
        
        if [ -z "$SERVER_ENDPOINT" ]; then
            echo -e "${YELLOW}    Could not detect IPv4 from interface${NC}"
            read -p "Enter server IP or DNS name: " SERVER_ENDPOINT
        else
            echo "    Detected IPv4: $SERVER_ENDPOINT"
            read -p "Use this address? [Y/n]: " CONFIRM
            if [[ $CONFIRM =~ ^[Nn]$ ]]; then
                read -p "Enter server IP or DNS name: " SERVER_ENDPOINT
            fi
        fi
    else
        read -p "Enter server IP or DNS name: " SERVER_ENDPOINT
    fi
    
    if [ -z "$SERVER_ENDPOINT" ]; then
        echo -e "${RED}Error: Server endpoint required${NC}"
        exit 1
    fi
else
    echo "[*] Using endpoint: $SERVER_ENDPOINT"
fi

# Find next available IP
LAST_OCTET=1
if grep -q "^\[Peer\]" "${AWG_CONFIG_DIR}/awg0.conf"; then
    HIGHEST_IP=$(grep "AllowedIPs = " "${AWG_CONFIG_DIR}/awg0.conf" | awk '{print $3}' | cut -d'/' -f1 | sort -t. -k4 -n | tail -1)
    LAST_OCTET=$(echo "$HIGHEST_IP" | cut -d'.' -f4)
fi

NEXT_OCTET=$((LAST_OCTET + 1))
if [ $NEXT_OCTET -ge 255 ]; then
    echo -e "${RED}Error: No more IP addresses available${NC}"
    exit 1
fi

SUBNET_PREFIX=$(echo "$SUBNET_IP" | cut -d'.' -f1-3)
CLIENT_IP="${SUBNET_PREFIX}.${NEXT_OCTET}"
echo "    ✓ Assigned IP: $CLIENT_IP"

echo
echo "[1/5] Generating client keys..."
CLIENT_PRIV_KEY=$(docker run --rm amneziavpn/amneziawg-go:latest awg genkey)
CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | docker run --rm -i amneziavpn/amneziawg-go:latest awg pubkey)
echo "    ✓ Keys generated"

echo "[2/5] Adding peer to server..."
cat >> "${AWG_CONFIG_DIR}/awg0.conf" <<PEER

[Peer]
# Client: ${CLIENT_NAME}
PublicKey = ${CLIENT_PUB_KEY}
PresharedKey = ${PSK_KEY}
AllowedIPs = ${CLIENT_IP}/32
PEER
echo "    ✓ Peer added"

echo "[3/5] Reloading server config..."
docker exec ${CONTAINER_NAME} sh -c "awg-quick strip /opt/amnezia/awg/awg0.conf > /tmp/awg0-stripped.conf" 2>/dev/null
docker exec ${CONTAINER_NAME} awg syncconf awg0 /tmp/awg0-stripped.conf
docker exec ${CONTAINER_NAME} rm /tmp/awg0-stripped.conf
echo "    ✓ Config reloaded (no restart)"

echo "[4/5] Generating client config..."

# HTTP/DNS Signature Packets
I1='<b 0x474554202f20485454502f312e310d0a486f73743a20>'
I2='<rc 7><b 0x2e636f6d0d0a>'
I3='<b 0x557365722d4167656e743a204d6f7a696c6c612f352e300d0a>'
I4='<b 0x436f6e6e656374696f6e3a206b6565702d616c6976650d0a0d0a><r 20>'
I5='<t><b 0x0100000100000000000000><rc 6><b 0x03636f6d000001000001>'

cat > "${AWG_CONFIG_DIR}/clients/${CLIENT_NAME}.conf" <<CLIENTCONF
[Interface]
Address = ${CLIENT_IP}/32
DNS = 1.1.1.1, 1.0.0.1
PrivateKey = ${CLIENT_PRIV_KEY}
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
I1 = ${I1}
I2 = ${I2}
I3 = ${I3}
I4 = ${I4}
I5 = ${I5}

[Peer]
PublicKey = ${SERVER_PUB_KEY}
PresharedKey = ${PSK_KEY}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${SERVER_ENDPOINT}:${AWG_PORT}
PersistentKeepalive = 25
CLIENTCONF

chmod 600 "${AWG_CONFIG_DIR}/clients/${CLIENT_NAME}.conf"
echo "    ✓ Client config created"

echo "[5/5] Generating QR code..."

# Generate QR code using Format 12 (matches file import exactly)
if command -v python3 &>/dev/null && command -v qrencode &>/dev/null; then
    python3 - "${AWG_CONFIG_DIR}/clients/${CLIENT_NAME}.conf" "${SERVER_ENDPOINT}" "${AWG_PORT}" "${CLIENT_PRIV_KEY}" "${CLIENT_IP}" "${SERVER_PUB_KEY}" "${PSK_KEY}" "${JC}" "${JMIN}" "${JMAX}" "${S1}" "${S2}" "${S3}" "${S4}" "${H1}" "${H2}" "${H3}" "${H4}" "${I1}" "${I2}" "${I3}" "${I4}" "${I5}" <<'PYTHON_SCRIPT'
import sys
import json
import zlib
import base64
import subprocess

config_file = sys.argv[1]
server_ip = sys.argv[2]
server_port = sys.argv[3]
client_priv_key = sys.argv[4]
client_ip = sys.argv[5]
server_pub_key = sys.argv[6]
psk_key = sys.argv[7]
jc, jmin, jmax = sys.argv[8], sys.argv[9], sys.argv[10]
s1, s2, s3, s4 = sys.argv[11], sys.argv[12], sys.argv[13], sys.argv[14]
h1, h2, h3, h4 = sys.argv[15], sys.argv[16], sys.argv[17], sys.argv[18]
i1, i2, i3, i4, i5 = sys.argv[19], sys.argv[20], sys.argv[21], sys.argv[22], sys.argv[23]

# Read full config text
with open(config_file, 'r') as f:
    config_text = f.read()

# Create lastConfig with UPPERCASE field names (as they appear in config file!)
# This matches what extractWireGuardConfig() creates
last_config = {
    "config": config_text,
    "hostName": server_ip,
    "port": int(server_port),
    "client_priv_key": client_priv_key,
    "client_ip": client_ip,
    "server_pub_key": server_pub_key,
    "psk_key": psk_key,
    "mtu": "1280",
    "persistent_keep_alive": "25",
    "allowed_ips": ["0.0.0.0/0", "::/0"],
    
    # UPPERCASE field names (as they appear in .conf file)
    "Jc": jc,
    "Jmin": jmin,
    "Jmax": jmax,
    "S1": s1,
    "S2": s2,
    "S3": s3,
    "S4": s4,
    "H1": h1,
    "H2": h2,
    "H3": h3,
    "H4": h4,
    "I1": i1,
    "I2": i2,
    "I3": i3,
    "I4": i4,
    "I5": i5,
}

# Create AWG protocol config (matching extractWireGuardConfig output)
awg_protocol_config = {
    "last_config": json.dumps(last_config, separators=(',', ':')),
    "isThirdPartyConfig": True,
    "port": int(server_port),
    "protocol_version": "2",  # Critical for v2 recognition!
    "transport_proto": "udp"
}

# Use "amnezia-awg" (v1 container name) + protocol_version="2"
server_config = {
    "containers": [{
        "container": "amnezia-awg",  # v1 name, not awg2!
        "awg": awg_protocol_config
    }],
    "defaultContainer": "amnezia-awg",
    "description": "AmneziaWG",
    "dns1": "1.1.1.1",
    "dns2": "1.0.0.1",
    "hostName": server_ip
}

# Compress and encode (NO vpn:// prefix!)
json_data = json.dumps(server_config, separators=(',', ':')).encode('utf-8')
compressed = zlib.compress(json_data, 8)
qt_compressed = len(json_data).to_bytes(4, 'big') + compressed
b64_data = base64.urlsafe_b64encode(qt_compressed).decode('ascii').rstrip('=')

# Display QR in terminal
print()
try:
    subprocess.run(['qrencode', '-t', 'ansiutf8', b64_data], check=True)
    
    # Save as PNG
    qr_png = config_file.replace('.conf', '-qr.png')
    subprocess.run(['qrencode', '-t', 'PNG', '-o', qr_png, '-s', '8', b64_data], check=True)
    print(f"\n    ✓ QR code saved: {qr_png}")
    print(f"      Format: AWG v2 (iOS/Android compatible)")
    print(f"      Size: {len(b64_data)} bytes")
    
except Exception as e:
    print(f"    ✗ QR generation failed: {e}")

PYTHON_SCRIPT
else
    if ! command -v python3 &>/dev/null; then
        echo -e "${YELLOW}    ⚠ Python3 not installed - QR code skipped${NC}"
        echo "      Install with: apt install python3 qrencode"
    elif ! command -v qrencode &>/dev/null; then
        echo -e "${YELLOW}    ⚠ qrencode not installed - QR code skipped${NC}"
        echo "      Install with: apt install qrencode"
    fi
fi

echo
echo "=== Client Added Successfully! ==="
echo
echo "Client: ${CLIENT_NAME}"
echo "  VPN IP: ${CLIENT_IP}"
echo "  Endpoint: ${SERVER_ENDPOINT}:${AWG_PORT}"
echo "  Config: ${AWG_CONFIG_DIR}/clients/${CLIENT_NAME}.conf"
if [ -f "${AWG_CONFIG_DIR}/clients/${CLIENT_NAME}-qr.png" ]; then
    echo "  QR Code: ${AWG_CONFIG_DIR}/clients/${CLIENT_NAME}-qr.png"
fi
echo
echo "Import to AmneziaVPN app:"
echo "  Option 1 (QR Code - Recommended):"
echo "    • Scan the QR code above or open the PNG file"
echo "    • AmneziaVPN app will import automatically"
echo
echo "  Option 2 (File Import):"
echo "    1. Copy config to your device:"
echo "       scp root@server:${AWG_CONFIG_DIR}/clients/${CLIENT_NAME}.conf ."
echo "    2. AmneziaVPN app → Settings → Import from file"
echo
echo "Verify connection:"
echo "  docker exec ${CONTAINER_NAME} awg show awg0"
echo "  (Should show endpoint + handshake after client connects)"
echo
