#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Status Display (Multi-Device)
#===============================================================================
#  Shows detailed status of all configured devices.
#===============================================================================

CONFIG_DIR="$HOME/.phantom-droid"
DEVICES_FILE="$CONFIG_DIR/devices.conf"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
LOG_FILE="/tmp/phantom-droid.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Get configured devices
get_devices() {
    grep -v '^#' "$DEVICES_FILE" 2>/dev/null | grep -v '^$' | grep '='
}

# Get saved port for device
get_port() {
    local name="$1"
    cat "$CONFIG_DIR/port_$name" 2>/dev/null || echo "40293"
}

# Show status for specific device or all
show_status() {
    local filter_device="${1:-}"

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    ${BOLD}PHANTOM-DROID STATUS${NC}${CYAN}                            ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # System Status
    echo -e "${BOLD}System${NC}"
    echo -e "───────────────────────────────────────────────────────────────────"

    if pgrep -x "adb" > /dev/null 2>&1; then
        echo -e "  ADB Server:       ${GREEN}● Running${NC}"
    else
        echo -e "  ADB Server:       ${RED}○ Not running${NC}"
    fi

    # LaunchAgents
    if launchctl list 2>/dev/null | grep -q "com.phantom-droid.watchdog"; then
        echo -e "  Watchdog:         ${GREEN}● Active${NC}"
    else
        echo -e "  Watchdog:         ${RED}○ Inactive${NC}"
    fi

    echo ""

    # Devices
    echo -e "${BOLD}Devices${NC}"
    echo -e "───────────────────────────────────────────────────────────────────"

    local total=0
    local connected=0

    while IFS='=' read -r name ip; do
        [[ -z "$name" ]] && continue
        [[ -n "$filter_device" && "$name" != "$filter_device" ]] && continue

        ((total++))
        local port=$(get_port "$name")

        echo ""

        if $ADB devices 2>/dev/null | grep -q "$ip.*device"; then
            ((connected++))
            echo -e "  ${GREEN}●${NC} ${BOLD}$name${NC} ${DIM}($ip:$port)${NC}"

            # Get device details
            local model=$($ADB -s "$ip:$port" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
            local brand=$($ADB -s "$ip:$port" shell getprop ro.product.brand 2>/dev/null | tr -d '\r')
            local android=$($ADB -s "$ip:$port" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
            local battery=$($ADB -s "$ip:$port" shell dumpsys battery 2>/dev/null | grep "level:" | awk '{print $2}' | tr -d '\r')
            local charging=$($ADB -s "$ip:$port" shell dumpsys battery 2>/dev/null | grep "status:" | awk '{print $2}' | tr -d '\r')

            echo -e "    Device:         $brand $model"
            echo -e "    Android:        $android"

            # Battery with color
            if [[ -n "$battery" ]]; then
                local battery_color=$GREEN
                [[ "$battery" -lt 80 ]] && battery_color=$YELLOW
                [[ "$battery" -lt 30 ]] && battery_color=$RED

                local charge_icon=""
                [[ "$charging" == "2" ]] && charge_icon=" ⚡"
                [[ "$charging" == "5" ]] && charge_icon=" ✓"

                echo -e "    Battery:        ${battery_color}${battery}%${NC}${charge_icon}"
            fi

            echo -e "    Status:         ${GREEN}Connected${NC}"
        else
            echo -e "  ${RED}○${NC} ${BOLD}$name${NC} ${DIM}($ip:$port)${NC}"
            echo -e "    Status:         ${RED}Disconnected${NC}"
        fi
    done < <(get_devices)

    echo ""
    echo -e "───────────────────────────────────────────────────────────────────"
    echo -e "  Total: $total devices, ${GREEN}$connected connected${NC}, ${RED}$((total - connected)) disconnected${NC}"
    echo ""

    # Quick commands
    echo -e "${BOLD}Quick Commands${NC}"
    echo -e "───────────────────────────────────────────────────────────────────"
    echo -e "  ${CYAN}phantom -a${NC}              Connect all devices"
    echo -e "  ${CYAN}phantom <name>${NC}          Connect specific device"
    echo -e "  ${CYAN}phantom -l${NC}              List configured devices"
    echo -e "  ${CYAN}pshell <name>${NC}           Shell into device"
    echo -e "  ${CYAN}padd <name> <ip>${NC}        Add new device"
    echo ""

    # Logs
    echo -e "${BOLD}Logs${NC}"
    echo -e "───────────────────────────────────────────────────────────────────"
    echo -e "  File: ${CYAN}$LOG_FILE${NC}"
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "  Recent:"
        tail -3 "$LOG_FILE" 2>/dev/null | while read line; do
            echo -e "    ${DIM}$line${NC}"
        done
    fi
    echo ""
}

# Parse arguments
device=""
if [[ $# -gt 0 ]]; then
    device="$1"
fi

show_status "$device"
