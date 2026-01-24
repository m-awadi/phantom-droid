#!/bin/bash
#===============================================================================
#
#   ██████╗ ██╗  ██╗ █████╗ ███╗   ██╗████████╗ ██████╗ ███╗   ███╗
#   ██╔══██╗██║  ██║██╔══██╗████╗  ██║╚══██╔══╝██╔═══██╗████╗ ████║
#   ██████╔╝███████║███████║██╔██╗ ██║   ██║   ██║   ██║██╔████╔██║
#   ██╔═══╝ ██╔══██║██╔══██║██║╚██╗██║   ██║   ██║   ██║██║╚██╔╝██║
#   ██║     ██║  ██║██║  ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚═╝ ██║
#   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝
#                      ██████╗ ██████╗  ██████╗ ██╗██████╗
#                      ██╔══██╗██╔══██╗██╔═══██╗██║██╔══██╗
#                      ██║  ██║██████╔╝██║   ██║██║██║  ██║
#                      ██║  ██║██╔══██╗██║   ██║██║██║  ██║
#                      ██████╔╝██║  ██║╚██████╔╝██║██████╔╝
#                      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝╚═════╝
#
#   Resilient Android Wireless Debugging for macOS
#
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/bin"
LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"
CONFIG_DIR="$HOME/.phantom-droid"

# Default device IP
DEFAULT_IP="192.168.1.100"

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                               ║${NC}"
echo -e "${CYAN}║   ${BOLD}PHANTOM-DROID INSTALLER${NC}${CYAN}                                    ║${NC}"
echo -e "${CYAN}║   Resilient Android Wireless Debugging                        ║${NC}"
echo -e "${CYAN}║                                                               ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for Android SDK
echo -e "${BLUE}Checking prerequisites...${NC}"

if [[ -z "${ANDROID_HOME:-}" ]]; then
    if [[ -d "$HOME/Library/Android/sdk" ]]; then
        export ANDROID_HOME="$HOME/Library/Android/sdk"
        echo -e "  ${GREEN}✓${NC} Android SDK found at $ANDROID_HOME"
    else
        echo -e "  ${RED}✗${NC} Android SDK not found"
        echo -e "    Please install Android Studio or set ANDROID_HOME"
        exit 1
    fi
else
    echo -e "  ${GREEN}✓${NC} ANDROID_HOME is set: $ANDROID_HOME"
fi

# Check for adb
ADB="$ANDROID_HOME/platform-tools/adb"
if [[ -x "$ADB" ]]; then
    ADB_VERSION=$($ADB version | head -1)
    echo -e "  ${GREEN}✓${NC} ADB found: $ADB_VERSION"
else
    echo -e "  ${RED}✗${NC} ADB not found in Android SDK"
    exit 1
fi

# Check adb supports mdns
if $ADB mdns check 2>/dev/null | grep -q "mdns"; then
    echo -e "  ${GREEN}✓${NC} ADB mDNS support available"
else
    echo -e "  ${YELLOW}⚠${NC} ADB mDNS not available (fallback to port scanning)"
fi

echo ""

# Get device IP
echo -e "${BLUE}Configuration${NC}"
echo -e "─────────────────────────────────────────"
read -p "  Enter your Android device's static IP [$DEFAULT_IP]: " DEVICE_IP
DEVICE_IP="${DEVICE_IP:-$DEFAULT_IP}"
echo -e "  ${GREEN}✓${NC} Device IP: $DEVICE_IP"
echo ""

# Create directories
echo -e "${BLUE}Creating directories...${NC}"
mkdir -p "$BIN_DIR"
mkdir -p "$LAUNCHAGENTS_DIR"
mkdir -p "$CONFIG_DIR"
echo -e "  ${GREEN}✓${NC} Created $BIN_DIR"
echo -e "  ${GREEN}✓${NC} Created $LAUNCHAGENTS_DIR"
echo -e "  ${GREEN}✓${NC} Created $CONFIG_DIR"
echo ""

# Install scripts
echo -e "${BLUE}Installing scripts...${NC}"
for script in "$SCRIPT_DIR/scripts/"*.sh; do
    filename=$(basename "$script")
    # Replace __DEVICE_IP__ placeholder if present
    sed "s/__DEVICE_IP__/$DEVICE_IP/g" "$script" > "$BIN_DIR/$filename"
    chmod +x "$BIN_DIR/$filename"
    echo -e "  ${GREEN}✓${NC} Installed $filename"
done
echo ""

# Install LaunchAgents
echo -e "${BLUE}Installing LaunchAgents...${NC}"

