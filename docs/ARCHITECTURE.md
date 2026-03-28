# Architecture Documentation

## Overview

This installer creates a Docker-based AmneziaWG VPN server with the
following design principles:

- **Stateless containers**: Configuration stored on host, not in container
- **Hot reload**: Add/remove clients without restarting server
- **Isolation**: Container handles VPN, host handles firewall
- **Flexibility**: Easy to backup, migrate, and customize

## System Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                         VPS Host                            │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Docker Bridge Network: amnezia-dns-net             │    │
│  │  Subnet: 172.29.172.0/24                            │    │
│  │  Bridge: amn0                                       │    │
│  │                                                     │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │  Container: amnezia-awg                     │    │    │
│  │  │  Image: amneziavpn/amneziawg-go:latest      │    │    │
│  │  │                                             │    │    │
│  │  │  Network Interfaces:                        │    │    │
│  │  │  ├─ eth0: 172.29.172.X (DNS network)        │    │    │
│  │  │  ├─ eth1: 172.17.0.X (default bridge)       │    │    │
│  │  │  └─ awg0: 10.66.66.1/24 (VPN tunnel)        │    │    │
│  │  │                                             │    │    │
│  │  │  Volumes:                                   │    │    │
│  │  │  ├─ /lib/modules (ro, kernel modules)       │    │    │
│  │  │  └─ /opt/amnezia/awg (rw, config)           │    │    │
│  │  │                                             │    │    │
│  │  │  Capabilities:                              │    │    │
│  │  │  ├─ NET_ADMIN (create interfaces)           │    │    │
│  │  │  ├─ SYS_MODULE (load kernel modules)        │    │    │
│  │  │  └─ Privileged (iptables)                   │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Host Network:                                              │
│  ├─ eth0: Public IP (e.g., 204.168.174.98)                  │
│  ├─ Port mapping: 0.0.0.0:51821 → container:51821/udp       │
│  └─ IP forwarding: Enabled (sysctl)                         │
│                                                             │
│  Filesystem:                                                │
│  └─ /opt/amnezia/awg/ (host storage)                        │
│     ├─ awg0.conf (server config)                            │
│     ├─ *.key (cryptographic keys)                           │
│     ├─ start.sh (container entrypoint)                      │
│     └─ clients/ (client configs)                            │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ VPN Tunnel (UDP 51821)
                          │ Obfuscated as HTTP/DNS
                          │
              ┌───────────┴───────────┐
              │                       │
        ┌─────▼─────┐          ┌─────▼─────┐
        │  Client 1 │          │  Client 2 │
        │           │          │           │
        │  VPN IP:  │          │  VPN IP:  │
        │10.66.66.2 │          │10.66.66.3 │
        └───────────┘          └───────────┘
```

## Network Layers

### Layer 1: Physical Network

- **Host interface**: eth0 (or similar)
- **Public IP**: Assigned by cloud provider
- **Firewall**: Cloud provider's firewall (must allow UDP port)

### Layer 2: Docker Networks

**amnezia-dns-net** (`172.29.172.0/24`):

- Purpose: Inter-container communication
- Usage: Optional DNS container can be added
- Bridge: `amn0` on host

**docker0** (default, `172.17.0.0/16`):

- Purpose: Default Docker networking
- Container gets eth1 on this network

### Layer 3: VPN Tunnel

**awg0** (`10.66.66.0/24`):

- Purpose: VPN client-to-client network
- Created by AmneziaWG inside container
- Virtual interface (WireGuard tunnel)

## Data Flow

### Outbound (Client → Internet)

```text
1. Client (10.66.66.2) sends packet to google.com

2. Packet encrypted by AmneziaWG on client device
   Outer: [Client Real IP] → [Server Public IP]:51821 (UDP)
   Inner: [10.66.66.2] → [8.8.8.8] (encrypted)

3. Packet arrives at VPS host:51821

4. Docker forwards to container:51821

5. Container's awg0 receives packet
   - Decrypts: [10.66.66.2] → [8.8.8.8]

6. Container's iptables FORWARD:
   awg0 → eth0/eth1 (allowed)

