#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Resilient Android Wireless Debugging Connection
#===============================================================================
#  Multi-device support - connects to any configured Android device.
#  Uses mDNS discovery, port scanning, and persistent configuration.
#===============================================================================

set -euo pipefail

# Configuration
CONFIG_DIR="$HOME/.phantom-droid"
DEVICES_FILE="$CONFIG_DIR/devices.conf"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
LOG_FILE="/tmp/phantom-droid.log"
DEFAULT_PORT="40293"
PORT_RANGE_START=37000
PORT_RANGE_END=45000
PORT_SCAN_STEP=100

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

# Initialize devices file if not exists
init_devices_file() {
    if [[ ! -f "$DEVICES_FILE" ]]; then
        cat > "$DEVICES_FILE" << 'EOF'
# Phantom-Droid Device Configuration
# Format: DEVICE_NAME=IP_ADDRESS
# Example:
#   oneplus=192.168.1.100
#   pixel=192.168.1.101
#   samsung=192.168.1.102
#
# The first device is the default when no device is specified.

oneplus=192.168.1.100
EOF
    fi
}

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
    echo -e "$1"
}

log_success() { log "${GREEN}✓ $1${NC}"; }
log_error() { log "${RED}✗ $1${NC}"; }
log_info() { log "${BLUE}→ $1${NC}"; }
log_warn() { log "${YELLOW}⚠ $1${NC}"; }

# Get list of configured devices
get_devices() {
    grep -v '^#' "$DEVICES_FILE" 2>/dev/null | grep -v '^$' | grep '='
}

# Get device IP by name
get_device_ip() {
    local name="$1"
    grep "^${name}=" "$DEVICES_FILE" 2>/dev/null | cut -d= -f2
}

# Get first (default) device name
get_default_device() {
    get_devices | head -1 | cut -d= -f1
}

# Get all device names
get_device_names() {
    get_devices | cut -d= -f1
}

# Get saved port for a device
get_saved_port() {
    local device="$1"
    cat "$CONFIG_DIR/port_$device" 2>/dev/null || echo "$DEFAULT_PORT"
}

# Save port for a device
save_port() {
    local device="$1"
    local port="$2"
    echo "$port" > "$CONFIG_DIR/port_$device"
}

# Check if adb exists
check_adb() {
    if [[ ! -x "$ADB" ]]; then
        log_error "ADB not found at: $ADB"
        log_info "Set ANDROID_HOME environment variable or install Android SDK"
        exit 1
    fi
}

# Ensure adb server is running
start_adb_server() {
    $ADB start-server 2>/dev/null || true
}

# Check if device is connected
is_connected() {
    local ip="$1"
    $ADB devices 2>/dev/null | grep -q "$ip.*device"
}

# Get connected port for an IP
get_connected_port() {
    local ip="$1"
    $ADB devices 2>/dev/null | grep "$ip" | cut -d: -f2 | cut -d$'\t' -f1
}

# Try to connect to a specific IP:port
try_connect() {
    local ip="$1"
    local port="$2"
    local result=$($ADB connect "$ip:$port" 2>&1)
    if echo "$result" | grep -q "connected"; then
        return 0
    fi
    return 1
}

# Disconnect from a port
disconnect_port() {
    local ip="$1"
    local port="$2"
    $ADB disconnect "$ip:$port" 2>/dev/null || true
}

# Discover device via mDNS
discover_mdns() {
    local ip="$1"
    local services=$($ADB mdns services 2>/dev/null || echo "")
    local discovered=$(echo "$services" | grep -i "adb.*connect" | grep "$ip" | awk '{print $NF}' | cut -d: -f2 | head -1)
    if [[ -n "$discovered" ]]; then
        echo "$discovered"
        return 0
    fi
    return 1
}

# Scan port range
scan_ports() {
    local ip="$1"
    for port in $(seq $PORT_RANGE_START $PORT_SCAN_STEP $PORT_RANGE_END); do
        if try_connect "$ip" "$port"; then
            echo "$port"
            return 0
        fi
        disconnect_port "$ip" "$port"
    done
    return 1
}

