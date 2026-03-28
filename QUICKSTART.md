# Quick Start Guide

This is a condensed guide for experienced users.
**New users should read README.md first!**

## ⚠️ Security Warning

**Review all code before running with root privileges!**
See README.md for full warning.

## Installation (3 minutes)

```bash
# 1. Clone and review
git clone https://github.com/YOUR-USERNAME/amneziawg-docker-install.git
cd amneziawg-docker-install
less install.sh scripts/setup.sh

# 2. Install
sudo bash install.sh

# 3. Add client
SERVER_ENDPOINT=vpn.example.com sudo -E bash scripts/add-client.sh laptop

# 4. Copy config
scp root@your-vps:/opt/amnezia/awg/clients/laptop.conf .

# 5. Import on device
# AmneziaVPN app → Import from file → laptop.conf
```

## Custom Configuration

```bash
# Set before install.sh
export AWG_SUBNET_IP="10.66.66.1"     # VPN subnet
export AWG_PORT="51821"                # VPN port
export SERVER_ENDPOINT="vpn.example.com"  # Your domain

sudo -E bash install.sh
```

## Common Commands

```bash
# Add clients
sudo bash scripts/add-client.sh phone
sudo bash scripts/add-client.sh tablet

# Manage
sudo bash scripts/manage.sh status    # Show status
sudo bash scripts/manage.sh list      # List clients
sudo bash scripts/manage.sh logs      # View logs
sudo bash scripts/manage.sh backup    # Backup config

# Direct Docker commands
docker logs amnezia-awg
docker exec amnezia-awg awg show awg0
docker restart amnezia-awg
```

## File Locations

- **Scripts**: `~/amneziawg-docker-install/scripts/`
- **Server config**: `/opt/amnezia/awg/awg0.conf`
- **Client configs**: `/opt/amnezia/awg/clients/*.conf`
- **Keys**: `/opt/amnezia/awg/*.key`

## Firewall Setup

**Cloud provider dashboard** (DigitalOcean/Hetzner/etc.):

- Allow **UDP port 51821** inbound

**No iptables config needed on host** - handled by container!

## Troubleshooting Quick Fixes

### No Internet After Connecting

```bash
# Verify container has NAT rules
docker exec amnezia-awg iptables -t nat -L -n | grep MASQUERADE

# If empty, restart container
docker restart amnezia-awg
```

### Import Error 900

**Use file import, NOT QR code** - QR codes don't work on iOS.

### Config Mismatch

Regenerate client:

```bash
rm /opt/amnezia/awg/clients/laptop.conf
# Edit awg0.conf and remove the [Peer] section
sudo bash scripts/add-client.sh laptop
```

## Verification

After client connects:

```bash
# Should show endpoint + handshake
docker exec amnezia-awg awg show awg0

# Example output:
# peer: ABC...
#   endpoint: 24.150.100.131:61705  ← Client's IP
#   latest handshake: 5 seconds ago  ← Recent!
#   transfer: 1.23 KiB received, 456 B sent  ← Data flowing!
```

## Backup

```bash
sudo bash scripts/manage.sh backup
# Creates: amneziawg-backup-YYYYMMDD-HHMMSS.tar.gz
```

## Full Documentation

- **README.md** - Main documentation
- **README.ru.md** - Russian documentation
- **TROUBLESHOOTING.md** - Detailed problem solving
- **docs/OBFUSCATION.md** - Technical details on obfuscation
- **docs/ARCHITECTURE.md** - System design and architecture
- **CONTRIBUTING.md** - How to contribute

## Support

- Issues:
  <https://github.com/YOUR-USERNAME/amneziawg-docker-install/issues>
- AmneziaVPN Docs: <https://docs.amnezia.org>
- Telegram: <https://t.me/amnezia_vpn_en>
