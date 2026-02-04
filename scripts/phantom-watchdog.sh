#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Self-Healing Connection Watchdog
#===============================================================================
#  Monitors devices with exponential backoff, circuit breaker pattern,
#  and automatic process cleanup. Prevents zombie accumulation.
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
LOCKFILE="/tmp/phantom-watchdog.lock"
CONNECT_SCRIPT="$HOME/bin/phantom-connect.sh"
WATCHDOG_LOG="/tmp/phantom-droid-watchdog.log"

# Redirect output to log
exec >> "$WATCHDOG_LOG" 2>&1

#===============================================================================
#  LOCK FILE (Prevent concurrent execution)
#===============================================================================

# Acquire lock or exit
if ! acquire_lock "$LOCKFILE"; then
    exit 0
fi

# Ensure cleanup on exit
cleanup_and_exit() {
    full_cleanup
    release_lock
    # Ensure minimum runtime for launchd
    ensure_min_runtime 10
}
trap cleanup_and_exit EXIT INT TERM

#===============================================================================
#  DEVICE MANAGEMENT
#===============================================================================

get_devices() {
    grep -v '^#' "$DEVICES_FILE" 2>/dev/null | grep -v '^$' | grep '=' || true
}

get_device_names() {
    get_devices | cut -d= -f1
}

get_device_ip() {
    local name="$1"
    grep "^${name}=" "$DEVICES_FILE" 2>/dev/null | cut -d= -f2
}

get_saved_port() {
    local device="$1"
    cat "$CONFIG_DIR/port_$device" 2>/dev/null || echo "40293"
}

#===============================================================================
#  LAST CHECK TRACKING
#===============================================================================

get_last_check_file() {
    echo "$CONFIG_DIR/last_check_$1"
}

should_check_device() {
    local device="$1"
    local last_check_file=$(get_last_check_file "$device")

    # Check circuit breaker first
    if should_skip_device "$device"; then
        return 1
    fi

    # Check backoff timer
    if [[ -f "$last_check_file" ]]; then
        local last_check=$(cat "$last_check_file")
        local now=$(date +%s)
        local elapsed=$((now - last_check))
        local backoff=$(get_backoff "$device")

        if [[ $elapsed -lt $backoff ]]; then
            local remaining=$((backoff - elapsed))
            log_info "$device: Backoff active, ${remaining}s remaining"
            return 1
        fi
    fi

    return 0
}

mark_checked() {
    local device="$1"
    date +%s > "$(get_last_check_file "$device")"
}

#===============================================================================
#  RECONNECTION LOGIC
#===============================================================================

reconnect_device() {
    local device_name="$1"
    local device_ip="$2"

    log_info "$device_name: Attempting reconnection..."

    # Run connection script with timeout
    local result
    if result=$(run_with_timeout 45 "$CONNECT_SCRIPT" "$device_name" 2>&1); then
        log_success "$device_name: Reconnection successful"
        update_backoff "$device_name" "true"
        update_circuit "$device_name" "true"
        return 0
    else
        local exit_code=$?

        if [[ $exit_code -eq $TIMEOUT_EXIT_CODE ]]; then
            log_error "$device_name: Reconnection timed out"
            cleanup_adb_processes_for_ip "$device_ip"
        else
            log_error "$device_name: Reconnection failed (exit: $exit_code)"
        fi

        update_backoff "$device_name" "false"
        update_circuit "$device_name" "false"
        return 1
    fi
}

#===============================================================================
#  MAIN WATCHDOG LOOP
#===============================================================================

main() {
    log_info "=== Watchdog cycle started ($(date)) ==="

    # Ensure ADB server is healthy
    ensure_adb_server

    # Get configured devices
    local devices=$(get_devices)
    if [[ -z "$devices" ]]; then
        log_warn "No devices configured"
        return 0
    fi

    local total=0
    local healthy=0
    local reconnected=0
    local failed=0
    local skipped=0

    while IFS='=' read -r name ip; do
        [[ -z "$name" ]] && continue
        ((total++))

        # Check if device should be processed
        if ! should_check_device "$name"; then
            ((skipped++))
            continue
        fi

        mark_checked "$name"

        local port=$(get_saved_port "$name")

        # Check device health
        if check_device_health "$name" "$ip" "$port"; then
            ((healthy++))
            log_info "$name: Healthy"
        else
            log_warn "$name: Unhealthy, attempting recovery..."

            if reconnect_device "$name" "$ip"; then
                ((reconnected++))
            else
                ((failed++))
            fi
        fi

    done <<< "$devices"

    # Clean up zombies
    cleanup_zombies

    log_info "Summary: $total total, $healthy healthy, $reconnected reconnected, $failed failed, $skipped skipped"
    log_info "=== Watchdog cycle completed ==="
}

main "$@"
