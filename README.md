# AmneziaWG Docker Installer

Easy-to-use installation scripts for setting up AmneziaWG VPN server using Docker with stateless containers and host-based configuration.

## ⚠️ SECURITY WARNING

**NEVER blindly download and run bash scripts with root privileges!**

This is extremely dangerous and can compromise your entire system. Before running ANY script from the internet:

1. **Clone the repository** and review ALL source code
2. **Understand what each command does**
3. **Verify the scripts are from a trusted source**
4. **Check for community reviews and recent activity**
5. **NEVER pipe wget/curl directly to bash** (`curl | sudo bash` is dangerous!)

**Recommended installation process:**

```bash
# Clone and inspect first
git clone https://github.com/YOUR-USERNAME/amneziawg-docker-install.git
cd amneziawg-docker-install

# Read and understand the scripts
less install.sh
less scripts/setup.sh
less scripts/add-client.sh

# Only run after reviewing
sudo bash install.sh
```

**Running scripts from unknown sources can:**
- Install backdoors and malware
- Steal credentials and private keys
- Compromise your server
- Create botnets
- Expose your users' data

**You have been warned!**

## Features

- 🐋 **Docker-based** - Runs in containers, isolated from host
- 💾 **Stateless containers** - All configuration stored on host
- 🔄 **Hot reload** - Add clients without restarting the server
- 🌐 **DNS support** - Use domain names instead of IPs
- 🎭 **Traffic obfuscation** - HTTP/DNS signature packets to bypass DPI
- 🔒 **Secure** - Post-quantum security with preshared keys
- 🚀 **Fast** - Built on WireGuard protocol
- 🔧 **Multi-VPN friendly** - Works alongside other VPN servers

## Quick Start

**⚠️ Read the security warning above before proceeding!**

```bash
# Clone the repository (DO NOT wget | bash!)
git clone https://github.com/YOUR-USERNAME/amneziawg-docker-install.git
cd amneziawg-docker-install

# Review the code first!
less install.sh
less scripts/setup.sh

# Run installation only after reviewing
sudo bash install.sh

# Add your first client
sudo amneziawg add-client laptop
```

That's it! Copy the generated config file to your device and import it into the [AmneziaVPN app](https://amnezia.org/downloads).

## Requirements

- **OS**: Ubuntu 20.04+, Debian 11+, or any Linux with Docker support
- **Docker**: Will be installed automatically if not present
- **RAM**: 512MB minimum
- **Disk**: 2GB free space
- **Network**: Public IP address and UDP port access

## Installation

### Method 1: One-Line Install (Recommended)

```bash
wget -O - https://raw.githubusercontent.com/YOUR-USERNAME/amneziawg-docker-install/main/install.sh | sudo bash
```

### Method 2: Manual Install

```bash
# Clone repository
git clone https://github.com/YOUR-USERNAME/amneziawg-docker-install.git
cd amneziawg-docker-install

# Run setup
sudo bash scripts/setup.sh
```

### Configuration Options

Set environment variables before installation:

```bash
export AWG_SUBNET_IP="10.66.66.1"    # VPN server IP (default: 10.66.66.1)
export AWG_SUBNET_CIDR="24"          # Subnet mask (default: 24)
export AWG_PORT="55555"               # VPN port (default: 51820)
export SERVER_ENDPOINT="vpn.example.com"  # Server DNS name (auto-detected)

sudo -E bash install.sh
```

## Usage

### Add a New Client

```bash
# With DNS name
SERVER_ENDPOINT=vpn.example.com sudo -E amneziawg add-client laptop

# With IP address
SERVER_ENDPOINT=203.0.113.5 sudo -E amneziawg add-client phone

# Auto-detect server IP
sudo amneziawg add-client tablet
```

Client configuration will be saved to `/opt/amnezia/awg/clients/<name>.conf`

### Manage Server

```bash
# Show status and active connections
sudo amneziawg status

# List all configured clients
sudo amneziawg list

# Show server configuration
sudo amneziawg show

# View container logs
sudo amneziawg logs

# Restart/stop/start server
sudo amneziawg restart
sudo amneziawg stop
sudo amneziawg start

# Backup configuration
sudo amneziawg backup
```

### Import Config to Client

**On iOS (Method 1 - QR Code):**
1. The add-client script generates a QR code automatically
2. Scan with AmneziaVPN app camera
3. Config imports automatically
4. Connect!

**On iOS/Android (Method 2 - File Import):**
1. Copy the `.conf` file to your device
2. Open AmneziaVPN app
3. Settings → Import from file
4. Select the config file
5. Connect!

