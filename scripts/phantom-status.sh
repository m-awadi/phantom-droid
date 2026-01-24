#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Status Display
#===============================================================================
#  Shows detailed status of your wireless Android debugging connection.
#===============================================================================

# Configuration
DEVICE_IP="${PHANTOM_DEVICE_IP:-192.168.1.100}"
CONFIG_FILE="$HOME/.phantom-droid/port"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
LOG_FILE="/tmp/phantom-droid.log"

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
echo -e "${CYAN}║              ${BOLD}PHANTOM-DROID STATUS${NC}${CYAN}                         ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# System Status
echo -e "${BOLD}System Status${NC}"
echo -e "─────────────────────────────────────────"

# ADB Server
if pgrep -x "adb" > /dev/null 2>&1; then
    echo -e "  ADB Server:      ${GREEN}● Running${NC}"
else
    echo -e "  ADB Server:      ${RED}○ Not running${NC}"
fi

# Saved Port
if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "  Saved Port:      $(cat $CONFIG_FILE)"
else
    echo -e "  Saved Port:      ${YELLOW}Not set${NC}"
fi

# Target IP
echo -e "  Target IP:       $DEVICE_IP"
echo ""

# Connection Status
echo -e "${BOLD}Connection Status${NC}"
echo -e "─────────────────────────────────────────"

DEVICES=$($ADB devices -l 2>/dev/null | tail -n +2 | grep -v "^$")
if [[ -n "$DEVICES" ]]; then
    echo -e "  Connected Devices:"
    echo "$DEVICES" | while read line; do
        echo -e "    ${GREEN}●${NC} $line"
    done
else
    echo -e "  ${YELLOW}No devices connected${NC}"
fi

echo ""

# Check if our target device is connected
if $ADB devices 2>/dev/null | grep -q "$DEVICE_IP.*device"; then
    echo -e "  Phantom Device:  ${GREEN}● CONNECTED${NC}"

    PORT=$(cat "$CONFIG_FILE" 2>/dev/null || echo "40293")

    echo ""
    echo -e "${BOLD}Device Information${NC}"
    echo -e "─────────────────────────────────────────"

    # Get device info
    MODEL=$($ADB -s "$DEVICE_IP:$PORT" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
    BRAND=$($ADB -s "$DEVICE_IP:$PORT" shell getprop ro.product.brand 2>/dev/null | tr -d '\r')
    ANDROID=$($ADB -s "$DEVICE_IP:$PORT" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
    SDK=$($ADB -s "$DEVICE_IP:$PORT" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')
    BATTERY=$($ADB -s "$DEVICE_IP:$PORT" shell dumpsys battery 2>/dev/null | grep "level:" | awk '{print $2}' | tr -d '\r')
    CHARGING=$($ADB -s "$DEVICE_IP:$PORT" shell dumpsys battery 2>/dev/null | grep "status:" | awk '{print $2}' | tr -d '\r')

    echo -e "  Brand:           $BRAND"
    echo -e "  Model:           $MODEL"
    echo -e "  Android:         $ANDROID (SDK $SDK)"

    # Battery with color coding
    if [[ -n "$BATTERY" ]]; then
        if [[ "$BATTERY" -ge 80 ]]; then
            BATTERY_COLOR=$GREEN
        elif [[ "$BATTERY" -ge 30 ]]; then
            BATTERY_COLOR=$YELLOW
        else
            BATTERY_COLOR=$RED
        fi

        CHARGE_STATUS=""
        if [[ "$CHARGING" == "2" ]]; then
            CHARGE_STATUS=" ⚡ Charging"
        elif [[ "$CHARGING" == "5" ]]; then
            CHARGE_STATUS=" ✓ Full"
        fi

        echo -e "  Battery:         ${BATTERY_COLOR}${BATTERY}%${NC}${CHARGE_STATUS}"
    fi

    # Screen state
    SCREEN=$($ADB -s "$DEVICE_IP:$PORT" shell dumpsys display 2>/dev/null | grep "mScreenState" | awk -F= '{print $2}' | tr -d '\r')
    if [[ "$SCREEN" == "ON" ]]; then
        echo -e "  Screen:          ${GREEN}On${NC}"
    else
        echo -e "  Screen:          Off"
    fi

else
    echo -e "  Phantom Device:  ${RED}○ DISCONNECTED${NC}"
    echo ""
    echo -e "  ${YELLOW}Run 'phantom-connect.sh' to connect${NC}"
fi

echo ""
echo -e "${BOLD}LaunchAgents${NC}"
echo -e "─────────────────────────────────────────"

# Check LaunchAgents
if launchctl list 2>/dev/null | grep -q "com.phantom-droid.watchdog"; then
    echo -e "  Watchdog:        ${GREEN}● Active${NC}"
else
    echo -e "  Watchdog:        ${RED}○ Inactive${NC}"
fi

if launchctl list 2>/dev/null | grep -q "com.phantom-droid.wake"; then
    echo -e "  Wake Handler:    ${GREEN}● Active${NC}"
else
    echo -e "  Wake Handler:    ${RED}○ Inactive${NC}"
fi

echo ""
echo -e "${BOLD}Logs${NC}"
echo -e "─────────────────────────────────────────"
echo -e "  Log file:        $LOG_FILE"
if [[ -f "$LOG_FILE" ]]; then
    echo -e "  Last 3 entries:"
    tail -3 "$LOG_FILE" 2>/dev/null | while read line; do
        echo -e "    ${BLUE}$line${NC}"
    done
fi

echo ""
