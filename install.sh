#!/bin/bash
# AmneziaWG Docker Installer - Main Installation Script
# https://github.com/YOUR-USERNAME/amneziawg-docker-install

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Display security warning
cat <<'WARNING'
╔══════════════════════════════════════════════════════════════╗
║                    ⚠️  SECURITY WARNING  ⚠️                    ║
╚══════════════════════════════════════════════════════════════╝

WARNING

echo -e "${RED}${BOLD}DOWNLOADING AND RUNNING BASH SCRIPTS WITH ROOT PRIVILEGES"
echo -e "IS A TERRIBLE IDEA AND EXTREMELY INSECURE!${NC}"
echo
echo -e "${YELLOW}Before proceeding, you should:${NC}"
echo
echo "  1. ✓ Review the entire script source code"
echo "  2. ✓ Understand what each command does"
echo "  3. ✓ Verify the source is trustworthy"
echo "  4. ✓ Check the repository has community review"
echo "  5. ✓ Never pipe wget/curl output directly to bash"
echo
echo -e "${BOLD}Recommended approach:${NC}"
echo "  # Clone and inspect the repository"
echo "  git clone https://github.com/YOUR-USERNAME/amneziawg-docker-install"
echo "  cd amneziawg-docker-install"
echo
echo "  # Read the scripts"
echo "  less install.sh"
echo "  less scripts/setup.sh"
echo "  less scripts/add-client.sh"
echo
echo "  # Only run after understanding what they do"
echo "  sudo bash install.sh"
echo
echo -e "${RED}Running scripts from unknown sources can:"
echo "  • Install backdoors and malware"
echo "  • Steal your credentials and private keys"
echo "  • Compromise your entire server"
echo "  • Create botnets for attacking others"
echo -e "  • Expose your users' data${NC}"
echo
echo -e "${BLUE}This script will:${NC}"
echo "  • Install Docker (if not present)"
echo "  • Create /opt/amnezia/awg directory"
echo "  • Pull amneziavpn/amneziawg-go Docker image"
echo "  • Generate cryptographic keys"
echo "  • Create configuration files"
echo "  • Run a privileged Docker container"
echo "  • Modify network settings (IP forwarding)"
echo
echo -e "${YELLOW}Source code: https://github.com/YOUR-USERNAME/amneziawg-docker-install${NC}"
echo

read -p "Have you reviewed the source code and understand the risks? (yes/NO): " -r
echo

if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Installation cancelled."
    echo
    echo "Please review the source code first:"
    echo "  https://github.com/YOUR-USERNAME/amneziawg-docker-install"
    exit 1
fi

echo
echo -e "${GREEN}Proceeding with installation...${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If scripts are in the same directory, use them
if [ -f "${SCRIPT_DIR}/scripts/setup.sh" ]; then
    echo "Running setup from local scripts..."
    bash "${SCRIPT_DIR}/scripts/setup.sh"
else
    # Download from GitHub (not recommended but supported)
    echo -e "${YELLOW}Downloading setup script from GitHub...${NC}"
    echo "This is less secure than cloning the repository!"
    echo
    
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/amneziawg-docker-install/main/scripts/setup.sh -o "$TEMP_DIR/setup.sh"
    curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/amneziawg-docker-install/main/scripts/add-client.sh -o "$TEMP_DIR/add-client.sh"
    curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/amneziawg-docker-install/main/scripts/manage.sh -o "$TEMP_DIR/manage.sh"
    
    chmod +x "$TEMP_DIR"/*.sh
    
    # Run setup
    bash "$TEMP_DIR/setup.sh"
    
    # Install scripts system-wide
    echo
    echo "Installing management scripts to /usr/local/bin/..."
    cp "$TEMP_DIR/add-client.sh" /usr/local/bin/amneziawg-add-client
    cp "$TEMP_DIR/manage.sh" /usr/local/bin/amneziawg-manage
    chmod +x /usr/local/bin/amneziawg-*
    
    # Create wrapper
    cat > /usr/local/bin/amneziawg <<'WRAPPER'
#!/bin/bash
# AmneziaWG management wrapper

case "${1:-}" in
    add-client)
        shift
        exec amneziawg-add-client "$@"
        ;;
    status|list|show|logs|restart|stop|start|backup)
        exec amneziawg-manage "$@"
        ;;
    *)
        echo "AmneziaWG Docker Management"
        echo
        echo "Usage: amneziawg <command> [args]"
        echo
        echo "Commands:"
        echo "  add-client <name>   Add new VPN client"
        echo "  status              Show server status"
        echo "  list                List all clients"
        echo "  show                Show configuration"
        echo "  logs                View logs"
        echo "  restart             Restart server"
        echo "  stop                Stop server"
        echo "  start               Start server"
        echo "  backup              Backup configuration"
        echo
        echo "Examples:"
        echo "  amneziawg add-client laptop"
        echo "  amneziawg status"
        echo "  amneziawg backup"
        exit 1
        ;;
esac
WRAPPER
    chmod +x /usr/local/bin/amneziawg
    
    echo -e "${GREEN}✓ Scripts installed${NC}"
fi

echo
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║           Installation completed successfully!           ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${BLUE}Next steps:${NC}"
echo
echo "  1. Add your first client:"
echo -e "     ${GREEN}sudo amneziawg add-client laptop${NC}"
echo
echo "  2. Check server status:"
echo -e "     ${GREEN}sudo amneziawg status${NC}"
echo
echo "  3. Configure external firewall (if applicable):"
echo "     • Allow UDP port $(grep 'AWG_PORT' /opt/amnezia/awg/awg0.conf 2>/dev/null | awk '{print $3}' || echo '51820') inbound"
echo
echo "For help and documentation:"
echo "  https://github.com/YOUR-USERNAME/amneziawg-docker-install"
echo
