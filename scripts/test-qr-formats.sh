#!/bin/bash
# Test Multiple QR Code Formats for AmneziaVPN iOS App
# Generates 5 different QR code formats to test compatibility

CLIENT_CONFIG="${1}"

if [ -z "$CLIENT_CONFIG" ] || [ ! -f "$CLIENT_CONFIG" ]; then
    echo "Usage: $0 <path-to-client-config.conf>"
    echo
    echo "Example:"
    echo "  $0 /opt/amnezia/awg/clients/laptop.conf"
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo "Error: python3 not found"
    echo "Install with: apt install python3"
    exit 1
fi

echo "=== Testing QR Code Formats for AmneziaVPN ==="
echo "Config file: $CLIENT_CONFIG"
echo

# Extract endpoint
ENDPOINT=$(grep "^Endpoint = " "$CLIENT_CONFIG" | awk '{print $3}')
SERVER_IP=$(echo "$ENDPOINT" | cut -d':' -f1)
SERVER_PORT=$(echo "$ENDPOINT" | cut -d':' -f2)

echo "Server: $SERVER_IP:$SERVER_PORT"
echo
echo "Generating 5 different QR code formats..."
echo

python3 - "$CLIENT_CONFIG" "$SERVER_IP" "$SERVER_PORT" << 'PYTHON_SCRIPT'
import sys
import json
import zlib
import base64

config_file = sys.argv[1]
server_ip = sys.argv[2]
server_port = sys.argv[3]

# Read config
with open(config_file, 'r') as f:
    config_text = f.read()

# Parse config to map
config_map = {}
for line in config_text.split('\n'):
    line = line.strip()
    if ' = ' in line and not line.startswith('[') and not line.startswith('#'):
        parts = line.split(' = ', 1)
        if len(parts) == 2:
            config_map[parts[0]] = parts[1]

print("=" * 70)
print("FORMAT 1: Plain Text WireGuard Config")
print("=" * 70)
print("Description: Raw .conf file content")
print()
print("QR Data Length:", len(config_text), "bytes")
print()
print("--- QR CODE DATA ---")
print(config_text[:200] + "..." if len(config_text) > 200 else config_text)
print()
try:
    import subprocess
    subprocess.run(['qrencode', '-t', 'ansiutf8', config_text], check=True)
except:
    print("(qrencode not available)")
print()

print("=" * 70)
print("FORMAT 2: Minimal JSON (Uncompressed)")
print("=" * 70)
print("Description: Minimal JSON structure without compression")
print()

minimal_json = {
    "containers": [{
        "container": "amnezia-awg",
        "awg": {
            "config": config_text,
            "hostName": server_ip,
            "port": int(server_port)
        }
    }],
    "defaultContainer": "amnezia-awg",
    "hostName": server_ip
}

minimal_json_str = json.dumps(minimal_json, separators=(',', ':'))
print("QR Data Length:", len(minimal_json_str), "bytes")
print()
print("--- QR CODE DATA ---")
print(minimal_json_str[:200] + "..." if len(minimal_json_str) > 200 else minimal_json_str)
print()
try:
    import subprocess
    subprocess.run(['qrencode', '-t', 'ansiutf8', minimal_json_str], check=True)
except:
    print("(qrencode not available)")
print()

print("=" * 70)
print("FORMAT 3: Minimal JSON + Base64 (No Compression)")
print("=" * 70)
print("Description: Base64-encoded JSON without compression")
print()

b64_minimal = base64.urlsafe_b64encode(minimal_json_str.encode('utf-8')).decode('ascii').rstrip('=')
vpn_url_minimal = f"vpn://{b64_minimal}"

print("QR Data Length:", len(vpn_url_minimal), "bytes")
print()
print("--- QR CODE DATA ---")
print(vpn_url_minimal[:100] + "..." if len(vpn_url_minimal) > 100 else vpn_url_minimal)
print()
try:
    import subprocess
    subprocess.run(['qrencode', '-t', 'ansiutf8', vpn_url_minimal], check=True)
except:
    print("(qrencode not available)")
print()

print("=" * 70)
print("FORMAT 4: Full JSON + zlib + Qt Header + Base64")
print("=" * 70)
print("Description: Official format with all fields")
print()

full_awg_config = {
    "config": config_text,
    "hostName": server_ip,
    "port": int(server_port),
    "client_priv_key": config_map.get("PrivateKey", ""),
    "client_ip": config_map.get("Address", "").replace("/32", ""),
    "server_pub_key": config_map.get("PublicKey", ""),
    "psk_key": config_map.get("PresharedKey", ""),
    "mtu": "1280",
    "persistent_keep_alive": "25",
    "allowed_ips": ["0.0.0.0/0", "::/0"],
    "junkPacketCount": config_map.get("Jc", ""),
    "junkPacketMinSize": config_map.get("Jmin", ""),
    "junkPacketMaxSize": config_map.get("Jmax", ""),
    "initPacketJunkSize": config_map.get("S1", ""),
    "responsePacketJunkSize": config_map.get("S2", ""),
    "cookieReplyPacketJunkSize": config_map.get("S3", ""),
    "transportPacketJunkSize": config_map.get("S4", ""),
    "initPacketMagicHeader": config_map.get("H1", ""),
    "responsePacketMagicHeader": config_map.get("H2", ""),
    "underloadPacketMagicHeader": config_map.get("H3", ""),
    "transportPacketMagicHeader": config_map.get("H4", ""),
    "specialJunk1": config_map.get("I1", ""),
    "specialJunk2": config_map.get("I2", ""),
    "specialJunk3": config_map.get("I3", ""),
    "specialJunk4": config_map.get("I4", ""),
    "specialJunk5": config_map.get("I5", ""),
}

