# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-03-27

### Added
- ✅ **Working QR codes for iOS!** Format 6 (Base64 without vpn:// prefix)
- ✅ Automatic QR code generation in add-client.sh
- ✅ Full AWG v2 support (S3/S4 parameters)
- ✅ HTTP/DNS signature packets (I1-I5) for traffic obfuscation
- ✅ Comprehensive troubleshooting guide (17KB)
- ✅ Russian documentation (README.ru.md)
- ✅ Architecture and obfuscation technical docs
- ✅ QR format testing script

### Fixed
- ✅ QR code import on iOS (was: Format with vpn:// prefix, now: Base64 only)
- ✅ Empty obfuscation parameters (now reads from server config)
- ✅ No internet after connection (added iptables to container)
- ✅ Process substitution error (use temp files in container)
- ✅ Multi-network routing (NAT to both eth0 and eth1)
- ✅ I5 hex encoding (even-length strings)
- ✅ Config reload fopen error (strip to temp file first)

### Changed
- Default VPN subnet: 10.8.1.0/24 → 10.66.66.0/24 (avoid conflicts)
- QR generation: Now uses Format 6 (iOS compatible)
- Documentation: Added security warnings prominently

### Testing
- Tested on Ubuntu 22.04
- Tested with iOS AmneziaVPN 4.8.14
- Tested alongside native WireGuard
- QR code import: ✅ Working (Format 6)
- File import: ✅ Working
- Internet access: ✅ Working

## [1.0.0] - 2026-03-27 (Initial Development)

### Added
- Initial Docker-based installer
- Stateless container architecture
- Hot reload support
- DNS name support for endpoints
- Basic documentation

### Known Issues
- QR codes didn't work on iOS (fixed in v1.1.0)
- Obfuscation parameters could be empty (fixed in v1.1.0)

---

## Version Format

This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR**: Incompatible changes (config format, breaking changes)
- **MINOR**: New features (backwards compatible)
- **PATCH**: Bug fixes (backwards compatible)
