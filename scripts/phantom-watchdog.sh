#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Connection Watchdog
#===============================================================================
#  Monitors the connection and automatically reconnects if dropped.
#  Designed to run as a background service via LaunchAgent.
#===============================================================================

set -uo pipefail

# Configuration
DEVICE_IP="${PHANTOM_DEVICE_IP:-192.168.1.100}"
CONFIG_FILE="$HOME/.phantom-droid/port"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
LOG_FILE="/tmp/phantom-droid.log"
CONNECT_SCRIPT="$HOME/bin/phantom-connect.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WATCHDOG: $1" >> "$LOG_FILE"
}

# Check if device is connected and responsive
check_connection() {
    # First check if device appears in adb devices
    if ! $ADB devices 2>/dev/null | grep -q "$DEVICE_IP.*device"; then
        return 1
    fi

    # Verify device is actually responsive with a simple command
    local port=$(cat "$CONFIG_FILE" 2>/dev/null || echo "40293")
    if $ADB -s "$DEVICE_IP:$port" shell echo "phantom-ping" 2>/dev/null | grep -q "phantom-ping"; then
        return 0
    fi

    return 1
}

# Main watchdog logic
main() {
    if check_connection; then
        log "Device connected and responsive ✓"
    else
        log "Device not connected, attempting reconnect..."
        if [[ -x "$CONNECT_SCRIPT" ]]; then
            "$CONNECT_SCRIPT" >> "$LOG_FILE" 2>&1
        else
            log "ERROR: Connect script not found at $CONNECT_SCRIPT"
        fi
    fi
}

main
