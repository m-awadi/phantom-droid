#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Connection Watchdog (Multi-Device)
#===============================================================================
#  Monitors all configured devices and reconnects if dropped.
#===============================================================================

set -uo pipefail

CONFIG_DIR="$HOME/.phantom-droid"
DEVICES_FILE="$CONFIG_DIR/devices.conf"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
LOG_FILE="/tmp/phantom-droid.log"
CONNECT_SCRIPT="$HOME/bin/phantom-connect.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WATCHDOG: $1" >> "$LOG_FILE"
}

# Get configured devices
get_devices() {
    grep -v '^#' "$DEVICES_FILE" 2>/dev/null | grep -v '^$' | grep '='
}

# Check if device is connected and responsive
check_device() {
    local name="$1"
    local ip="$2"
    local port=$(cat "$CONFIG_DIR/port_$name" 2>/dev/null || echo "40293")

    # Check if device appears in adb devices
    if ! $ADB devices 2>/dev/null | grep -q "$ip.*device"; then
        return 1
    fi

    # Verify device is responsive
    if $ADB -s "$ip:$port" shell echo "phantom-ping" 2>/dev/null | grep -q "phantom-ping"; then
        return 0
    fi

    return 1
}

# Main watchdog logic
main() {
    local connected=0
    local disconnected=0
    local reconnected=0

    while IFS='=' read -r name ip; do
        [[ -z "$name" ]] && continue

        if check_device "$name" "$ip"; then
            log "$name ($ip): Connected ✓"
            ((connected++))
        else
            log "$name ($ip): Disconnected, attempting reconnect..."
            ((disconnected++))

            if [[ -x "$CONNECT_SCRIPT" ]]; then
                if "$CONNECT_SCRIPT" "$name" >> "$LOG_FILE" 2>&1; then
                    log "$name ($ip): Reconnected ✓"
                    ((reconnected++))
                else
                    log "$name ($ip): Reconnect failed ✗"
                fi
            fi
        fi
    done < <(get_devices)

    log "Summary: $connected connected, $disconnected disconnected, $reconnected reconnected"
}

main
