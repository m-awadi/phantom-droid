#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Disconnect
#===============================================================================
#  Cleanly disconnects from the Android device.
#===============================================================================

DEVICE_IP="${PHANTOM_DEVICE_IP:-192.168.1.100}"
CONFIG_FILE="$HOME/.phantom-droid/port"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PORT=$(cat "$CONFIG_FILE" 2>/dev/null || echo "40293")

echo -e "${BLUE}Disconnecting from $DEVICE_IP:$PORT...${NC}"
$ADB disconnect "$DEVICE_IP:$PORT" 2>/dev/null

echo -e "${GREEN}✓ Disconnected${NC}"
echo ""
echo "Connected devices:"
$ADB devices -l
