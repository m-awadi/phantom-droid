#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Device Pairing Helper
#===============================================================================
#  Interactive pairing for new devices.
#===============================================================================

set -euo pipefail

CONFIG_DIR="$HOME/.phantom-droid"
DEVICES_FILE="$CONFIG_DIR/devices.conf"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              ${BOLD}PHANTOM-DROID PAIRING WIZARD${NC}${CYAN}                  ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check adb
if [[ ! -x "$ADB" ]]; then
    echo -e "${RED}✗${NC} ADB not found. Please install Android SDK."
    exit 1
fi

# Start adb server
$ADB start-server 2>/dev/null

echo -e "${BOLD}On your Android phone:${NC}"
echo -e "  1. Go to ${CYAN}Settings → Developer Options → Wireless debugging${NC}"
echo -e "  2. Enable wireless debugging"
echo -e "  3. Tap ${CYAN}\"Pair device with pairing code\"${NC}"
echo -e "  4. Note the IP, port, and pairing code shown"
echo ""

# Get pairing info
read -p "Enter pairing IP:PORT (e.g., 192.168.1.100:37000): " pairing_address
read -p "Enter 6-digit pairing code: " pairing_code

echo ""
echo -e "${BLUE}→${NC} Pairing with $pairing_address..."

if $ADB pair "$pairing_address" "$pairing_code"; then
    echo -e "${GREEN}✓${NC} Pairing successful!"
else
    echo -e "${RED}✗${NC} Pairing failed. Check the code and try again."
    exit 1
fi

echo ""

# Get device name and connection IP
read -p "Enter a name for this device (e.g., pixel, samsung): " device_name

# Extract IP from pairing address
device_ip=$(echo "$pairing_address" | cut -d: -f1)
read -p "Enter device static IP [$device_ip]: " input_ip
device_ip="${input_ip:-$device_ip}"

echo ""
echo -e "${BLUE}→${NC} Getting connection port from phone..."
echo -e "  Check ${CYAN}Wireless debugging${NC} screen for the main port (not pairing port)"
read -p "Enter connection port: " connection_port

# Try to connect
echo ""
echo -e "${BLUE}→${NC} Connecting to $device_ip:$connection_port..."

if $ADB connect "$device_ip:$connection_port" | grep -q "connected"; then
    echo -e "${GREEN}✓${NC} Connected successfully!"

    # Save to config
    mkdir -p "$CONFIG_DIR"

    # Check if device already exists
    if grep -q "^${device_name}=" "$DEVICES_FILE" 2>/dev/null; then
        sed -i '' "/^${device_name}=/d" "$DEVICES_FILE"
    fi

    echo "${device_name}=${device_ip}" >> "$DEVICES_FILE"
    echo "$connection_port" > "$CONFIG_DIR/port_$device_name"

    echo -e "${GREEN}✓${NC} Device saved as '${BOLD}$device_name${NC}'"
    echo ""
    echo -e "${BOLD}Your device is ready!${NC}"
    echo -e "  Connect:    ${CYAN}phantom $device_name${NC}"
    echo -e "  Status:     ${CYAN}pstatus${NC}"
    echo -e "  Shell:      ${CYAN}pshell $device_name${NC}"
else
    echo -e "${RED}✗${NC} Connection failed. Try again with the correct port."
    exit 1
fi

echo ""