# Connect to a single device
connect_device() {
    local device_name="$1"
    local device_ip=$(get_device_ip "$device_name")

    if [[ -z "$device_ip" ]]; then
        log_error "Device '$device_name' not found in configuration"
        log_info "Add it to $DEVICES_FILE"
        return 1
    fi

    log_info "Connecting to ${BOLD}$device_name${NC}${BLUE} ($device_ip)...${NC}"

    # Check if already connected
    if is_connected "$device_ip"; then
        local port=$(get_connected_port "$device_ip")
        save_port "$device_name" "$port"
        log_success "Already connected to $device_name ($device_ip:$port)"
        return 0
    fi

    # Try saved port first
    local saved_port=$(get_saved_port "$device_name")
    log_info "Trying saved port: $saved_port"
    if try_connect "$device_ip" "$saved_port"; then
        save_port "$device_name" "$saved_port"
        log_success "Connected to $device_name ($device_ip:$saved_port)"
        return 0
    fi

    # Try mDNS discovery
    log_info "Scanning via mDNS..."
    local mdns_port=$(discover_mdns "$device_ip" || echo "")
    if [[ -n "$mdns_port" ]]; then
        log_info "mDNS discovered port: $mdns_port"
        if try_connect "$device_ip" "$mdns_port"; then
            save_port "$device_name" "$mdns_port"
            log_success "Connected to $device_name via mDNS ($device_ip:$mdns_port)"
            return 0
        fi
    fi

    # Fallback: scan port range
    log_info "Scanning port range..."
    local scanned_port=$(scan_ports "$device_ip" || echo "")
    if [[ -n "$scanned_port" ]]; then
        save_port "$device_name" "$scanned_port"
        log_success "Connected to $device_name via scan ($device_ip:$scanned_port)"
        return 0
    fi

    log_error "Could not connect to $device_name ($device_ip)"
    return 1
}

# Reset ADB server (clears stale connections)
reset_adb() {
    log_info "Resetting ADB server (clearing stale connections)..."
    $ADB kill-server 2>/dev/null || true
    sleep 1
    $ADB start-server 2>/dev/null || true
    log_success "ADB server reset"
}

# Show usage
show_usage() {
    echo ""
    echo -e "${CYAN}Usage:${NC} phantom-connect.sh [OPTIONS] [DEVICE]"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  -a, --all        Connect to all configured devices"
    echo "  -r, --reset      Reset ADB server before connecting (clears stale connections)"
    echo "  -l, --list       List configured devices"
    echo "  -h, --help       Show this help"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  phantom-connect.sh              # Connect to default device"
    echo "  phantom-connect.sh oneplus      # Connect to 'oneplus'"
    echo "  phantom-connect.sh -a           # Connect to all devices"
    echo "  phantom-connect.sh -r           # Reset ADB and connect"
    echo "  phantom-connect.sh -l           # List devices"
    echo ""
    echo -e "${BOLD}Configuration:${NC} $DEVICES_FILE"
    echo ""
}

# List devices
list_devices() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              ${BOLD}CONFIGURED DEVICES${NC}${CYAN}                           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local default=$(get_default_device)

    while IFS='=' read -r name ip; do
        [[ -z "$name" ]] && continue
        local port=$(get_saved_port "$name")
        local status="${RED}○ Disconnected${NC}"

        if is_connected "$ip"; then
            status="${GREEN}● Connected${NC}"
        fi

        local default_marker=""
        if [[ "$name" == "$default" ]]; then
            default_marker=" ${YELLOW}(default)${NC}"
        fi

        echo -e "  ${BOLD}$name${NC}$default_marker"
        echo -e "    IP:     $ip"
        echo -e "    Port:   $port"
        echo -e "    Status: $status"
        echo ""
    done < <(get_devices)

    echo -e "Config: ${CYAN}$DEVICES_FILE${NC}"
    echo ""
}

# Main
main() {
    init_devices_file
    check_adb

    local connect_all=false
    local reset_server=false
    local device=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)
                connect_all=true
                shift
                ;;
            -r|--reset)
                reset_server=true
                shift
                ;;
            -l|--list)
                list_devices
                exit 0
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                device="$1"
                shift
                ;;
        esac
    done

    # Reset ADB if requested, otherwise just start server
    if [[ "$reset_server" == true ]]; then
        reset_adb
    else
        start_adb_server
    fi

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       ${BOLD}PHANTOM-DROID CONNECTOR${NC}${CYAN}         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
    echo ""

    if [[ "$connect_all" == true ]]; then
        # Connect to all devices
        local success=0
        local failed=0

        for name in $(get_device_names); do
            if connect_device "$name"; then
                ((success++))
            else
                ((failed++))
            fi
            echo ""
        done

        echo -e "${BOLD}Summary:${NC} ${GREEN}$success connected${NC}, ${RED}$failed failed${NC}"
    else
        # Connect to single device
        if [[ -z "$device" ]]; then
            device=$(get_default_device)
        fi

        if [[ -z "$device" ]]; then
            log_error "No devices configured"
            log_info "Add devices to $DEVICES_FILE"
            exit 1
        fi

        connect_device "$device"
    fi

    echo ""
    echo -e "${BOLD}Connected devices:${NC}"
    $ADB devices -l | tail -n +2 | grep -v "^$" | while read line; do
        echo -e "  ${GREEN}●${NC} $line"
    done
    echo ""
}

main "$@"
