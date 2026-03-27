# AmneziaWG Obfuscation Explained

This document explains how AmneziaWG obfuscates VPN traffic to bypass Deep Packet Inspection (DPI) systems.

## Why Obfuscation is Needed

Standard WireGuard has distinctive packet signatures that make it easy to detect and block:
- Fixed packet types (1, 2, 3, 4)
- Predictable packet sizes
- Characteristic timing patterns
- Recognizable handshake sequence

Countries and ISPs use DPI to identify and block VPN traffic. AmneziaWG solves this by making traffic look random or like other protocols.

## Obfuscation Layers

### 1. Junk Packets (Jc, Jmin, Jmax)

**What**: Random packets sent before each handshake  
**Purpose**: Make traffic size unpredictable  
**Parameters**:
- `Jc`: Number of junk packets (recommended: 3-10)
- `Jmin`: Minimum packet size in bytes
- `Jmax`: Maximum packet size in bytes

**Example**:
```
Jc = 5
Jmin = 50
Jmax = 1000
```

Sends 5 random packets with sizes between 50-1000 bytes before handshake.

**Important**: If Jmax >= MTU (usually 1500), packets will fragment, which looks suspicious!

### 2. Message Padding (S1-S4)

**What**: Add random bytes to protocol messages  
**Purpose**: Hide WireGuard's characteristic message sizes

**Parameters**:
- `S1`: Padding for handshake initiation (15-150 bytes)
- `S2`: Padding for handshake response (15-150 bytes)
- `S3`: Padding for cookie reply (15-150 bytes) - AWG 2.0
- `S4`: Padding for transport messages (15-150 bytes) - AWG 2.0

**Constraints**:
- `S1 + 56 ≠ S2` AND `S2 + 56 ≠ S1`
- `S3 + 56 ≠ S4` AND `S4 + 56 ≠ S3`

Why 56? That's WireGuard's handshake initiation size. We want to avoid that.

**Example**:
```
S1 = 129
S2 = 83
S3 = 49
S4 = 99
```

### 3. Magic Headers (H1-H4)

**What**: Randomize the packet type field  
**Purpose**: Replace WireGuard's fixed type values (1,2,3,4)

**Parameters**: Non-overlapping number ranges
- `H1`: Handshake init header range
- `H2`: Handshake response header range
- `H3`: Cookie reply header range
- `H4`: Transport message header range

**Format**: `min-max` or single number
- Range: `123456-789012`
- Single: `654321`

**Example**:
```
H1 = 125846151-898407554
H2 = 959053812-1066514477
H3 = 1474249607-1476151460
H4 = 1505335300-2147483647
```

Instead of WireGuard's `type = 1`, packets have `type = [random number in H1 range]`

### 4. Signature Packets (I1-I5)

**What**: Custom packets sent before handshakes  
**Purpose**: Mimic legitimate protocols (HTTP, DNS, TLS, etc.)

**Tag Syntax**:
- `<b 0xHEX>`: Static bytes (hex-encoded)
- `<r SIZE>`: Random bytes
- `<rd SIZE>`: Random digits (0-9)
- `<rc SIZE>`: Random letters (a-zA-Z)
- `<t>`: 4-byte Unix timestamp

**HTTP Example**:
```
I1 = <b 0x474554202f20485454502f312e310d0a486f73743a20>
```
Decodes to: `GET / HTTP/1.1\r\nHost: `

**TLS Example**:
```
I1 = <b 0x160301>
I2 = <r 100>
```
TLS 1.0 handshake signature + 100 random bytes

**DNS Example**:
```
I1 = <t><b 0x0100000100000000000000>
I2 = <rc 10><b 0x00000100001>
```
Timestamp + DNS query header + random domain

**Combining Tags**:
```
I1 = <b 0x474554><rc 10><b 0x2e636f6d>
```
Results in: `GET` + 10 random letters + `.com`

## HTTP/DNS Signature Packets Used in This Installer

The default configuration mimics HTTP traffic:

```
I1 = <b 0x474554202f20485454502f312e310d0a486f73743a20>
     "GET / HTTP/1.1\r\nHost: "

I2 = <rc 7><b 0x2e636f6d0d0a>
     [7 random letters] + ".com\r\n"
     Example: "abcdefg.com\r\n"

I3 = <b 0x557365722d4167656e743a204d6f7a696c6c612f352e300d0a>
     "User-Agent: Mozilla/5.0\r\n"

I4 = <b 0x436f6e6e656374696f6e3a206b6565702d616c6976650d0a0d0a><r 20>
     "Connection: keep-alive\r\n\r\n" + 20 random bytes

I5 = <t><b 0x0100000100000000000000><rc 6><b 0x03636f6d000001000001>
     [timestamp] + DNS query header + random 6-letter domain + ".com" + query footer
```