**On Linux/macOS:**
```bash
# Install AmneziaWG tools
# See: https://github.com/amnezia-vpn/amneziawg-tools

# Connect
sudo awg-quick up laptop.conf
```

## How It Works

### Architecture

```
┌─────────────────────────────────────────────┐
│              VPS Host                        │
│                                              │
│  ┌────────────────────────────────────┐    │
│  │  Docker Container: amnezia-awg     │    │
│  │                                     │    │
│  │  ┌──────────────────────────────┐  │    │
│  │  │  awg0: 10.66.66.1/24         │  │    │
│  │  │  Port: 55555/UDP             │  │    │
│  │  │                               │  │    │
│  │  │  Config (mounted from host): │  │    │
│  │  │  /opt/amnezia/awg/           │  │    │
│  │  └──────────────────────────────┘  │    │
│  └────────────────────────────────────┘    │
│                                              │
│  eth0: Public IP                            │
└─────────────────────────────────────────────┘
                    │
                    │ Encrypted VPN Tunnel
                    │ (looks like HTTP/DNS)
                    │
        ┌───────────┴──────────┐
        │                      │
   ┌────▼────┐          ┌─────▼─────┐
   │ Client1 │          │  Client2  │
   │10.66.66.2│         │10.66.66.3│
   └─────────┘          └───────────┘
```

### Installation Process

1. **Creates directories**: `/opt/amnezia/awg/` for configuration
2. **Generates keys**: Server private/public keys, preshared key
3. **Generates obfuscation parameters**: Random Jc, S1-S4, H1-H4 values
4. **Creates Docker network**: `amnezia-dns-net` for optional DNS container
5. **Runs container**: Mounts config directory, exposes VPN port
6. **Configures firewall**: iptables rules inside container for NAT

### Client Addition Process

1. **Generates client keys**: Unique private/public key pair
2. **Assigns IP**: Next available IP in VPN subnet
3. **Adds peer**: Appends to server config
4. **Reloads server**: Hot reload without restart
5. **Creates client config**: With all obfuscation parameters
6. **Adds signatures**: HTTP/DNS traffic mimicry (I1-I5)

## Traffic Obfuscation

AmneziaWG disguises VPN traffic as legitimate HTTP/DNS requests using:

### Junk Packets (Jc, Jmin, Jmax)
Random packets of varying sizes sent before handshakes to make traffic unpredictable.

### Padding (S1-S4)
- **S1**: Handshake initiation padding
- **S2**: Handshake response padding
- **S3**: Cookie reply padding
- **S4**: Transport message padding

### Magic Headers (H1-H4)
Randomize the packet type field with non-overlapping ranges to avoid WireGuard's distinctive signatures.

### Signature Packets (I1-I5)
Custom packets sent before handshakes that mimic real protocols:
- **I1**: `GET / HTTP/1.1\r\nHost: ` - HTTP request start
- **I2**: Random domain name + `.com\r\n`
- **I3**: `User-Agent: Mozilla/5.0\r\n` - Browser header
- **I4**: `Connection: keep-alive\r\n\r\n` + random data
- **I5**: DNS query packet with timestamp

## File Structure

```
/opt/amnezia/awg/
├── awg0.conf                # Server configuration
├── server_private.key       # Server private key (600)
├── server_public.key        # Server public key (644)
├── preshared.key            # Preshared key (600)
├── obfuscation-params.txt   # Parameter reference
├── start.sh                 # Container entrypoint
└── clients/                 # Client configurations (700)
    ├── laptop.conf          # Client configs (600)
    ├── phone.conf
    └── tablet.conf
```

## Firewall Requirements

### External Firewall (Cloud Provider)

**Required**: Allow UDP port (default: 51820) inbound

Configure in your provider's dashboard:
- **DigitalOcean**: Networking → Firewalls
- **Hetzner**: Firewalls → Rules
- **Vultr**: Firewall → Add Rule
- **AWS/Lightsail**: Networking → Firewall

### Container Firewall (Automatic)

Handled automatically by `start.sh`:
- IP forwarding enabled
- NAT/masquerading for VPN subnet
- Forwarding rules for awg0 interface

**No manual configuration needed!**

## Troubleshooting

### Client Can Connect But No Internet

**Symptoms**: VPN shows connected, but no internet access

**Cause**: Container's iptables rules missing or incorrect

**Solution**:
```bash
# Check if start.sh has iptables rules
cat /opt/amnezia/awg/start.sh | grep iptables

# If missing, the container needs NAT rules for routing
# Restart container to apply:
docker restart amnezia-awg

# Verify NAT is working:
docker exec amnezia-awg iptables -t nat -L POSTROUTING -n
# Should show MASQUERADE rules for your VPN subnet
```

### Handshake Fails

