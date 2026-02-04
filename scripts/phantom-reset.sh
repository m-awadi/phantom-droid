#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Emergency Reset & Cleanup
#===============================================================================
#  Fixes stuck ADB processes, clears conflicts, and reinitializes the system.
#  Run this when ADB is hung or not responding.
#===============================================================================

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
CONFIG_DIR="$HOME/.phantom-droid"

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           ${BOLD}PHANTOM-DROID EMERGENCY RESET${NC}${CYAN}                    ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

#===============================================================================
#  STEP 1: Stop all LaunchAgents
#===============================================================================

echo -e "${BLUE}→ Step 1: Stopping LaunchAgents...${NC}"

# Unload phantom-droid agents
launchctl unload ~/Library/LaunchAgents/com.phantom-droid.watchdog.plist 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} Stopped phantom-droid watchdog" || \
    echo -e "  ${YELLOW}○${NC} Watchdog not loaded"

launchctl unload ~/Library/LaunchAgents/com.phantom-droid.wake.plist 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} Stopped phantom-droid wake handler" || \
    echo -e "  ${YELLOW}○${NC} Wake handler not loaded"

# Unload old conflicting agents
launchctl unload ~/Library/LaunchAgents/com.android.adb-connect.plist 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} Stopped old adb-connect agent" || true

launchctl unload ~/Library/LaunchAgents/com.android.adb-wake.plist 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} Stopped old adb-wake agent" || true

echo ""

#===============================================================================
#  STEP 2: Kill all ADB processes
#===============================================================================

echo -e "${BLUE}→ Step 2: Killing all ADB processes...${NC}"

# Count before
ADB_COUNT=$(pgrep -c adb 2>/dev/null || echo "0")
echo -e "  Found $ADB_COUNT ADB processes"

# Kill all
killall -9 adb 2>/dev/null || true
pkill -9 -f "adb" 2>/dev/null || true

sleep 2

# Verify
ADB_AFTER=$(pgrep -c adb 2>/dev/null || echo "0")
if [[ "$ADB_AFTER" == "0" ]]; then
    echo -e "  ${GREEN}✓${NC} All ADB processes terminated"
else
    echo -e "  ${YELLOW}⚠${NC} $ADB_AFTER processes still running (may be restarting)"
fi

echo ""

#===============================================================================
#  STEP 3: Clear port conflicts
#===============================================================================

echo -e "${BLUE}→ Step 3: Clearing port 5037 conflicts...${NC}"

PORT_PID=$(lsof -ti:5037 2>/dev/null || echo "")
if [[ -n "$PORT_PID" ]]; then
    echo -e "  Found process $PORT_PID using port 5037"
    kill -9 $PORT_PID 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} Killed conflicting process" || \
        echo -e "  ${YELLOW}⚠${NC} Could not kill process"
else
    echo -e "  ${GREEN}✓${NC} Port 5037 is clear"
fi

echo ""

#===============================================================================
#  STEP 4: Clear circuit breaker and backoff states
#===============================================================================

echo -e "${BLUE}→ Step 4: Clearing recovery states...${NC}"

# Clear circuit breakers
rm -f "$CONFIG_DIR"/circuit_* 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} Cleared circuit breaker states" || true

# Clear backoff timers
rm -f "$CONFIG_DIR"/backoff_* 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} Cleared backoff timers" || true

# Clear last check timestamps
rm -f "$CONFIG_DIR"/last_check_* 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} Cleared last check timestamps" || true

# Clear health states
rm -f "$CONFIG_DIR"/health_* 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} Cleared health states" || true

# Clear lock files
rm -f /tmp/phantom-*.lock 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} Cleared lock files" || true

echo ""

#===============================================================================
#  STEP 5: Remove old conflicting LaunchAgents
#===============================================================================

echo -e "${BLUE}→ Step 5: Removing old conflicting agents...${NC}"

if [[ -f ~/Library/LaunchAgents/com.android.adb-connect.plist ]]; then
    rm -f ~/Library/LaunchAgents/com.android.adb-connect.plist
    echo -e "  ${GREEN}✓${NC} Removed com.android.adb-connect.plist"
fi

if [[ -f ~/Library/LaunchAgents/com.android.adb-wake.plist ]]; then
    rm -f ~/Library/LaunchAgents/com.android.adb-wake.plist
    echo -e "  ${GREEN}✓${NC} Removed com.android.adb-wake.plist"
fi

# Kill any remaining android-watchdog script
pkill -f "android-watchdog" 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} Killed old android-watchdog script" || true

echo ""

#===============================================================================
#  STEP 6: Start fresh ADB server
#===============================================================================

echo -e "${BLUE}→ Step 6: Starting fresh ADB server...${NC}"

sleep 2

if "$ADB" start-server 2>&1 | grep -q "daemon started"; then
    echo -e "  ${GREEN}✓${NC} ADB server started successfully"
else
    # Check if already running
    if "$ADB" devices &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} ADB server is running"
    else
        echo -e "  ${RED}✗${NC} Failed to start ADB server"
        echo -e "  ${YELLOW}Try:${NC} Restart your Mac or reinstall Android SDK"
    fi
fi

echo ""

#===============================================================================
#  STEP 7: Reload phantom-droid LaunchAgents
#===============================================================================

echo -e "${BLUE}→ Step 7: Reloading phantom-droid agents...${NC}"

if [[ -f ~/Library/LaunchAgents/com.phantom-droid.watchdog.plist ]]; then
    launchctl load ~/Library/LaunchAgents/com.phantom-droid.watchdog.plist 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} Loaded watchdog agent" || \
        echo -e "  ${YELLOW}○${NC} Watchdog already loaded"
fi

if [[ -f ~/Library/LaunchAgents/com.phantom-droid.wake.plist ]]; then
    launchctl load ~/Library/LaunchAgents/com.phantom-droid.wake.plist 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} Loaded wake handler" || \
        echo -e "  ${YELLOW}○${NC} Wake handler already loaded"
fi

echo ""

#===============================================================================
#  STEP 8: Test ADB
#===============================================================================

echo -e "${BLUE}→ Step 8: Testing ADB...${NC}"

# Test with timeout
if command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
elif command -v timeout &>/dev/null; then
    TIMEOUT_CMD="timeout"
else
    TIMEOUT_CMD=""
fi

if [[ -n "$TIMEOUT_CMD" ]]; then
    DEVICES=$($TIMEOUT_CMD 5 "$ADB" devices 2>&1)
else
    DEVICES=$("$ADB" devices 2>&1)
fi

if echo "$DEVICES" | grep -q "List of devices"; then
    echo -e "  ${GREEN}✓${NC} ADB is responding"
    echo ""
    echo -e "${BOLD}Connected devices:${NC}"
    echo "$DEVICES" | tail -n +2 | grep -v "^$" | while read line; do
        if [[ -n "$line" ]]; then
            echo -e "  ${GREEN}●${NC} $line"
        fi
    done
else
    echo -e "  ${RED}✗${NC} ADB not responding"
    echo -e "  ${YELLOW}Output:${NC} $DEVICES"
fi

echo ""

#===============================================================================
#  SUMMARY
#===============================================================================

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Reset Complete!${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Connect your device: ${CYAN}phantom${NC}"
echo -e "  2. Check status: ${CYAN}pstatus${NC}"
echo -e "  3. If still stuck: ${CYAN}phantom -r${NC} (reset + connect)"
echo ""
echo -e "If USB device not detected:"
echo -e "  1. Unplug and replug the USB cable"
echo -e "  2. Check for USB authorization prompt on phone"
echo -e "  3. Run: ${CYAN}ppair${NC} to re-pair the device"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