**Result**: VPN handshake packets look like HTTP GET requests and DNS queries!

## Effectiveness

### What Gets Obfuscated

✅ Packet types (randomized with H1-H4)  
✅ Packet sizes (varied with Jc, Jmin, Jmax, S1-S4)  
✅ Protocol signatures (masked with I1-I5)  
✅ Timing patterns (junk packets add randomness)

### What's NOT Hidden

❌ Traffic is still encrypted (obviously encrypted data)  
❌ Connection persistence (long-lived connections are suspicious)  
❌ Packet frequency patterns (can still be analyzed statistically)  
❌ Destination IP (your VPN server is visible)

## Performance Impact

**Overhead from obfuscation**:
- Junk packets: Adds `Jc * (Jmin to Jmax)` bytes per handshake
- Padding: Adds S1+S2+S3+S4 bytes per handshake
- Signature packets: Adds I1+I2+I3+I4+I5 bytes per handshake

**Example calculation**:
```
Junk: 5 packets * 500 bytes avg = 2.5 KB
Padding: 129+83+49+99 = 360 bytes
Signatures: ~200 bytes
Total: ~3 KB overhead per handshake
```

Handshakes happen every ~2 minutes (PersistentKeepalive), so overhead is minimal.

**Latency**: Negligible (< 1ms for parameter processing)

## Customizing Obfuscation

### Conservative (Maximum Stealth)

```
Jc = 10      # More junk packets
Jmin = 100
Jmax = 1280  # Maximum before fragmentation
S1 = 150
S2 = 150
S3 = 150
S4 = 150
```

**Trade-off**: Slower connection establishment, higher bandwidth usage

### Aggressive (Minimum Overhead)

```
Jc = 3       # Fewer junk packets
Jmin = 10
Jmax = 50
S1 = 15      # Minimum padding
S2 = 15
S3 = 15
S4 = 15
```

**Trade-off**: Faster but easier to detect

### Balanced (Default)

```
Jc = 5
Jmin = 57
Jmax = 1242
S1 = 129
S2 = 83
S3 = 49
S4 = 99
```

Good balance between stealth and performance.

## Protocol Mimicry Strategies

### HTTP Traffic

Best for bypassing web-only filters:

```
I1 = <b 0x474554202f20485454502f312e310d0a>  # "GET / HTTP/1.1\r\n"
I2 = <r 50>
```

### HTTPS/TLS Traffic

Best for blending with encrypted web traffic:

```
I1 = <b 0x160301>  # TLS 1.0 handshake
I2 = <r 100>
I3 = <r 50>
```

### DNS Traffic

Best for blending with DNS queries:

```
I1 = <t><b 0x0100000100000000>
I2 = <rc 10><b 0x00000100001>
```

### SSH Traffic

```
I1 = <b 0x5353482d322e30>  # "SSH-2.0"
I2 = <r 30>
```

### BitTorrent Traffic (Controversial)

```
I1 = <b 0x13426974546f7272656e742070726f746f636f6c>
I2 = <r 8>
```

## Detection Resistance

### What DPI Systems Look For

1. **Fixed packet types** → Defeated by H1-H4
2. **Known packet sizes** → Defeated by S1-S4 and junk packets
3. **Protocol signatures** → Defeated by I1-I5
4. **Timing patterns** → Partially defeated by junk packets
5. **Statistical analysis** → Harder to defeat

### Best Practices

1. **Use all obfuscation layers** (Jc, S1-S4, H1-H4, I1-I5)
2. **Mimic common protocols** (HTTP/HTTPS most common)
3. **Change parameters periodically** (regenerate configs every few months)
4. **Use DNS names** (IP addresses can be blacklisted)
5. **Spread traffic across ports** (don't use 51820 - too obvious)
6. **Vary connection times** (don't connect/disconnect at fixed times)

## Limitations

Obfuscation is **not a silver bullet**:

- **Deep inspection can still detect patterns** with enough data
- **Encrypted payload is still obvious** (can't hide that data is encrypted)
- **Connection metadata** (duration, frequency) can be analyzed
- **Active probing** can detect VPN servers

**Use obfuscation as one layer** in defense-in-depth strategy.

## References

- [AmneziaWG GitHub](https://github.com/amnezia-vpn/amneziawg-go)
- [AmneziaWG Documentation](https://docs.amnezia.org/documentation/amnezia-wg/)
- [WireGuard Protocol](https://www.wireguard.com/protocol/)
- [Traffic Analysis Attacks](https://en.wikipedia.org/wiki/Traffic_analysis)
