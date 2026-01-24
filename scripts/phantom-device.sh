#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Device Manager
#===============================================================================
#  Add, remove, and manage configured devices.
#===============================================================================

set -euo pipefail

CONFIG_DIR="$HOME/.phantom-droid"
DEVICES_FILE="$CONFIG_DIR/devices.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Ensure config exists
mkdir -p "$CONFIG_DIR"
touch "$DEVICES_FILE"

show_usage() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              ${BOLD}PHANTOM-DROID DEVICE MANAGER${NC}${CYAN}                  ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Usage:${NC} phantom-device.sh <command> [args]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo "  add <name> <ip>     Add a new device"
    echo "  remove <name>       Remove a device"
    echo "  list                List all devices"
    echo "  set-default <name>  Set default device"
    echo "  edit                Open config in editor"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  phantom-device.sh add pixel 192.168.1.101"
    echo "  phantom-device.sh add samsung 192.168.1.102"
    echo "  phantom-device.sh remove pixel"
    echo "  phantom-device.sh set-default samsung"
    echo ""
    echo -e "${BOLD}Config file:${NC} $DEVICES_FILE"
    echo ""
}

# Add a device
add_device() {
    local name="$1"
    local ip="$2"

    # Validate name (alphanumeric and underscore only)
    if [[ ! "$name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        echo -e "${RED}✗${NC} Invalid device name. Use letters, numbers, underscore, hyphen."
        exit 1
    fi

    # Validate IP
    if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}✗${NC} Invalid IP address format."
        exit 1
    fi

    # Check if device already exists
    if grep -q "^${name}=" "$DEVICES_FILE" 2>/dev/null; then
        echo -e "${YELLOW}⚠${NC} Device '$name' already exists. Updating IP..."
        # Remove old entry
        sed -i '' "/^${name}=/d" "$DEVICES_FILE"
    fi

    # Add device
    echo "${name}=${ip}" >> "$DEVICES_FILE"
    echo -e "${GREEN}✓${NC} Added device: ${BOLD}$name${NC} ($ip)"

    # Show current devices
    echo ""
    list_devices
}

# Remove a device
remove_device() {
    local name="$1"

    if ! grep -q "^${name}=" "$DEVICES_FILE" 2>/dev/null; then
        echo -e "${RED}✗${NC} Device '$name' not found."
        exit 1
    fi

    sed -i '' "/^${name}=/d" "$DEVICES_FILE"

    # Remove port file
    rm -f "$CONFIG_DIR/port_$name"

    echo -e "${GREEN}✓${NC} Removed device: ${BOLD}$name${NC}"
    echo ""
    list_devices
}

# List all devices
list_devices() {
    echo -e "${BOLD}Configured Devices:${NC}"
    echo -e "───────────────────────────────────────"

    local first=true
    while IFS='=' read -r name ip; do
        [[ -z "$name" || "$name" =~ ^# ]] && continue

        local default_marker=""
        if [[ "$first" == true ]]; then
            default_marker=" ${YELLOW}(default)${NC}"
            first=false
        fi

        echo -e "  ${BOLD}$name${NC}$default_marker = $ip"
    done < "$DEVICES_FILE"

    echo ""
}

# Set default device (move to top of file)
set_default() {
    local name="$1"

    if ! grep -q "^${name}=" "$DEVICES_FILE" 2>/dev/null; then
        echo -e "${RED}✗${NC} Device '$name' not found."
        exit 1
    fi

    # Get the device line
    local device_line=$(grep "^${name}=" "$DEVICES_FILE")

    # Remove it from current position
    sed -i '' "/^${name}=/d" "$DEVICES_FILE"

    # Create temp file with device at top
    local temp_file=$(mktemp)
    echo "$device_line" > "$temp_file"
    cat "$DEVICES_FILE" >> "$temp_file"
    mv "$temp_file" "$DEVICES_FILE"

    echo -e "${GREEN}✓${NC} Set ${BOLD}$name${NC} as default device"
    echo ""
    list_devices
}

# Open config in editor
edit_config() {
    local editor="${EDITOR:-nano}"
    echo -e "${BLUE}→${NC} Opening $DEVICES_FILE in $editor..."
    "$editor" "$DEVICES_FILE"
}

# Main
main() {
    if [[ $# -lt 1 ]]; then
        show_usage
        exit 0
    fi

    local command="$1"
    shift

    case "$command" in
        add)
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}✗${NC} Usage: phantom-device.sh add <name> <ip>"
                exit 1
            fi
            add_device "$1" "$2"
            ;;
        remove|rm|delete)
            if [[ $# -lt 1 ]]; then
                echo -e "${RED}✗${NC} Usage: phantom-device.sh remove <name>"
                exit 1
            fi
            remove_device "$1"
            ;;
        list|ls)
            list_devices
            ;;
        set-default|default)
            if [[ $# -lt 1 ]]; then
                echo -e "${RED}✗${NC} Usage: phantom-device.sh set-default <name>"
                exit 1
            fi
            set_default "$1"
            ;;
        edit)
            edit_config
            ;;
        *)
            echo -e "${RED}✗${NC} Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
