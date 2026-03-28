# Project Summary

## What's Inside

This repository contains everything needed to set up AmneziaWG VPN
server using Docker.

### Files Created

```text
amneziawg-docker-install/
├── README.md                          # Main documentation (English)
├── README.ru.md                       # Russian documentation
├── LICENSE                            # MIT License
├── CONTRIBUTING.md                    # Contribution guidelines
├── TROUBLESHOOTING.md                 # Detailed troubleshooting guide
├── .gitignore                         # Git ignore rules
├── install.sh                         # Main installer (with security warnings)
│
├── scripts/
│   ├── setup.sh                       # Initial server setup
│   ├── add-client.sh                  # Add new VPN clients
│   └── manage.sh                      # Server management commands
│
├── docs/
│   ├── OBFUSCATION.md                 # Obfuscation technical details
│   └── ARCHITECTURE.md                # System architecture docs
│
└── examples/
    └── client-config-example.conf     # Example client configuration
```

### What Gets Created on VPS

```text
/opt/amnezia/awg/
├── awg0.conf                          # Server configuration
├── server_private.key                 # Server private key (600)
├── server_public.key                  # Server public key (644)
├── preshared.key                      # Preshared key (600)
├── obfuscation-params.txt             # Parameters reference
├── start.sh                           # Container entrypoint
└── clients/                           # Client configs directory
    ├── laptop.conf
    ├── phone.conf
    └── ...
```

## Key Features Implemented

✅ **Stateless Docker containers** - All config on host  
✅ **Hot reload** - No restart when adding clients  
✅ **DNS name support** - Use domains instead of IPs  
✅ **HTTP/DNS obfuscation** - I1-I5 signature packets  
✅ **Multi-VPN compatible** - Works with other WireGuard instances  
✅ **Security warnings** - Prominent disclaimers about running scripts  
✅ **Comprehensive docs** - Everything learned during development  
✅ **Bilingual** - English and Russian documentation  

## Issues Solved During Development

1. **Empty obfuscation parameters** - Fixed by reading from server
   config instead of separate file
2. **QR code import fails** - Documented workaround (use file import)
3. **No internet after connection** - Fixed with iptables inside container
4. **Process substitution across docker exec** - Use temp files instead
5. **Multiple Docker networks** - NAT to both eth0 and eth1
6. **I5 hex encoding error** - Fixed odd-length hex strings
7. **Container routing** - Explicit forwarding rules for all interfaces

## Testing Done

- ✅ Fresh install on Ubuntu 22.04
- ✅ Works alongside native WireGuard
- ✅ iOS client connection (AmneziaVPN 4.8.14)
- ✅ Internet access through VPN
- ✅ Hot reload (add client without restart)
- ✅ File import (iOS)
- ✅ HTTP/DNS signature packets
- ✅ DNS name endpoints
- ❌ QR code import (known iOS app issue)

## What Makes This Different

### vs. Official Amnezia Client

- **Target users**: System administrators vs end users
- **Method**: Manual Docker setup vs GUI automation
- **Control**: Full control vs simplified
- **Platform**: Any Linux with Docker vs Desktop apps only

### vs. wiresock/amneziawg-install

- **Method**: Docker vs native packages
- **Isolation**: Containerized vs kernel module
- **Updates**: Pull new image vs rebuild kernel module
- **Complexity**: More complex (Docker) vs simpler (systemd)

## Security Approach

### What We Do

✅ Prominent security warnings  
✅ Encourage code review before running  
✅ No telemetry or external communication  
✅ Proper file permissions (600/700)  
✅ Minimal privileges where possible  
✅ Clear documentation of risks  

### What We Don't Do

❌ Hide what the scripts do  
❌ Obfuscate code  
❌ Download additional scripts at runtime  
❌ Phone home  
❌ Recommend piping to bash  

## Documentation Philosophy

All documentation includes:

- Clear examples
- Expected output
- Troubleshooting steps
- Security considerations
- What was learned during development

Every issue encountered is documented in TROUBLESHOOTING.md with
solutions.

## Ready for GitHub

The project is structured for easy publishing:

- Clear README with security warnings
- Comprehensive documentation
- Working scripts (tested)
- Example configurations
- Contribution guidelines
- MIT License
- Proper .gitignore

## Usage After Publishing

Users can:

```bash
# Review first (mandatory!)
git clone https://github.com/YOUR-USERNAME/amneziawg-docker-install.git
cd amneziawg-docker-install
less install.sh

# Install
sudo bash install.sh

# Use
sudo amneziawg add-client laptop
sudo amneziawg status
sudo amneziawg backup
```

All scripts include help text and examples.