# Unload existing agents
for plist in "$LAUNCHAGENTS_DIR"/com.phantom-droid.*.plist; do
    if [[ -f "$plist" ]]; then
        launchctl unload "$plist" 2>/dev/null || true
    fi
done

# Install new agents
for plist in "$SCRIPT_DIR/launchagents/"*.plist; do
    filename=$(basename "$plist")
    # Replace __HOME__ placeholder with actual home directory
    sed "s|__HOME__|$HOME|g" "$plist" > "$LAUNCHAGENTS_DIR/$filename"
    echo -e "  ${GREEN}✓${NC} Installed $filename"
done
echo ""

# Load LaunchAgents
echo -e "${BLUE}Starting services...${NC}"
for plist in "$LAUNCHAGENTS_DIR"/com.phantom-droid.*.plist; do
    if [[ -f "$plist" ]]; then
        launchctl load "$plist" 2>/dev/null || true
        filename=$(basename "$plist")
        echo -e "  ${GREEN}✓${NC} Started $filename"
    fi
done
echo ""

# Save device IP configuration
echo "$DEVICE_IP" > "$CONFIG_DIR/device_ip"
echo "40293" > "$CONFIG_DIR/port"

# Add shell configuration
SHELL_CONFIG=""
if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    SHELL_CONFIG="$HOME/.bashrc"
fi

if [[ -n "$SHELL_CONFIG" ]]; then
    # Check if already configured
    if ! grep -q "PHANTOM-DROID" "$SHELL_CONFIG" 2>/dev/null; then
        echo -e "${BLUE}Adding shell configuration...${NC}"
        cat >> "$SHELL_CONFIG" << 'SHELL_EOF'

# ─────────────────────────────────────────────────────────────────────────────
# PHANTOM-DROID: Android Wireless Debugging
# ─────────────────────────────────────────────────────────────────────────────
export PATH="$ANDROID_HOME/platform-tools:$HOME/bin:$PATH"
export PHANTOM_DEVICE_IP="__DEVICE_IP__"

# Dynamic port detection
_phantom_device() {
    local ip=$(cat ~/.phantom-droid/device_ip 2>/dev/null || echo "192.168.1.100")
    local port=$(cat ~/.phantom-droid/port 2>/dev/null || echo "40293")
    echo "$ip:$port"
}

# Aliases
alias phantom='phantom-connect.sh'
alias phantom-status='phantom-status.sh'
alias pconnect='phantom-connect.sh'
alias pdisconnect='phantom-disconnect.sh'
alias pstatus='phantom-status.sh'
alias pshell='adb -s $(_phantom_device) shell'
alias plog='adb -s $(_phantom_device) logcat'
alias pinstall='adb -s $(_phantom_device) install'
alias prestart='phantom-disconnect.sh && phantom-connect.sh'
alias pscrcpy='scrcpy -s $(_phantom_device)'
# ─────────────────────────────────────────────────────────────────────────────
SHELL_EOF

        # Replace placeholder with actual IP
        sed -i '' "s/__DEVICE_IP__/$DEVICE_IP/g" "$SHELL_CONFIG"
        echo -e "  ${GREEN}✓${NC} Added aliases to $SHELL_CONFIG"
    else
        echo -e "${YELLOW}⚠${NC} Shell configuration already exists in $SHELL_CONFIG"
    fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                 INSTALLATION COMPLETE! 🎉                     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Quick Start:${NC}"
echo -e "  1. On your phone: Enable ${CYAN}Settings → Developer Options → Wireless debugging${NC}"
echo -e "  2. Pair once: ${CYAN}adb pair <ip>:<pairing-port> <code>${NC}"
echo -e "  3. Run: ${CYAN}source $SHELL_CONFIG${NC} (or open new terminal)"
echo -e "  4. Connect: ${CYAN}phantom${NC} or ${CYAN}pconnect${NC}"
echo ""
echo -e "${BOLD}Useful Commands:${NC}"
echo -e "  ${CYAN}phantom${NC}         - Connect to device (auto-discovers port)"
echo -e "  ${CYAN}pstatus${NC}         - Show connection status"
echo -e "  ${CYAN}pshell${NC}          - Open device shell"
echo -e "  ${CYAN}plog${NC}            - View logcat"
echo -e "  ${CYAN}pinstall app.apk${NC} - Install APK"
echo -e "  ${CYAN}pscrcpy${NC}         - Mirror screen (requires scrcpy)"
echo ""
echo -e "${BOLD}Auto-Connect:${NC}"
echo -e "  Watchdog runs every 2 minutes and on network changes."
echo -e "  Your device will reconnect automatically!"
echo ""
echo -e "Logs: ${CYAN}/tmp/phantom-droid.log${NC}"
echo ""