7. Container's iptables NAT (MASQUERADE):
   [10.66.66.2] → [172.17.0.X] (container's eth1 IP)

8. Docker NAT:
   [172.17.0.X] → [204.168.174.98] (host's public IP)

9. Packet exits to internet via host's eth0

10. Reply comes back (reverse path)
```

## Component Responsibilities

### Host System

**Responsibilities:**

- Run Docker daemon
- Expose VPN port (port mapping)
- Enable IP forwarding (sysctl)
- Store configuration files
- (Optional) External firewall rules

**Does NOT handle:**

- VPN protocol processing (in container)
- NAT for VPN clients (in container)
- Encryption/decryption (in container)

### Container

**Responsibilities:**

- Run AmneziaWG protocol (awg-go)
- Create awg0 interface
- Encrypt/decrypt packets
- Forward traffic (iptables FORWARD rules)
- NAT VPN subnet (iptables MASQUERADE)
- Read config from mounted volume

**Does NOT handle:**

- Exposing ports to internet (host does this)
- Storing configuration (on host volume)
- External firewall (host/cloud provider)

## Configuration Storage

All configuration lives on the **host** at `/opt/amnezia/awg/`:

```text
/opt/amnezia/awg/
├── awg0.conf              # Server WireGuard config
│                          # Updated when clients added
│                          # Mounted read-write into container
│
├── server_private.key     # Server's private key
│                          # Generated once, never changes
│                          # Permissions: 600 (owner only)
│
├── server_public.key      # Server's public key
│                          # Shared with all clients
│                          # Permissions: 644 (world-readable)
│
├── preshared.key          # Preshared key (PSK)
│                          # Same for all clients
│                          # Post-quantum security
│                          # Permissions: 600
│
├── obfuscation-params.txt # Human-readable reference
│                          # Not used by scripts (read from awg0.conf)
│                          # Useful for documentation
│
├── start.sh               # Container entrypoint script
│                          # Sets up awg0 interface
│                          # Configures iptables
│                          # Executable, mounted into container
│
└── clients/               # Client configurations
    ├── laptop.conf        # Individual client config
    ├── phone.conf         # Includes all obfuscation params
    └── tablet.conf        # Ready to import
```

## Container Lifecycle

### Startup Sequence

1. Docker runs container with `--entrypoint /opt/amnezia/awg/start.sh`
2. start.sh reads `/opt/amnezia/awg/awg0.conf` (from host volume)
3. Runs `awg-quick up` to create awg0 interface
4. Configures iptables for forwarding and NAT
5. Enters infinite loop (`tail -f /dev/null`)

### Hot Reload (Add Client)

1. Script appends [Peer] section to awg0.conf on host
2. Script runs `docker exec awg syncconf` to reload
3. Server accepts new peer **without restart**
4. No existing connections disrupted

### Restart Behavior

When container restarts:

1. Reads awg0.conf from host (includes all previously added peers)
2. Recreates awg0 interface with all peers
3. All clients can reconnect automatically

## Security Model

### Privilege Separation

- **Host**: Minimal privileges, just runs Docker
- **Container**: Runs as root inside container (isolated from host)
- **Config files**: Restrictive permissions (600/700)

### Crypto Material

**Server private key**:

- Generated once during setup
- Never leaves the server
- If compromised: All clients must regenerate

**Client private keys**:

- Generated per-client
- Stored in client configs
- If one compromised: Only that client affected

**Preshared key (PSK)**:

- Shared by all clients
- Adds post-quantum security
- If compromised: Still need private keys to connect

### Attack Surface

**Exposed**:

- UDP port (VPN endpoint)
- Server public key (not secret)
- VPN server IP address

**Protected**:

- Server private key (never transmitted)
- Client private keys (only on client devices)
- Preshared key (transmitted encrypted)
- Configuration on host (file permissions)

## Comparison with Native Installation

| Aspect | Docker (This Project) | Native (amneziawg-install) |
| ------ | --------------------- | -------------------------- |
| **Isolation** | ✅ Strong (containerized) | ⚠️ Weaker (kernel module) |
| **Updates** | ✅ Easy (pull new image) | ⚠️ Rebuild kernel module |
| **Portability** | ✅ Works anywhere Docker runs | ⚠️ Kernel-dependent |
| **Config Management** | ✅ Host filesystem | ✅ Host filesystem |
| **Performance** | ⚠️ Slight overhead | ✅ Native speed |
| **Complexity** | ⚠️ Docker knowledge needed | ✅ Simpler (systemd service) |
| **Persistence** | ✅ Host volume | ✅ Host filesystem |

## Design Decisions

### Why Docker?

**Pros**:

- Isolation from host system
- Easy updates (pull new image)
- Consistent environment across OSes
- No kernel module compilation

**Cons**:

- Requires Docker daemon
- Slightly higher resource usage
- More complex networking

### Why Host-Based Config?

**Pros**:

- Easy to backup (just tar /opt/amnezia/awg)
- Easy to edit (any text editor)
- Survives container recreation
- Version control friendly

**Cons**:

- Config not portable with container
- Must mount volume correctly

### Why iptables Inside Container?

**Decision**: Put NAT/forwarding rules **inside container**, not on host

**Rationale**:

- Container networking is isolated
- awg0 interface only exists inside container
- Host iptables can't see container's interfaces
- Allows users to manage host firewall separately

**Trade-off**: Container needs `--privileged` flag

## Networking Deep Dive

### Why Two Docker Networks?

The container connects to:

1. **amnezia-dns-net**: For future DNS container
2. **docker0** (default): For internet access

This creates **two eth interfaces** in the container, which caused routing
issues during development.

**Solution**: NAT to BOTH eth0 and eth1 in start.sh

### Why awg0 Can't Route Directly

The awg0 interface is virtual (exists only in container). Packets from awg0
need:

1. **FORWARD rules**: Allow awg0 → eth0/eth1
2. **NAT rules**: Rewrite source IP from VPN subnet to container IP
3. **Docker NAT**: Rewrite container IP to host IP

Without ALL three layers, packets get dropped.

## Performance Considerations

### Resource Usage

- **Memory**: ~50MB for container + awg-go process
- **CPU**: Minimal (< 1% idle, spikes during handshakes)
- **Disk**: ~100MB for Docker image, < 1MB for configs
- **Network**: Overhead from obfuscation (see OBFUSCATION.md)

### Scalability

Tested with:

- ✅ 10 simultaneous clients
- ✅ 100+ Mbps throughput
- ✅ < 5ms added latency

Not tested at scale (100+ clients) but should handle it fine.

### Bottlenecks

- **Not CPU**: Encryption is fast
- **Not memory**: Small memory footprint
- **Possibly network**: Depends on host's network bandwidth
- **Possibly iptables**: Many MASQUERADE rules can slow down

## Failure Modes

### Container Crashes

**Impact**: All VPN clients disconnected

**Recovery**: Auto-restart (--restart unless-stopped)

- Container reads awg0.conf on startup
- All peers restored automatically
- Clients reconnect within 25 seconds (PersistentKeepalive)

### Host Reboots

**Impact**: Container stops

**Recovery**: Docker auto-starts container on boot

- Configuration persists on host
- No manual intervention needed

### Config Corruption

**Impact**: Container won't start or clients can't connect

**Recovery**: Restore from backup

```bash
tar -xzf backup.tar.gz -C /opt/amnezia/awg/
docker restart amnezia-awg
```

### Docker Network Loss

**Impact**: Container can't reach internet

**Recovery**: Recreate network

```bash
docker network create --driver bridge --subnet=172.29.172.0/24 amnezia-dns-net
docker restart amnezia-awg
```

## Future Enhancements

Possible improvements:

1. **Multi-container setup**: Separate containers per protocol
   (AWG, OpenVPN, etc.)
2. **Web UI**: Browser-based management interface
3. **Monitoring**: Prometheus metrics export
4. **Automated backups**: Cron job to backup configs
5. **Client revocation**: CRL or key rotation
6. **IPv6 support**: Dual-stack VPN
7. **QR code fix**: Solve iOS compression issue
8. **Multiple servers**: Mesh VPN setup

## Related Projects

- **Official Amnezia Client**:
  <https://github.com/amnezia-vpn/amnezia-client>
- **AmneziaWG Protocol**: <https://github.com/amnezia-vpn/amneziawg-go>
- **Native Installer**: <https://github.com/wiresock/amneziawg-install>
- **WireGuard**: <https://www.wireguard.com/>