full_server_config = {
    "containers": [{
        "container": "amnezia-awg",
        "awg": full_awg_config
    }],
    "defaultContainer": "amnezia-awg",
    "description": "AmneziaWG",
    "dns1": "1.1.1.1",
    "dns2": "1.0.0.1",
    "hostName": server_ip
}

json_data = json.dumps(full_server_config, separators=(',', ':')).encode('utf-8')
compressed = zlib.compress(json_data, 8)
qt_compressed = len(json_data).to_bytes(4, 'big') + compressed
b64_full = base64.urlsafe_b64encode(qt_compressed).decode('ascii').rstrip('=')
vpn_url_full = f"vpn://{b64_full}"

print("Uncompressed JSON:", len(json_data), "bytes")
print("Compressed:", len(qt_compressed), "bytes")
print("Base64:", len(vpn_url_full), "bytes")
print()
print("--- QR CODE DATA ---")
print(vpn_url_full[:100] + "..." if len(vpn_url_full) > 100 else vpn_url_full)
print()
try:
    import subprocess
    subprocess.run(['qrencode', '-t', 'ansiutf8', vpn_url_full], check=True)
except:
    print("(qrencode not available)")
print()

print("=" * 70)
print("FORMAT 5: Compact JSON (Minimal Fields) + Compression")
print("=" * 70)
print("Description: Only essential fields, compressed")
print()

compact_awg_config = {
    "config": config_text,
    "hostName": server_ip,
    "port": int(server_port),
    "mtu": "1280"
}

compact_server_config = {
    "containers": [{
        "container": "amnezia-awg",
        "awg": compact_awg_config
    }],
    "defaultContainer": "amnezia-awg",
    "hostName": server_ip
}

json_compact = json.dumps(compact_server_config, separators=(',', ':')).encode('utf-8')
compressed_compact = zlib.compress(json_compact, 8)
qt_compact = len(json_compact).to_bytes(4, 'big') + compressed_compact
b64_compact = base64.urlsafe_b64encode(qt_compact).decode('ascii').rstrip('=')
vpn_url_compact = f"vpn://{b64_compact}"

print("Uncompressed JSON:", len(json_compact), "bytes")
print("Compressed:", len(qt_compact), "bytes")
print("Base64:", len(vpn_url_compact), "bytes")
print()
print("--- QR CODE DATA ---")
print(vpn_url_compact[:100] + "..." if len(vpn_url_compact) > 100 else vpn_url_compact)
print()
try:
    import subprocess
    subprocess.run(['qrencode', '-t', 'ansiutf8', vpn_url_compact], check=True)
except:
    print("(qrencode not available)")
print()

print("=" * 70)
print("SUMMARY")
print("=" * 70)
print()
print("Format 1: Plain text (largest, simplest)")
print("Format 2: JSON uncompressed (large)")
print("Format 3: JSON + Base64 only (medium)")
print("Format 4: Full official format (medium-large)")
print("Format 5: Compact + compressed (smallest)")
print()
print("Try scanning each QR code with AmneziaVPN app (iOS)")
print("Test them in order: 5, 3, 1, 4, 2")
print("(Start with smallest/simplest)")
print()

# Save URLs to file for easy testing
output_dir = config_file.rsplit('/', 1)[0]
output_file = f"{output_dir}/qr-test-urls.txt"

with open(output_file, 'w') as f:
    f.write("QR Code Test URLs\n")
    f.write("=" * 70 + "\n\n")
    f.write("Format 1 (Plain Text):\n")
    f.write(config_text + "\n\n")
    f.write("Format 2 (JSON Uncompressed):\n")
    f.write(minimal_json_str + "\n\n")
    f.write("Format 3 (JSON + Base64):\n")
    f.write(vpn_url_minimal + "\n\n")
    f.write("Format 4 (Full Official):\n")
    f.write(vpn_url_full + "\n\n")
    f.write("Format 5 (Compact):\n")
    f.write(vpn_url_compact + "\n\n")

print(f"All formats saved to: {output_file}")

PYTHON_SCRIPT

echo
echo "✓ Test complete!"
echo
echo "Next steps:"
echo "  1. Scan each QR code with AmneziaVPN iOS app"
echo "  2. Note which format works"
echo "  3. Report back which one succeeded"
echo
echo "Recommended test order: Format 5 → 3 → 1 → 4 → 2"
echo "(smallest to largest)"
