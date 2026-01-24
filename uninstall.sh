#!/bin/bash
#===============================================================================
#  PHANTOM-DROID: Uninstaller
#===============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║              PHANTOM-DROID UNINSTALLER                        ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

read -p "Are you sure you want to uninstall Phantom-Droid? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}Stopping services...${NC}"

# Unload LaunchAgents
for plist in "$HOME/Library/LaunchAgents"/com.phantom-droid.*.plist; do
    if [[ -f "$plist" ]]; then
        launchctl unload "$plist" 2>/dev/null || true
        rm -f "$plist"
        echo -e "  ${GREEN}✓${NC} Removed $(basename $plist)"
    fi
done

echo ""
echo -e "${BLUE}Removing scripts...${NC}"

# Remove scripts
for script in phantom-connect.sh phantom-disconnect.sh phantom-status.sh phantom-watchdog.sh; do
    if [[ -f "$HOME/bin/$script" ]]; then
        rm -f "$HOME/bin/$script"
        echo -e "  ${GREEN}✓${NC} Removed $script"
    fi
done

echo ""
echo -e "${BLUE}Removing configuration...${NC}"

# Remove config directory
if [[ -d "$HOME/.phantom-droid" ]]; then
    rm -rf "$HOME/.phantom-droid"
    echo -e "  ${GREEN}✓${NC} Removed ~/.phantom-droid"
fi

# Remove log files
rm -f /tmp/phantom-droid*.log /tmp/phantom-droid*.err 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Removed log files"

echo ""
echo -e "${YELLOW}Note:${NC} Shell aliases in ~/.zshrc or ~/.bashrc were not removed."
echo -e "      You can manually remove the PHANTOM-DROID section if desired."
echo ""
echo -e "${GREEN}Phantom-Droid has been uninstalled.${NC}"
echo ""
