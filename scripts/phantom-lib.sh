#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Resilience Library
#===============================================================================
#  Timeout wrappers, health checks, process cleanup, and self-healing patterns.
#  Source this file from other phantom-droid scripts.
#===============================================================================

# Configuration
CONFIG_DIR="$HOME/.phantom-droid"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
LOG_FILE="/tmp/phantom-droid.log"

# Timeout configuration (seconds)
readonly ADB_CONNECT_TIMEOUT=10
readonly ADB_SHELL_TIMEOUT=5
readonly ADB_MDNS_TIMEOUT=8
readonly ADB_DEVICES_TIMEOUT=5
readonly TIMEOUT_EXIT_CODE=124

# Backoff configuration
readonly INITIAL_BACKOFF=5
readonly MAX_BACKOFF=300
readonly BACKOFF_MULTIPLIER=2

# Circuit breaker configuration
readonly CIRCUIT_FAILURE_THRESHOLD=5
readonly CIRCUIT_OPEN_DURATION=600

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Track child processes
declare -a CHILD_PIDS=()

#===============================================================================
#  LOGGING
#===============================================================================

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
    echo -e "$1"
}

log_success() { log "${GREEN}✓ $1${NC}"; }
log_error() { log "${RED}✗ $1${NC}"; }
log_info() { log "${BLUE}→ $1${NC}"; }
log_warn() { log "${YELLOW}⚠ $1${NC}"; }

#===============================================================================
#  TIMEOUT WRAPPERS
#===============================================================================

# Check if GNU timeout is available (prefer gtimeout on macOS)
get_timeout_cmd() {
    if command -v gtimeout &>/dev/null; then
        echo "gtimeout"
    elif command -v timeout &>/dev/null; then
        echo "timeout"
    else
        echo ""
    fi
}

# Run command with timeout using best available method
# Usage: run_with_timeout <seconds> <command> [args...]
# Returns: 0=success, 124=timeout, other=command exit code
run_with_timeout() {
    local timeout_seconds="$1"
    shift

    local timeout_cmd=$(get_timeout_cmd)

    if [[ -n "$timeout_cmd" ]]; then
        # Use GNU timeout with kill signal after 2 extra seconds
        "$timeout_cmd" -k 2 "$timeout_seconds" "$@"
        return $?
    else
        # Fallback: background process with manual timeout
        "$@" &
        local pid=$!
        local elapsed=0

        while [[ $elapsed -lt $timeout_seconds ]]; do
            if ! kill -0 "$pid" 2>/dev/null; then
                wait "$pid"
                return $?
            fi
            sleep 1
            ((elapsed++))
        done

        # Timeout - kill process
        kill -TERM "$pid" 2>/dev/null
        sleep 1
        kill -KILL "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        return $TIMEOUT_EXIT_CODE
    fi
}

# Safe ADB command with timeout
# Usage: adb_timeout <timeout_seconds> [adb_args...]
adb_timeout() {
    local timeout_seconds="$1"
    shift
    run_with_timeout "$timeout_seconds" "$ADB" "$@"
}

# Safe ADB connect with timeout and cleanup
# Usage: safe_adb_connect <ip> <port>
# Returns: 0=success, 1=failed, 124=timeout
safe_adb_connect() {
    local ip="$1"
    local port="$2"
    local result
    local exit_code

    result=$(adb_timeout "$ADB_CONNECT_TIMEOUT" connect "$ip:$port" 2>&1)
    exit_code=$?

    case $exit_code in
        0)
            if echo "$result" | grep -q "connected"; then
                return 0
            elif echo "$result" | grep -q "already connected"; then
                return 0
            else
                return 1
            fi
            ;;
        $TIMEOUT_EXIT_CODE)
            log_warn "Connection to $ip:$port timed out"
            cleanup_hung_connection "$ip" "$port"
            return $TIMEOUT_EXIT_CODE
            ;;
        *)
            return 1
            ;;
    esac
}

# Safe ADB devices listing
safe_adb_devices() {
    adb_timeout "$ADB_DEVICES_TIMEOUT" devices "$@"
}

# Safe ADB shell command
safe_adb_shell() {
    local device="$1"
    shift
    adb_timeout "$ADB_SHELL_TIMEOUT" -s "$device" shell "$@"
}

