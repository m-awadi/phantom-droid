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
#   Multi-Device Support
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
DEVICES_FILE="$CONFIG_DIR/devices.conf"

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                               ║${NC}"
echo -e "${CYAN}║   ${BOLD}PHANTOM-DROID INSTALLER${NC}${CYAN}                                    ║${NC}"
echo -e "${CYAN}║   Resilient Android Wireless Debugging (Multi-Device)         ║${NC}"
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
    cp "$script" "$BIN_DIR/$filename"
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

# Device configuration
echo -e "${BLUE}Device Configuration${NC}"
echo -e "───────────────────────────────────────────────────────────────────"

if [[ -f "$DEVICES_FILE" ]] && [[ -s "$DEVICES_FILE" ]]; then
    echo -e "  ${YELLOW}⚠${NC} Existing device configuration found. Keeping it."
    echo ""
    echo -e "  ${BOLD}Configured devices:${NC}"
    grep -v '^#' "$DEVICES_FILE" 2>/dev/null | grep -v '^$' | while read line; do
        echo -e "    $line"
    done
else
    echo -e "  Let's add your first device."
    echo ""
    read -p "  Device name (e.g., oneplus, pixel): " device_name
    device_name="${device_name:-myphone}"

    read -p "  Device IP address: " device_ip
    device_ip="${device_ip:-192.168.1.100}"

    # Create devices file
    cat > "$DEVICES_FILE" << EOF
# Phantom-Droid Device Configuration
# Format: DEVICE_NAME=IP_ADDRESS
# The first device is the default.
#
# Add more devices:
#   padd pixel 192.168.1.101
#   padd samsung 192.168.1.102
#
# Or edit this file directly.

${device_name}=${device_ip}
EOF

    echo -e "  ${GREEN}✓${NC} Added device: ${BOLD}$device_name${NC} ($device_ip)"
fi
echo ""

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
# PHANTOM-DROID: Android Wireless Debugging (Multi-Device)
# ─────────────────────────────────────────────────────────────────────────────
export PATH="$ANDROID_HOME/platform-tools:$HOME/bin:$PATH"

# Get device info from config
_phantom_device() {
    local name="${1:-$(head -1 ~/.phantom-droid/devices.conf 2>/dev/null | grep -v '^#' | cut -d= -f1)}"
    local ip=$(grep "^${name}=" ~/.phantom-droid/devices.conf 2>/dev/null | cut -d= -f2)
    local port=$(cat ~/.phantom-droid/port_$name 2>/dev/null || echo "40293")
    echo "$ip:$port"
}

# Main commands
alias phantom='phantom-connect.sh'
alias pstatus='phantom-status.sh'
alias ppair='phantom-pair.sh'

# Connection shortcuts
alias pconnect='phantom-connect.sh'
alias pdisconnect='phantom-disconnect.sh'
alias prestart='phantom-disconnect.sh -a && phantom-connect.sh -a'

# Device management
alias padd='phantom-device.sh add'
alias premove='phantom-device.sh remove'
alias plist='phantom-device.sh list'
alias pdefault='phantom-device.sh set-default'

# ADB shortcuts (use: pshell [device], plog [device], etc.)
pshell() { adb -s $(_phantom_device "$1") shell; }
plog() { adb -s $(_phantom_device "$1") logcat; }
pinstall() { local apk="$1"; shift; adb -s $(_phantom_device "$1") install "$apk"; }
pscrcpy() { scrcpy -s $(_phantom_device "$1"); }
ppush() { local src="$1"; local dst="$2"; shift 2; adb -s $(_phantom_device "$1") push "$src" "$dst"; }
ppull() { local src="$1"; local dst="$2"; shift 2; adb -s $(_phantom_device "$1") pull "$src" "$dst"; }
# ─────────────────────────────────────────────────────────────────────────────
SHELL_EOF
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
echo -e "${BOLD}Next Steps:${NC}"
echo -e "  1. Run: ${CYAN}source $SHELL_CONFIG${NC} (or open new terminal)"
echo -e "  2. Pair your phone: ${CYAN}ppair${NC} (interactive wizard)"
echo -e "  3. Connect: ${CYAN}phantom${NC}"
echo ""
echo -e "${BOLD}Multi-Device Commands:${NC}"
echo -e "  ${CYAN}phantom${NC}              Connect default device"
echo -e "  ${CYAN}phantom pixel${NC}        Connect specific device"
echo -e "  ${CYAN}phantom -a${NC}           Connect ALL devices"
echo -e "  ${CYAN}phantom -l${NC}           List configured devices"
echo ""
echo -e "${BOLD}Device Management:${NC}"
echo -e "  ${CYAN}ppair${NC}                Interactive pairing wizard"
echo -e "  ${CYAN}padd pixel 192.168.1.101${NC}   Add device"
echo -e "  ${CYAN}premove pixel${NC}        Remove device"
echo -e "  ${CYAN}pdefault pixel${NC}       Set default device"
echo ""
echo -e "${BOLD}Device Interaction:${NC}"
echo -e "  ${CYAN}pstatus${NC}              Show all devices status"
echo -e "  ${CYAN}pshell${NC}               Shell into default device"
echo -e "  ${CYAN}pshell pixel${NC}         Shell into 'pixel'"
echo -e "  ${CYAN}plog${NC}                 Logcat from default device"
echo -e "  ${CYAN}pinstall app.apk${NC}     Install APK"
echo ""
echo -e "${BOLD}Auto-Connect:${NC}"
echo -e "  Watchdog monitors ALL configured devices every 2 minutes."
echo -e "  All devices reconnect automatically!"
echo ""
echo -e "Config: ${CYAN}$DEVICES_FILE${NC}"
echo -e "Logs:   ${CYAN}/tmp/phantom-droid.log${NC}"
echo ""
