#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
#  OllamaBot Update Script
#  Pulls latest changes, preserves session state, rebuilds, and relaunches
#  
#  Usage: ./scripts/update.sh
#  
#  Session state (open files, project folder) is automatically saved when
#  the app quits and restored on next launch.
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="OllamaBot"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              🔄 OllamaBot Update                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Gracefully quit running app (triggers session save)
echo -e "${YELLOW}[1/5] Saving session and quitting OllamaBot...${NC}"
# Try graceful quit first (allows app to save session)
osascript -e 'tell application "OllamaBot" to quit' 2>/dev/null || true
sleep 1
# Force quit if still running
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5
echo "  ✓ App closed"

# Step 2: Check for uncommitted changes
echo -e "${YELLOW}[2/5] Checking git status...${NC}"
cd "$PROJECT_DIR"
if [[ -n $(git status --porcelain) ]]; then
    echo -e "${RED}  ⚠ You have uncommitted changes!${NC}"
    echo "  Stashing changes before pull..."
    git stash push -m "Auto-stash before update $(date '+%Y-%m-%d %H:%M:%S')"
    STASHED=true
else
    echo "  ✓ Working directory clean"
    STASHED=false
fi

# Step 3: Pull latest changes
echo -e "${YELLOW}[3/5] Pulling latest changes...${NC}"
git fetch origin
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git pull origin "$CURRENT_BRANCH"
echo "  ✓ Updated to latest"

# Restore stashed changes if any
if [ "$STASHED" = true ]; then
    echo "  Restoring stashed changes..."
    git stash pop || echo -e "${YELLOW}  ⚠ Could not auto-restore stash - use 'git stash pop' manually${NC}"
fi

# Step 4: Build with optimized script (keeps SwiftPM caches)
echo -e "${YELLOW}[4/5] Building...${NC}"
"$SCRIPT_DIR/build-app.sh"

# Step 5: Launch the app
echo -e "${YELLOW}[5/5] Launching OllamaBot...${NC}"
open "$APP_BUNDLE"

# Done
echo -e "\n${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              ✅ Update Complete!                              ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  Your session (open files, project) will be restored         ║"
echo "║  automatically when the app launches.                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Show what changed
echo -e "${BOLD}Recent changes:${NC}"
git log --oneline -5
echo ""