# Safe mDNS discovery
safe_mdns_discover() {
    local ip="$1"
    local result

    result=$(adb_timeout "$ADB_MDNS_TIMEOUT" mdns services 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        local port=$(echo "$result" | grep -i "adb.*connect" | grep "$ip" | awk '{print $NF}' | cut -d: -f2 | head -1)
        if [[ -n "$port" ]]; then
            echo "$port"
            return 0
        fi
    fi

    return 1
}

#===============================================================================
#  PROCESS CLEANUP
#===============================================================================

# Clean up hung connection
cleanup_hung_connection() {
    local ip="$1"
    local port="$2"

    # Force disconnect (with timeout to prevent hang)
    run_with_timeout 2 "$ADB" disconnect "$ip:$port" 2>/dev/null || true

    # Kill any processes related to this connection
    cleanup_adb_processes_for_ip "$ip"
}

# Find and kill ADB processes related to specific IP
cleanup_adb_processes_for_ip() {
    local ip="$1"

    local hung_pids=$(ps aux 2>/dev/null | grep "[a]db.*$ip" | awk '{print $2}')

    for pid in $hung_pids; do
        local runtime=$(ps -p "$pid" -o etimes= 2>/dev/null | tr -d ' ')

        if [[ -n "$runtime" ]] && [[ $runtime -gt 15 ]]; then
            log_warn "Killing hung ADB process $pid for $ip (runtime: ${runtime}s)"
            kill -TERM "$pid" 2>/dev/null
            sleep 1
            kill -KILL "$pid" 2>/dev/null 2>&1 || true
        fi
    done
}

# Kill all ADB processes
kill_all_adb() {
    log_info "Killing all ADB processes..."
    killall -9 adb 2>/dev/null || true
    sleep 1
}

# Clean up zombie processes
cleanup_zombies() {
    local zombies=$(ps aux 2>/dev/null | awk '$8 ~ /^Z/ && /adb/ {print $2}')

    if [[ -n "$zombies" ]]; then
        log_warn "Found zombie processes, attempting cleanup..."
        for pid in $zombies; do
            wait "$pid" 2>/dev/null || true
        done
    fi
}

# Comprehensive cleanup
full_cleanup() {
    log_info "Performing full cleanup..."

    # Kill tracked children
    for pid in "${CHILD_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null
        fi
    done

    sleep 1

    # Force kill remaining
    for pid in "${CHILD_PIDS[@]}"; do
        kill -KILL "$pid" 2>/dev/null 2>&1 || true
    done

    cleanup_zombies
    CHILD_PIDS=()
}

# Setup cleanup trap
setup_cleanup_trap() {
    trap full_cleanup EXIT INT TERM
    trap 'wait -n 2>/dev/null || true' CHLD
}

#===============================================================================
#  HEALTH CHECKS
#===============================================================================

get_health_file() {
    echo "$CONFIG_DIR/health_$1"
}

# Record health result
record_health() {
    local device="$1"
    local status="$2"
    local health_file=$(get_health_file "$device")

    local timestamp=$(date +%s)
    local failures=0
    local last_success=0

    if [[ -f "$health_file" ]]; then
        source "$health_file" 2>/dev/null || true
    fi

    if [[ "$status" == "ok" ]]; then
        failures=0
        last_success=$timestamp
    else
        ((failures++))
    fi

    cat > "$health_file" << EOF
failures=$failures
last_success=$last_success
last_check=$timestamp
EOF
}

# Check device health
check_device_health() {
    local device_name="$1"
    local device_ip="$2"
    local device_port="$3"

    # Check if device in ADB devices list
    local devices_output
    devices_output=$(safe_adb_devices 2>/dev/null)

    if ! echo "$devices_output" | grep -q "$device_ip.*device"; then
        record_health "$device_name" "fail"
        return 1
    fi

    # Basic echo test
    local ping_result
    ping_result=$(safe_adb_shell "$device_ip:$device_port" "echo ok" 2>/dev/null)

    if [[ "$ping_result" != *"ok"* ]]; then
        record_health "$device_name" "fail"
        return 1
    fi

    record_health "$device_name" "ok"
    return 0
}

#===============================================================================
#  EXPONENTIAL BACKOFF
#===============================================================================

get_backoff_file() {
    echo "$CONFIG_DIR/backoff_$1"
}

get_backoff() {
    local device="$1"
    local backoff_file=$(get_backoff_file "$device")

    if [[ -f "$backoff_file" ]]; then
        cat "$backoff_file"
    else
        echo "$INITIAL_BACKOFF"
    fi
}

update_backoff() {
    local device="$1"
    local success="$2"
    local backoff_file=$(get_backoff_file "$device")

    if [[ "$success" == "true" ]]; then
        echo "$INITIAL_BACKOFF" > "$backoff_file"
    else
        local current=$(get_backoff "$device")
        local new_backoff=$((current * BACKOFF_MULTIPLIER))

        if [[ $new_backoff -gt $MAX_BACKOFF ]]; then
            new_backoff=$MAX_BACKOFF
        fi

        echo "$new_backoff" > "$backoff_file"
        log_info "$device: Backoff increased to ${new_backoff}s"
    fi
}

#===============================================================================
#  CIRCUIT BREAKER
#===============================================================================

get_circuit_file() {
    echo "$CONFIG_DIR/circuit_$1"
}

get_circuit_state() {
    local device="$1"
    local circuit_file=$(get_circuit_file "$device")

    if [[ ! -f "$circuit_file" ]]; then
        echo "closed"
        return
    fi

    local state="closed"
    local failures=0
    local timestamp=0
    source "$circuit_file" 2>/dev/null || true

    local now=$(date +%s)
    local elapsed=$((now - timestamp))

    if [[ "$state" == "open" ]] && [[ $elapsed -gt $CIRCUIT_OPEN_DURATION ]]; then
        echo "half-open"
        return
    fi

    echo "$state"
}

update_circuit() {
    local device="$1"
    local success="$2"
    local circuit_file=$(get_circuit_file "$device")

    local state="closed"
    local failures=0
    local timestamp=$(date +%s)

    if [[ -f "$circuit_file" ]]; then
        source "$circuit_file" 2>/dev/null || true
    fi

    if [[ "$success" == "true" ]]; then
        state="closed"
        failures=0
    else
        ((failures++))

        if [[ $failures -ge $CIRCUIT_FAILURE_THRESHOLD ]]; then
            if [[ "$state" != "open" ]]; then
                log_error "$device: Circuit breaker opened after $failures failures"
            fi
            state="open"
        fi
    fi

    cat > "$circuit_file" << EOF
state="$state"
failures=$failures
timestamp=$timestamp
EOF
}

should_skip_device() {
    local device="$1"

    local circuit=$(get_circuit_state "$device")
    if [[ "$circuit" == "open" ]]; then
        log_warn "$device: Circuit breaker open, skipping"
        return 0
    fi

    return 1
}

#===============================================================================
#  ADB SERVER MANAGEMENT
#===============================================================================

# Ensure clean ADB server
ensure_adb_server() {
    # Check if server is responding
    if ! adb_timeout 3 devices &>/dev/null; then
        log_warn "ADB server not responding, restarting..."
        kill_all_adb
        sleep 2
        "$ADB" start-server 2>/dev/null
        sleep 2
    fi
}

# Full ADB reset
reset_adb_server() {
    log_info "Resetting ADB server..."

    # Kill all processes
    kill_all_adb

    # Clear port
    local port_pid=$(lsof -ti:5037 2>/dev/null)
    if [[ -n "$port_pid" ]]; then
        kill -9 $port_pid 2>/dev/null || true
    fi

    sleep 2

    # Start fresh
    "$ADB" start-server 2>/dev/null
    sleep 2

    log_success "ADB server reset complete"
}

#===============================================================================
#  LIMITED PORT SCANNING
#===============================================================================

# Scan common ports only (prevents hung process accumulation)
scan_ports_limited() {
    local ip="$1"
    local max_attempts="${2:-5}"
    local tested=0

    # Common wireless debugging ports
    local common_ports=(40293 37847 38571 42145 41953 39847 43521 44123 37000 45000)

    for port in "${common_ports[@]}"; do
        if [[ $tested -ge $max_attempts ]]; then
            break
        fi

        ((tested++))

        if safe_adb_connect "$ip" "$port"; then
            echo "$port"
            return 0
        fi
    done

    return 1
}

#===============================================================================
#  LOCK FILE MANAGEMENT (for LaunchAgents)
#===============================================================================

acquire_lock() {
    local lockfile="$1"
    local lockfd="${2:-200}"

    eval "exec $lockfd>$lockfile"

    if ! flock -n "$lockfd"; then
        log_info "Another instance is running, exiting"
        return 1
    fi

    return 0
}

release_lock() {
    local lockfd="${1:-200}"
    flock -u "$lockfd" 2>/dev/null || true
}

# Ensure minimum runtime for launchd (prevents respawn loop)
ensure_min_runtime() {
    local min_seconds="${1:-10}"
    sleep "$min_seconds"
}
