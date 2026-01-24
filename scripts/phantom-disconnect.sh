#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Disconnect (Multi-Device)
#===============================================================================
#  Disconnects from specified device or all devices.
#===============================================================================

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

get_devices() {
    grep -v '^#' "$DEVICES_FILE" 2>/dev/null | grep -v '^$' | grep '='
}

get_device_ip() {
    local name="$1"
    grep "^${name}=" "$DEVICES_FILE" 2>/dev/null | cut -d= -f2
}

get_default_device() {
    get_devices | head -1 | cut -d= -f1
}

get_port() {
    local name="$1"
    cat "$CONFIG_DIR/port_$name" 2>/dev/null || echo "40293"
}

show_usage() {
    echo ""
    echo -e "${CYAN}Usage:${NC} phantom-disconnect.sh [OPTIONS] [DEVICE]"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  -a, --all    Disconnect all devices"
    echo "  -h, --help   Show this help"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  phantom-disconnect.sh              # Disconnect default device"
    echo "  phantom-disconnect.sh oneplus      # Disconnect 'oneplus'"
    echo "  phantom-disconnect.sh -a           # Disconnect all"
    echo ""
}

disconnect_device() {
    local name="$1"
    local ip=$(get_device_ip "$name")

    if [[ -z "$ip" ]]; then
        echo -e "${RED}✗${NC} Device '$name' not found"
        return 1
    fi

    local port=$(get_port "$name")

    echo -e "${BLUE}→${NC} Disconnecting $name ($ip:$port)..."
    $ADB disconnect "$ip:$port" 2>/dev/null
    echo -e "${GREEN}✓${NC} Disconnected $name"
}

main() {
    local disconnect_all=false
    local device=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)
                disconnect_all=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
            *)
                device="$1"
                shift
                ;;
        esac
    done

    echo ""

    if [[ "$disconnect_all" == true ]]; then
        echo -e "${BOLD}Disconnecting all devices...${NC}"
        echo ""
        while IFS='=' read -r name ip; do
            [[ -z "$name" ]] && continue
            disconnect_device "$name"
        done < <(get_devices)
    else
        if [[ -z "$device" ]]; then
            device=$(get_default_device)
        fi

        if [[ -z "$device" ]]; then
            echo -e "${RED}✗${NC} No devices configured"
            exit 1
        fi

        disconnect_device "$device"
    fi

    echo ""
    echo -e "${BOLD}Connected devices:${NC}"
    $ADB devices -l | tail -n +2 | grep -v "^$" | while read line; do
        echo -e "  ${GREEN}●${NC} $line"
    done || echo "  (none)"
    echo ""
}

main "$@"
