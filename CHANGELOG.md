# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - 2026-03-28

### Fixed

- ✅ **QR codes now work perfectly on iOS!** (Format 12)
- ✅ Correct container structure: "amnezia-awg" + "protocol_version":"2"
- ✅ Field names in last_config use UPPERCASE (Jc, S3, I1) matching config file
- ✅ Removed ANSI color codes from plain text output
- ✅ Interactive IPv4 detection (avoids IPv6 from external services)

### Changed

- QR structure now matches file import exactly:
  - Container: "amnezia-awg" (not "amnezia-awg2")
  - Added: "protocol_version": "2"
  - Added: "last_config" nested JSON string
  - Field names: UPPERCASE in last_config
- SERVER_ENDPOINT detection: Interactive prompt with manual/auto options

### Discovered

- Container type "amnezia-awg2" exists but isn't used for imports
- File import uses "amnezia-awg" + "protocol_version":"2" for v2
- Field names must match config file exactly (case-sensitive)
- vpn:// prefix breaks iOS QR scanner (must be removed)

## [1.1.0] - 2026-03-27

### Added

- ✅ Working QR codes for iOS (Format 6 - partial)
- ✅ Full AWG v2 support (S3/S4, I1-I5)
- ✅ HTTP/DNS signature packets for traffic obfuscation
- ✅ Comprehensive troubleshooting guide
- ✅ Russian documentation
- ✅ Architecture and obfuscation docs

### Fixed (v1.1.0)

- ✅ Empty obfuscation parameters (read from server config)
- ✅ No internet after connection (iptables in container)
- ✅ Multi-network routing (NAT to eth0 and eth1)
- ✅ Process substitution error (temp file method)
- ✅ I5 hex encoding (even-length strings)
- ✅ Config reload errors

## [1.0.0] - 2026-03-27

### Added (v1.0.0)

- Initial Docker-based installer
- Stateless container architecture
- Hot reload support
- DNS name support
- Basic documentation

---

## Key Discoveries

### QR Code Format Evolution

- Format 1-5: Failed (various approaches)
- Format 6: Partial success (Base64 without vpn:// prefix)
- Format 7-10: Failed (wrong structure)
- Format 11: Close (used amnezia-awg2, lacked protocol_version)
- **Format 12: SUCCESS!** (amnezia-awg + protocol_version:2 + UPPERCASE fields)

### Critical Insights

1. Container "amnezia-awg" + "protocol_version":"2" = AWG v2
2. Container "amnezia-awg2" is for different use case
3. Field names in last_config must be UPPERCASE (Jc not junkPacketCount)
4. QR must NOT have vpn:// prefix for iOS
5. Structure must match extractWireGuardConfig() output exactly
