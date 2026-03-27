# Troubleshooting Guide

This document covers all issues encountered during development and testing, with solutions.

## Table of Contents

1. [Client Connection Issues](#client-connection-issues)
2. [Import/Configuration Issues](#importconfiguration-issues)
3. [Network and Routing Issues](#network-and-routing-issues)
4. [Docker and Container Issues](#docker-and-container-issues)
5. [Firewall Issues](#firewall-issues)

---

## Client Connection Issues

### Client Connects But No Internet

**Symptoms:**
- VPN shows "connected" in app
- Can't browse websites
- `awg show` on server shows no handshake or endpoint

**Diagnosis:**
```bash
# Check if client peer appears on server
docker exec amnezia-awg awg show awg0

# Should show:
# peer: [public key]
#   endpoint: [client IP]:[port]  ← MUST BE PRESENT
#   latest handshake: X seconds ago  ← MUST BE RECENT
#   transfer: X KiB received, Y KiB sent  ← MUST BE INCREASING
```

**Cause 1: Container missing NAT rules**

The container needs iptables rules to route VPN traffic to the internet.

**Solution:**
```bash
# Check if start.sh has iptables rules
cat /opt/amnezia/awg/start.sh | grep iptables

# If missing or incorrect, update start.sh:
cat > /opt/amnezia/awg/start.sh << 'STARTSCRIPT'
#!/bin/bash
set -e

VPN_SUBNET=$(grep "^Address" /opt/amnezia/awg/awg0.conf | awk '{print $3}')
awg-quick down /opt/amnezia/awg/awg0.conf 2>/dev/null || true
awg-quick up /opt/amnezia/awg/awg0.conf

# CRITICAL: NAT rules for both eth0 and eth1
iptables -A INPUT -i awg0 -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i awg0 -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i awg0 -o eth0 -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i awg0 -o eth1 -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -o awg0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -t nat -A POSTROUTING -s ${VPN_SUBNET} -o eth0 -j MASQUERADE 2>/dev/null || true
iptables -t nat -A POSTROUTING -s ${VPN_SUBNET} -o eth1 -j MASQUERADE 2>/dev/null || true

tail -f /dev/null
STARTSCRIPT

chmod +x /opt/amnezia/awg/start.sh

# Restart container
docker restart amnezia-awg
```

**Cause 2: Container connected to wrong Docker network**

Check container routing:
```bash
docker exec amnezia-awg ip route
```

If default route points to a network without internet (like amnezia-dns-net `172.29.172.0/24`), the NAT rules to BOTH eth0 and eth1 in start.sh should fix it.

**Cause 3: Multiple Docker networks interfering**

The container might have multiple network interfaces. The solution is to NAT to ALL of them (eth0, eth1) which the updated start.sh does.

### Handshake Never Completes

**Symptoms:**
- Client shows: "handshake did not complete after 5 seconds, retrying"
- Server shows no endpoint for the peer
- Traffic visible in tcpdump but only one direction

**Cause: Configuration mismatch**

Obfuscation parameters must match EXACTLY between client and server.

**Solution:**
```bash
# Check server parameters
grep "^Jc = " /opt/amnezia/awg/awg0.conf
grep "^S1 = " /opt/amnezia/awg/awg0.conf
grep "^H1 = " /opt/amnezia/awg/awg0.conf

# Check client parameters
grep "^Jc = " /opt/amnezia/awg/clients/laptop.conf
grep "^S1 = " /opt/amnezia/awg/clients/laptop.conf
grep "^H1 = " /opt/amnezia/awg/clients/laptop.conf

# ALL VALUES MUST MATCH!
```

If they don't match, regenerate the client with the latest add-client script.

### Traffic Only in One Direction

**Symptoms:**
- `tcpdump` shows packets FROM client TO server
- No packets FROM server TO client
- Handshake fails

**Cause: Return packets blocked**

This happened during testing when container's iptables rules were missing.

**Solution:**
Ensure start.sh has proper FORWARD and MASQUERADE rules (see "Container missing NAT rules" above).

---

## Import/Configuration Issues

### Error 900: ImportInvalidConfigError

**Symptoms:**
- AmneziaVPN app shows "Error 900" when importing config
- Or: "The config does not contain any containers and credentials"

**Cause 1: Empty obfuscation parameters**

Config file has lines like:
```
Jc = 
Jmin = 
```

**Solution:**
The add-client script had a bug where it tried to `source` a params file with wrong format. Latest version reads directly from server config.

Regenerate client:
```bash
rm /opt/amnezia/awg/clients/laptop.conf
# Remove [Peer] section from awg0.conf
nano /opt/amnezia/awg/awg0.conf

# Re-add with latest script
SERVER_ENDPOINT=vpn.example.com bash add-client.sh laptop
```

**Cause 2: Missing I1-I5 parameters**

Older versions of the script didn't include signature packets.

**Solution:**
The latest script includes all I1-I5 parameters. Regenerate your clients.

**Cause 3: Format issues**

- Trailing spaces after values
- Wrong line endings (CRLF instead of LF)
- Comments in wrong places

**Solution:**
```bash
# Check for issues
cat -A /opt/amnezia/awg/clients/laptop.conf

# Look for:
# - $ at end of lines (good - Unix line ending)
# - ^M$ at end (bad - Windows line ending)
# - extra $ before actual end (trailing space)

# Fix line endings if needed
dos2unix /opt/amnezia/awg/clients/laptop.conf
```

### QR Code Import Fails

**Symptoms:**
- Scanning QR code shows: "qUncompress: Input data is corrupted"
- Or: "qUncompress: Not enough memory"
- File import of same config works fine

**Cause:**
iOS AmneziaVPN client (v4.8.14) has issues with Qt's qCompress format. The compression/decompression doesn't match between platforms.

**Solution:**
**Use file import instead of QR codes!**

QR codes are experimental and unreliable. File import works perfectly:
1. Copy `.conf` file to your device (AirDrop/iCloud/Email)
2. AmneziaVPN app → Import from file
3. Select the `.conf` file

### I5 Parameter Parse Error

**Symptoms:**
- "failed to parse I5: failed to build <b>: empty argument"
- Or: "odd amount of symbols"

**Cause:**
Hex strings in `<b 0xHEX>` tags must have even number of characters (2 hex digits = 1 byte).

**Examples:**
- `<b 0x1234>` ✓ (4 chars, even)
- `<b 0x123>` ✗ (3 chars, odd)
- `<b 0x>` ✗ (0 chars, empty)

**Solution:**
The latest script has correct I5 with even-length hex strings. Don't manually edit I1-I5 values.

---

## Network and Routing Issues

### VPN Subnet Conflicts

**Symptoms:**
- Routing doesn't work correctly
- Can't reach certain networks
- Native WireGuard stops working after installing AmneziaWG

**Cause:**
VPN subnet overlaps with existing network (native WireGuard, LAN, etc.)

**Solution:**
Choose non-conflicting subnets:

```bash
# If you have native WireGuard on 10.0.0.0/24
# Use different subnet for AmneziaWG:

export AWG_SUBNET_IP="10.66.66.1"  # Far from 10.0.0.0
export AWG_SUBNET_CIDR="24"

sudo -E bash install.sh
```

**Common subnet choices:**
- `10.66.66.0/24` (Amnezia default)
- `172.16.0.0/24` (Class B private)
- `192.168.99.0/24` (Class C private)

### DNS Not Working

**Symptoms:**
- Can ping IPs (8.8.8.8) but can't resolve names (google.com)
- Websites with IP work, websites with domain don't

**Diagnosis:**
```bash
# On client device while connected to VPN:
# Try accessing: http://142.250.185.46 (Google's IP)
# If works → DNS issue
# If doesn't work → routing issue
```

**Solution:**
Check DNS in client config:
```bash
grep "^DNS = " /opt/amnezia/awg/clients/laptop.conf

# Should show:
DNS = 1.1.1.1, 1.0.0.1

# Or use your own DNS:
DNS = 8.8.8.8, 8.8.4.4
```

---

## Docker and Container Issues

### Container Won't Start

**Symptoms:**
- `docker ps` doesn't show amnezia-awg
- `docker logs amnezia-awg` shows errors

**Diagnosis:**
```bash
docker logs amnezia-awg
```

**Common errors:**

**1. Port already in use**
```
Error: port is already allocated
```

**Solution:**
```bash
# Find what's using the port
netstat -uln | grep 51820

# Change port
export AWG_PORT="51821"
sudo -E bash install.sh
```

**2. Permission denied**
```
permission denied while trying to connect to docker daemon
```

**Solution:**
```bash
# Run with sudo
sudo bash install.sh

# Or add user to docker group (logout/login required)
sudo usermod -aG docker $USER
```

**3. Kernel module not found**
```
[!] Missing WireGuard (Amnezia VPN) kernel module
```

**This is OK!** The message says "Falling back to slow userspace implementation" which works fine. The Docker image includes the userspace implementation.

### Multiple Docker Networks Problem

**Symptoms:**
- Container has eth0 and eth1
- Routing points to wrong interface
- Internet works from container but not through VPN

**Diagnosis:**
```bash
# Check container's network interfaces
docker exec amnezia-awg ip addr

# Check routing
docker exec amnezia-awg ip route

# Example problematic output:
# default via 172.29.172.1 dev eth0  ← Points to DNS network (no internet)
# 172.17.0.0/16 dev eth1            ← eth1 has internet
```

**Cause:**
Container connected to multiple Docker networks (`amnezia-dns-net` and default `bridge`). Default route might point to wrong network.

**Solution:**
The start.sh script NATs to BOTH eth0 and eth1, so traffic can exit through either interface:

```bash
iptables -t nat -A POSTROUTING -s ${VPN_SUBNET} -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s ${VPN_SUBNET} -o eth1 -j MASQUERADE
```

This is already in the latest start.sh. Just restart container:
```bash
docker restart amnezia-awg
```

### Config Reload Fails with "fopen: No such file or directory"

**Symptoms:**
- Error when adding client during reload step
- Message: `fopen: No such file or directory`

**Cause:**
Process substitution `<(...)` doesn't work across `docker exec` boundary.

**Old broken code:**
```bash
docker exec container awg syncconf awg0 <(docker exec container awg-quick strip config)
```

**Solution (already fixed in scripts):**
```bash
# Create temp file INSIDE container first
docker exec container sh -c "awg-quick strip /path/config > /tmp/stripped.conf"
docker exec container awg syncconf awg0 /tmp/stripped.conf
docker exec container rm /tmp/stripped.conf
```

---

## Firewall Issues

### External Firewall (Cloud Provider)

**Symptoms:**
- VPN clients can't connect
- No traffic visible in tcpdump
- Connection times out

**Diagnosis:**
```bash
# Listen for incoming traffic on VPN port
tcpdump -i eth0 -n udp port 55555

# If you see NO packets → external firewall blocking
# If you see packets → firewall OK, check other issues
```

**Solution:**
Configure firewall in your cloud provider's dashboard:
- **Allow**: UDP port 55555 (or your configured port)
- **Direction**: Inbound
- **Source**: 0.0.0.0/0 (all IPs) or specific IPs

**Provider-specific:**
- **DigitalOcean**: Networking → Firewalls → Add rule
- **Hetzner Cloud**: Firewalls → Rules → Add
- **AWS/Lightsail**: Networking → Firewall → Custom UDP
- **Vultr**: Firewall → Add Rule → UDP

### Traffic Visible But No Handshake

**Symptoms:**
- `tcpdump` shows packets from client to server
- NO packets from server back to client
- Client keeps retrying handshake

**Diagnosis:**
```bash
# Watch bidirectional traffic
tcpdump -i eth0 -n 'udp port 55555 and host [CLIENT_IP]'

# You should see BOTH:
# [CLIENT_IP] > [SERVER_IP]  (incoming)
# [SERVER_IP] > [CLIENT_IP]  (outgoing)

# If only incoming → server can't send replies
```

**Cause:**
Container's iptables missing or wrong.

**Solution:**
See "Client Connects But No Internet" → "Cause 1: Container missing NAT rules"

### DOCKER-USER Chain Blocking Traffic

**Symptoms:**
- Container can ping internet
- VPN clients connect
- But VPN traffic doesn't forward

**Diagnosis:**
```bash
# Check DOCKER-USER chain
iptables -L DOCKER-USER -n -v

# Check packet counts
iptables -L FORWARD -n -v | head -20
```

**Solution:**
Add explicit allow rule:
```bash
iptables -I DOCKER-USER -s 10.66.66.0/24 -j ACCEPT
iptables -I DOCKER-USER -d 10.66.66.0/24 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables-save > /etc/iptables/rules.v4
```

---

## Import/Configuration Issues (Detailed)

### Testing Which Config Format Works

When troubleshooting import issues, test systematically:

**Test 1: Minimal AWG 1.x config (no S3/S4, no I1-I5)**
```ini
[Interface]
Address = 10.66.66.2/32
DNS = 1.1.1.1, 1.0.0.1
PrivateKey = [key]
Jc = 5
Jmin = 57
Jmax = 1242
S1 = 129
S2 = 83
H1 = 125846151-898407554
H2 = 959053812-1066514477
H3 = 1474249607-1476151460
H4 = 1505335300-2147483647

[Peer]
PublicKey = [key]
PresharedKey = [key]
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = server:port
PersistentKeepalive = 25
```

**Result from testing:**
- ✓ Imports successfully
- ✓ Connects to server
- ✗ No internet (needed iptables fix)

**Test 2: AWG 2.0 config (with S3/S4, no I1-I5)**
Same as above but add:
```ini
S3 = 49
S4 = 99
```

**Result:**
- ✓ Imports successfully
- ✓ Connects to server

**Test 3: Full config (with I1-I5)**
Add signature packets:
```ini
I1 = <b 0x474554202f20485454502f312e310d0a>
I2 = <r 50>
I3 = 
I4 = 
I5 = 
```

**Result:**
- ✓ Imports successfully
- ✓ Connects to server
- ✓ Internet works after iptables fix

**Test 4: Complex signatures (HTTP/DNS)**
All I1-I5 with full HTTP/DNS signatures.

**Result:**
- ✗ I5 fails if hex string has odd length
- ✓ Works after fixing hex to even length
- ✓ Traffic successfully mimics HTTP/DNS

### File Import vs QR Code

**Testing results:**

| Method | Result | Notes |
|--------|--------|-------|
| QR Code (plain text) | ✗ Failed | "qUncompress: Input data is corrupted" |
| QR Code (compressed JSON) | ✗ Failed | "Not enough memory" |
| File Import | ✓ Works | Reliable, recommended |

**Conclusion:** iOS AmneziaVPN app v4.8.14 has issues with QR code compression format. Always use file import.

---

## Diagnostic Commands Reference

### Server-Side Diagnostics

```bash
# Container status
docker ps | grep amnezia-awg

# Container logs
docker logs amnezia-awg
docker logs --tail 50 -f amnezia-awg  # Follow mode

# WireGuard status
docker exec amnezia-awg awg show awg0
docker exec amnezia-awg awg show awg0 dump  # Detailed

# Network interfaces
docker exec amnezia-awg ip addr
docker exec amnezia-awg ip route

# Firewall rules
docker exec amnezia-awg iptables -L -n -v
docker exec amnezia-awg iptables -t nat -L -n -v

# Test internet from container
docker exec amnezia-awg ping -c 3 8.8.8.8
docker exec amnezia-awg nslookup google.com

# Watch traffic
tcpdump -i eth0 -n udp port 55555
tcpdump -i eth0 -n 'udp port 55555 and host [CLIENT_IP]'

# List all clients
ls -la /opt/amnezia/awg/clients/

# View server config
cat /opt/amnezia/awg/awg0.conf
```

### Client-Side Diagnostics

**iOS:**
- Enable debug logging in AmneziaVPN app settings
- Check connection status: should show "Connected" + data transfer
- Look for "Latest handshake" timestamp (should be recent)

**Test with IP instead of domain:**
- Safari → `http://142.250.185.46` (Google's IP)
- If works → DNS issue
- If doesn't → routing issue

**Test VPN server IP:**
- Safari → `http://10.66.66.1` (should timeout - server doesn't run HTTP)
- Ping in network tools app
- If works → VPN tunnel OK, internet routing broken

---

## Lessons Learned

### What We Discovered During Testing

1. **Docker multi-network routing**: Container with multiple network interfaces needs NAT to ALL of them
2. **Process substitution limitation**: `<(...)` doesn't cross docker exec boundary
3. **iOS QR code issues**: Compression format incompatible, file import works
4. **Parameter format**: `source` command fails with WireGuard format (`Key = value` with spaces)
5. **I1-I5 hex encoding**: Must have even number of hex digits
6. **Container network isolation**: iptables rules needed INSIDE container, not just on host
7. **Obfuscation parameter matching**: Even one mismatch causes handshake failure
8. **File permissions critical**: 600 for keys/configs, 700 for directories

### Common Mistakes

❌ **Removing ALL iptables from container** → No internet for VPN clients  
✓ **Keep iptables inside container** for NAT, manage external firewall separately

❌ **Using QR codes on iOS** → Import fails  
✓ **Use file import** instead

❌ **Hardcoding IP in configs** → Can't change server IP later  
✓ **Use DNS names** in SERVER_ENDPOINT

❌ **Manually editing I1-I5** → Easy to create invalid hex  
✓ **Use provided values** or understand tag syntax

❌ **Assuming default Docker route works** → Might point to wrong network  
✓ **NAT to all network interfaces** (eth0, eth1)

---

## Emergency Fixes

### Quick Reset

If everything is broken:

```bash
# Stop and remove container
docker stop amnezia-awg
docker rm amnezia-awg

# Backup your config
cp -r /opt/amnezia/awg /opt/amnezia/awg.backup

# Re-run setup (keeps existing keys if present)
sudo bash install.sh
```

### Regenerate All Clients

If server config changed:

```bash
# Backup old configs
cp -r /opt/amnezia/awg/clients /opt/amnezia/awg/clients.old

# Remove all [Peer] sections from server config
nano /opt/amnezia/awg/awg0.conf
# Keep only [Interface] section

# Restart container
docker restart amnezia-awg

# Re-add all clients
for client in laptop phone tablet; do
    SERVER_ENDPOINT=vpn.example.com bash add-client.sh $client
done
```

### Force Clean Start

Complete wipe (CAREFUL!):

```bash
# Stop container
docker stop amnezia-awg
docker rm amnezia-awg

# Remove ALL config (you'll lose keys!)
sudo rm -rf /opt/amnezia/awg

# Remove network
docker network rm amnezia-dns-net

# Start fresh
sudo bash install.sh
```
