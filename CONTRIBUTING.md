# Contributing to AmneziaWG Docker Install

Thank you for your interest in contributing! This project aims to provide
a secure, easy-to-use installer for AmneziaWG VPN servers.

## Code of Conduct

- Be respectful and constructive
- Focus on security and user safety
- Document all changes thoroughly
- Test before submitting

## How to Contribute

### Reporting Issues

Before opening an issue:

1. Check existing issues for duplicates
2. Gather diagnostic information
3. Include your OS, Docker version, and setup details
4. Provide logs and error messages

**Diagnostic info to include:**

```bash
# System info
uname -a
docker version

# Container status
docker ps
docker logs amnezia-awg

# Config (sanitize private keys!)
cat /opt/amnezia/awg/awg0.conf | sed 's/PrivateKey = .*/PrivateKey = [REDACTED]/'
```

### Submitting Changes

1. **Fork the repository**
2. **Create a feature branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow existing code style
   - Add comments for complex logic
   - Update documentation

4. **Test thoroughly**
   - Test on clean VPS
   - Test with existing WireGuard installation
   - Test client connection and internet access
   - Test on multiple platforms if possible

5. **Document changes**
   - Update README.md if needed
   - Update TROUBLESHOOTING.md for new issues
   - Add examples

6. **Submit pull request**
   - Describe what changed and why
   - Reference related issues
   - Include test results

## Security Guidelines

### Critical Rules

- **NEVER commit private keys** or configs with real credentials
- **NEVER add backdoors** or phone-home functionality
- **NEVER use `curl | bash`** patterns in documentation
- **ALWAYS warn about security implications**
- **ALWAYS validate user input** in scripts
- **ALWAYS use `set -e`** in bash scripts to fail fast

### Code Review Focus

When reviewing PRs, check for:

- Command injection vulnerabilities
- Unvalidated user input
- Missing error handling
- Hardcoded credentials
- Unnecessary privileges (avoid `--privileged` if possible)
- Clear documentation

## Testing Checklist

Before submitting, verify:

- [ ] Fresh install works on Ubuntu 22.04
- [ ] Fresh install works on Debian 11
- [ ] Works with existing WireGuard installation
- [ ] Client can connect and access internet
- [ ] Hot reload works (add client without restart)
- [ ] Backup/restore works
- [ ] Scripts handle errors gracefully
- [ ] Documentation is updated
- [ ] No private keys in commits
- [ ] Security warnings are prominent

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR-USERNAME/amneziawg-docker-install.git
cd amneziawg-docker-install

# Create test branch
git checkout -b test/my-changes

# Make changes to scripts/
nano scripts/setup.sh

# Test on a VPS or VM (DO NOT test on production!)
scp -r scripts/ user@test-vps:/tmp/
ssh user@test-vps
cd /tmp/scripts
sudo bash setup.sh

# If successful, commit and push
git add scripts/setup.sh
git commit -m "Fix: description of what you fixed"
git push origin test/my-changes
```

## Documentation Standards

- Use clear, simple language
- Include examples for all commands
- Explain WHY, not just WHAT
- Add troubleshooting sections for new features
- Keep security warnings visible
- Support both English and Russian documentation

## Script Standards

### Bash Scripts

```bash
#!/bin/bash
# Brief description of what this script does

set -e  # Exit on error

# Use meaningful variable names
AWG_CONFIG_DIR="/opt/amnezia/awg"

# Validate inputs
if [ -z "$CLIENT_NAME" ]; then
    echo "Error: CLIENT_NAME required"
    exit 1
fi

# Use colors for important messages
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Success!${NC}"

# Clean up on exit
trap "rm -f /tmp/tempfile" EXIT
```

### Error Handling

- Check command success before continuing
- Provide helpful error messages
- Suggest solutions in error output
- Clean up temporary files
- Don't leave system in broken state

### Comments

- Comment complex logic
- Explain WHY, not obvious WHAT
- Include examples in comments
- Link to relevant documentation

## Questions?

Open an issue or reach out:

- Issues: <https://github.com/YOUR-USERNAME/amneziawg-docker-install/issues>
- Discussions:
  <https://github.com/YOUR-USERNAME/amneziawg-docker-install/discussions>

## Thank You

Your contributions help make secure VPN access easier and more accessible.
Every bug report, documentation improvement, and code contribution matters!
