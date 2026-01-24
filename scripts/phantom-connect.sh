#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Resilient Android Wireless Debugging Connection
#===============================================================================
#  Auto-discovers and connects to your Android device even when port changes.
#  Uses mDNS discovery, port scanning, and persistent configuration.
#===============================================================================

set -euo pipefail

# Configuration
DEVICE_IP="${PHANTOM_DEVICE_IP:-192.168.1.100}"
CONFIG_FILE="$HOME/.phantom-droid/port"
CONFIG_DIR="$HOME/.phantom-droid"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
LOG_FILE="/tmp/phantom-droid.log"
DEFAULT_PORT="40293"
PORT_RANGE_START=37000
PORT_RANGE_END=45000
PORT_SCAN_STEP=100

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
    echo -e "$1"
}

log_success() { log "${GREEN}✓ $1${NC}"; }
log_error() { log "${RED}✗ $1${NC}"; }
log_info() { log "${BLUE}→ $1${NC}"; }
log_warn() { log "${YELLOW}⚠ $1${NC}"; }

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

# Load last known working port
load_saved_port() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        echo "$DEFAULT_PORT"
    fi
}

# Save working port
save_port() {
    echo "$1" > "$CONFIG_FILE"
}

# Check if already connected
is_connected() {
    $ADB devices 2>/dev/null | grep -q "$DEVICE_IP.*device"
}

# Get currently connected port
get_connected_port() {
    $ADB devices 2>/dev/null | grep "$DEVICE_IP" | cut -d: -f2 | cut -d$'\t' -f1
}

# Try to connect to a specific port
try_connect() {
    local port=$1
    local result=$($ADB connect "$DEVICE_IP:$port" 2>&1)
    if echo "$result" | grep -q "connected"; then
        return 0
    fi
    return 1
}

# Disconnect from a port (silently)
disconnect_port() {
    $ADB disconnect "$DEVICE_IP:$1" 2>/dev/null || true
}

# Discover device via mDNS
discover_mdns() {
    log_info "Scanning via mDNS..."
    local services=$($ADB mdns services 2>/dev/null || echo "")

    # Look for adb-tls-connect service
    local discovered=$(echo "$services" | grep -i "adb.*connect" | grep "$DEVICE_IP" | awk '{print $NF}' | cut -d: -f2 | head -1)

    if [[ -n "$discovered" ]]; then
        echo "$discovered"
        return 0
    fi
    return 1
}

# Scan port range
scan_ports() {
    log_info "Scanning port range $PORT_RANGE_START-$PORT_RANGE_END..."
    for port in $(seq $PORT_RANGE_START $PORT_SCAN_STEP $PORT_RANGE_END); do
        if try_connect "$port"; then
            echo "$port"
            return 0
        fi
        disconnect_port "$port"
    done
    return 1
}

# Main connection logic
connect() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       PHANTOM-DROID CONNECTOR         ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
    echo ""

    check_adb
    start_adb_server

    log_info "Target device: $DEVICE_IP"

    # Check if already connected
    if is_connected; then
        local port=$(get_connected_port)
        save_port "$port"
        log_success "Already connected to $DEVICE_IP:$port"
        return 0
    fi

    # Try last known port
    local saved_port=$(load_saved_port)
    log_info "Trying saved port: $saved_port"
    if try_connect "$saved_port"; then
        save_port "$saved_port"
        log_success "Connected using saved port: $saved_port"
        return 0
    fi

    # Try mDNS discovery
    local mdns_port=$(discover_mdns || echo "")
    if [[ -n "$mdns_port" ]]; then
        log_info "mDNS discovered port: $mdns_port"
        if try_connect "$mdns_port"; then
            save_port "$mdns_port"
            log_success "Connected via mDNS: $DEVICE_IP:$mdns_port"
            return 0
        fi
    fi

    # Fallback: scan port range
    local scanned_port=$(scan_ports || echo "")
    if [[ -n "$scanned_port" ]]; then
        save_port "$scanned_port"
        log_success "Connected via port scan: $DEVICE_IP:$scanned_port"
        return 0
    fi

    log_error "Could not connect to device"
    log_warn "Make sure:"
    log_warn "  1. Phone is on the same Wi-Fi network"
    log_warn "  2. Wireless debugging is enabled on phone"
    log_warn "  3. IP address is correct: $DEVICE_IP"
    return 1
}

# Run main function
connect