**Symptoms**: No handshake shown in `awg show`, client keeps retrying

**Cause**: Configuration mismatch between client and server

**Solution**:
```bash
# Verify client's public key is in server config
docker exec amnezia-awg awg show awg0
# Compare peer public key with client config

# Check obfuscation parameters match
grep "^Jc = " /opt/amnezia/awg/awg0.conf
grep "^Jc = " /opt/amnezia/awg/clients/laptop.conf
# All parameters must be identical!
```

### Error 900: ImportInvalidConfigError

**Symptoms**: AmneziaVPN app shows error when importing config

**Causes and Solutions**:

1. **Empty obfuscation parameters**
   - Check config file has values: `Jc = 5` not `Jc = `
   - Regenerate client with updated script

2. **Missing I1-I5 parameters**
   - Older configs missing signature packets
   - Use latest add-client script

3. **Trailing spaces or wrong format**
   - Check with: `cat -A /opt/amnezia/awg/clients/laptop.conf`
   - No `$` at end of lines (except actual end of line)

4. **Using QR code instead of file**
   - **Solution**: Use file import, NOT QR code
   - iOS app has issues with compressed QR format

### QR Code Import Fails

**Symptoms**: `qUncompress: Input data is corrupted`

**Cause**: iOS AmneziaVPN client has issues with Qt's compression format

**Solution**: **Use file import instead**
- File import works reliably
- QR codes are experimental and buggy
- Transfer `.conf` file via AirDrop/iCloud/Email

### Port Already in Use

**Symptoms**: Container won't start, port conflict

**Solution**:
```bash
# Check what's using the port
sudo netstat -uln | grep 55555
# or
sudo ss -uln | grep 55555

# Change port if needed
export AWG_PORT="51821"
sudo -E bash install.sh
```

### Container Can't Reach Internet

**Symptoms**: `docker exec amnezia-awg ping 8.8.8.8` fails

**Cause**: Docker networking misconfigured

**Solution**:
```bash
# Check container has default route
docker exec amnezia-awg ip route

# Should show:
# default via X.X.X.X dev eth0

# If missing, container networking is broken
# Recreate container or check Docker installation
```

### "No Such File or Directory" When Reloading

**Symptoms**: Error when adding client during reload step

**Cause**: Process substitution doesn't work across Docker exec

**Solution**: Already fixed in latest script - uses temp file inside container instead

### Multiple Docker Networks

**Symptoms**: Container has eth0 and eth1, routing is wrong

**Cause**: Container connected to multiple Docker networks

**Solution**:
```bash
# Check container's routing
docker exec amnezia-awg ip route

# If default via eth0 but internet is on eth1:
# The start.sh already handles this - NAT rules for BOTH interfaces

# Verify:
docker exec amnezia-awg iptables -t nat -L -n | grep MASQUERADE
# Should show rules for both eth0 and eth1
```

### Clients Can't Talk to Each Other

**Symptoms**: Client 1 can't ping Client 2

**Cause**: Forwarding between VPN clients disabled

**Solution**:
Add to `/opt/amnezia/awg/start.sh`:
```bash
iptables -A FORWARD -i awg0 -o awg0 -j ACCEPT
```

Then restart container.

## Advanced Configuration

### Change DNS Servers

Edit client configs to use different DNS:

```bash
# Use Google DNS
DNS = 8.8.8.8, 8.8.4.4

# Use Quad9
DNS = 9.9.9.9, 149.112.112.112

# Use your own DNS server on the host
DNS = 10.66.66.1
```

### Customize Obfuscation

Edit `/opt/amnezia/awg/awg0.conf` before first client:

```ini
Jc = 7        # More junk packets (slower but stealthier)
Jmin = 100    # Larger minimum junk size
Jmax = 1280   # Maximum junk size (MTU limit)
```

**Important**: All clients must be regenerated after changing these values!

### Disable Signature Packets

If signature packets cause issues, edit the add-client script and set:

```bash
I1=''
I2=''
I3=''
I4=''
I5=''
```

Or remove those lines entirely from client configs.

### Use Different Signature Patterns

**TLS Handshake:**
```
I1 = <b 0x160301>
I2 = <r 100>
```

**SSH:**
```
I1 = <b 0x5353482d322e30>
I2 = <r 50>
```

**Custom:**
```
I1 = <b 0xYOURHEXDATA>
I2 = <rc 20>           # 20 random letters
I3 = <rd 10>           # 10 random digits
I4 = <r 30>            # 30 random bytes
I5 = <t>               # Current timestamp
```

