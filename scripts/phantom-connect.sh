#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Resilient Android Wireless Debugging Connection
#===============================================================================
#  Multi-device support with timeout protection, health checks, and self-healing.
#  Uses mDNS discovery, limited port scanning, and persistent configuration.
#===============================================================================

set -uo pipefail

# Get script directory and source library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/phantom-lib.sh" 2>/dev/null || source "$HOME/bin/phantom-lib.sh" 2>/dev/null || {
    echo "Error: phantom-lib.sh not found"
    exit 1
}

# Configuration
DEVICES_FILE="$CONFIG_DIR/devices.conf"
DEFAULT_PORT="40293"
PORT_RANGE_START=37000
PORT_RANGE_END=45000

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

# Setup cleanup on exit
setup_cleanup_trap

#===============================================================================
#  DEVICE CONFIGURATION
#===============================================================================

init_devices_file() {
    if [[ ! -f "$DEVICES_FILE" ]]; then
        cat > "$DEVICES_FILE" << 'EOF'
# Phantom-Droid Device Configuration
# Format: DEVICE_NAME=IP_ADDRESS
# Example:
#   oneplus=192.168.1.100
#   pixel=192.168.1.101
#
# The first device is the default when no device is specified.

oneplus=192.168.1.100
EOF
    fi
}

get_devices() {
    grep -v '^#' "$DEVICES_FILE" 2>/dev/null | grep -v '^$' | grep '=' || true
}

get_device_ip() {
    local name="$1"
    grep "^${name}=" "$DEVICES_FILE" 2>/dev/null | cut -d= -f2
}

get_default_device() {
    get_devices | head -1 | cut -d= -f1
}

get_device_names() {
    get_devices | cut -d= -f1
}

get_saved_port() {
    local device="$1"
    cat "$CONFIG_DIR/port_$device" 2>/dev/null || echo "$DEFAULT_PORT"
}

save_port() {
    local device="$1"
    local port="$2"
    echo "$port" > "$CONFIG_DIR/port_$device"
}

#===============================================================================
#  CONNECTION CHECKS
#===============================================================================

is_connected() {
    local ip="$1"
    local devices_output

    devices_output=$(safe_adb_devices 2>/dev/null) || return 1
    echo "$devices_output" | grep -q "$ip.*device"
}

get_connected_port() {
    local ip="$1"
    safe_adb_devices 2>/dev/null | grep "$ip" | cut -d: -f2 | cut -d$'\t' -f1
}

disconnect_port() {
    local ip="$1"
    local port="$2"
    run_with_timeout 3 "$ADB" disconnect "$ip:$port" 2>/dev/null || true
}

#===============================================================================
#  CONNECTION LOGIC
#===============================================================================

connect_device() {
    local device_name="$1"
    local device_ip=$(get_device_ip "$device_name")

    if [[ -z "$device_ip" ]]; then
        log_error "Device '$device_name' not found in configuration"
        log_info "Add it to $DEVICES_FILE"
        return 1
    fi

    # Check circuit breaker
    if should_skip_device "$device_name"; then
        return 1
    fi

    log_info "Connecting to ${BOLD}$device_name${NC}${BLUE} ($device_ip)...${NC}"

    # Check if already connected
    if is_connected "$device_ip"; then
        local port=$(get_connected_port "$device_ip")
        save_port "$device_name" "$port"
        log_success "Already connected to $device_name ($device_ip:$port)"
        update_backoff "$device_name" "true"
        update_circuit "$device_name" "true"
        return 0
    fi

    # Strategy 1: Try saved port
    local saved_port=$(get_saved_port "$device_name")
    log_info "Trying saved port: $saved_port"
    if safe_adb_connect "$device_ip" "$saved_port"; then
        save_port "$device_name" "$saved_port"
        log_success "Connected to $device_name ($device_ip:$saved_port)"
        update_backoff "$device_name" "true"
        update_circuit "$device_name" "true"
        return 0
    fi

    # Strategy 2: Try mDNS discovery
    log_info "Scanning via mDNS..."
    local mdns_port=$(safe_mdns_discover "$device_ip")
    if [[ -n "$mdns_port" ]]; then
        log_info "mDNS discovered port: $mdns_port"
        if safe_adb_connect "$device_ip" "$mdns_port"; then
            save_port "$device_name" "$mdns_port"
            log_success "Connected to $device_name via mDNS ($device_ip:$mdns_port)"
            update_backoff "$device_name" "true"
            update_circuit "$device_name" "true"
            return 0
        fi
    fi

    # Strategy 3: Limited port scan (prevents hung process accumulation)
    log_info "Scanning common ports (limited)..."
    local scanned_port=$(scan_ports_limited "$device_ip" 5)
    if [[ -n "$scanned_port" ]]; then
        save_port "$device_name" "$scanned_port"
        log_success "Connected to $device_name via scan ($device_ip:$scanned_port)"
        update_backoff "$device_name" "true"
        update_circuit "$device_name" "true"
        return 0
    fi

    # All strategies failed
    log_error "Could not connect to $device_name ($device_ip)"
    log_info "Troubleshooting:"
    log_info "  1. Verify wireless debugging is enabled on phone"
    log_info "  2. Check phone is on same network"
    log_info "  3. Try: phantom -r (reset ADB server)"
    log_info "  4. Run: ppair (pairing wizard)"

    update_backoff "$device_name" "false"
    update_circuit "$device_name" "false"
    return 1
}

#===============================================================================
#  DISPLAY FUNCTIONS
#===============================================================================

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
        local circuit=$(get_circuit_state "$name")

        if is_connected "$ip"; then
            status="${GREEN}● Connected${NC}"
        elif [[ "$circuit" == "open" ]]; then
            status="${YELLOW}◌ Circuit Open${NC}"
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

#===============================================================================
#  MAIN
#===============================================================================

main() {
    init_devices_file

    # Validate ADB exists
    if [[ ! -x "$ADB" ]]; then
        log_error "ADB not found at: $ADB"
        log_info "Set ANDROID_HOME environment variable or install Android SDK"
        exit 1
    fi

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

    # Reset or ensure ADB server
    if [[ "$reset_server" == true ]]; then
        reset_adb_server
    else
        ensure_adb_server
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
    safe_adb_devices -l 2>/dev/null | tail -n +2 | grep -v "^$" | while read line; do
        echo -e "  ${GREEN}●${NC} $line"
    done
    echo ""
}

main "$@"