See [AmneziaWG documentation](https://github.com/amnezia-vpn/amneziawg-go#custom-signature-packets) for tag syntax.

## Backup and Restore

### Backup

```bash
# Backup all configuration
sudo amneziawg backup

# Creates: amneziawg-backup-YYYYMMDD-HHMMSS.tar.gz
```

The backup includes:
- Server keys
- Server configuration
- All client configurations
- Obfuscation parameters

### Restore

```bash
# Extract backup to config directory
sudo tar -xzf amneziawg-backup-*.tar.gz -C /opt/amnezia/awg/

# Restart container
docker restart amnezia-awg
```

## Migration from Native WireGuard

If you're running native WireGuard on the same host:

1. **Use different subnet**:
   - Native WG: `10.0.0.0/24`
   - AmneziaWG: `10.66.66.0/24` (default)

2. **Use different port**:
   - Native WG: `51820`
   - AmneziaWG: `51821` or higher

3. **Both can run simultaneously** - no conflicts!

## Comparison with Official Amnezia Client

| Feature | Official Client | This Installer |
|---------|----------------|----------------|
| **Method** | SSH + Docker deployment | Manual Docker setup |
| **Platform** | Desktop GUI app | Command-line scripts |
| **Configuration** | Stored in app | Stored on VPS host |
| **Flexibility** | Limited | Full control |
| **Complexity** | Simple (automated) | Moderate (manual) |
| **Use Case** | End users | System administrators |

## Security Considerations

### What Data is Stored

**On VPS**:
- Server private key (`/opt/amnezia/awg/server_private.key`)
- Client private keys (`/opt/amnezia/awg/clients/*.conf`)
- Preshared key (shared by all clients)

**Best Practices**:
1. Set proper file permissions (done automatically)
2. Encrypt backups before storing remotely
3. Use strong passwords for VPS access
4. Enable SSH key authentication
5. Keep Docker and host system updated

### Privacy

**No telemetry**: This installer sends no data to third parties

**Traffic analysis**: Obfuscation parameters make DPI detection difficult but not impossible

**DNS leaks**: Configure clients to use VPN DNS to prevent leaks

## Performance Tuning

### For High-Traffic Servers

Edit `/opt/amnezia/awg/start.sh` and add before `tail -f`:

```bash
# Increase buffer sizes
sysctl -w net.core.rmem_max=26214400
sysctl -w net.core.wmem_max=26214400

# TCP tuning
sysctl -w net.ipv4.tcp_congestion_control=bbr
```

### For Low-Latency

Reduce junk packets in server config:

```ini
Jc = 3        # Fewer junk packets
Jmin = 10     # Smaller minimum size
Jmax = 50     # Smaller maximum size
```

## Uninstallation

```bash
# Stop and remove container
docker stop amnezia-awg
docker rm amnezia-awg

# Remove Docker network
docker network rm amnezia-dns-net

# Remove configuration (CAREFUL!)
sudo rm -rf /opt/amnezia/awg

# Remove scripts (if installed system-wide)
sudo rm /usr/local/bin/amneziawg
```

## FAQ

### Q: Can I use this with existing WireGuard?
**A**: Yes! Use different subnets and ports. Both can run simultaneously.

### Q: Do I need to restart the container when adding clients?
**A**: No! The script uses hot reload (`awg syncconf`).

### Q: Can I change my server IP later?
**A**: Yes, if using DNS names. Just update DNS records. If using IP addresses, regenerate all client configs.

### Q: What's the difference from standard WireGuard?
**A**: AmneziaWG adds obfuscation to bypass DPI. Protocol is compatible but includes extra parameters.

### Q: Is this secure?
**A**: Yes. Based on WireGuard (audited), adds obfuscation and preshared keys (post-quantum security).

### Q: Why not use the official Amnezia client?
**A**: This gives you full control, works on headless servers, and stores config on the VPS for easy management.

### Q: QR codes don't work?
**A**: Known issue with iOS app compression. Use file import instead - it's more reliable.

### Q: Can I run this without Docker?
**A**: Use the native installer instead: https://github.com/wiresock/amneziawg-install

## Credits

- **AmneziaVPN Project**: https://github.com/amnezia-vpn
- **AmneziaWG Protocol**: https://github.com/amnezia-vpn/amneziawg-go
- **WireGuard**: https://www.wireguard.com/

## License

MIT License - See LICENSE file

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test thoroughly
4. Submit a pull request

## Support

- **Issues**: https://github.com/YOUR-USERNAME/amneziawg-docker-install/issues
- **AmneziaVPN Docs**: https://docs.amnezia.org
- **Telegram**: https://t.me/amnezia_vpn_en

## Changelog

### Version 1.0.0 (2026-03-27)
- Initial release
- Docker-based installation
- Hot reload support
- HTTP/DNS traffic obfuscation
- File-based config import
