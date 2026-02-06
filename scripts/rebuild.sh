#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
#  OllamaBot Rebuild Script
#  Fast rebuilds with optional deep clean
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

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

NO_OPEN=false
PASSTHRU_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-open)
            NO_OPEN=true
            ;;
        *)
            PASSTHRU_ARGS+=("$1")
            ;;
    esac
    shift
done

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           🔄 OllamaBot Rebuild & Run                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Kill any running instances
echo -e "${YELLOW}[1/3] Closing any running OllamaBot instances...${NC}"
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5

# Step 2: Build (fast by default; use --deep-clean for full cache purge)
echo -e "${YELLOW}[2/3] Building...${NC}"
if [ "${#PASSTHRU_ARGS[@]}" -gt 0 ]; then
    "$SCRIPT_DIR/build-app.sh" "${PASSTHRU_ARGS[@]}"
else
    "$SCRIPT_DIR/build-app.sh"
fi

# Step 3: Launch the app
if [ "$NO_OPEN" = false ]; then
    echo -e "${YELLOW}[3/3] Launching OllamaBot...${NC}"
    open "$APP_BUNDLE"
fi

# Done
echo -e "\n${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              ✅ OllamaBot is now running!                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Show build timestamp
BUILD_TIME=$(date "+%Y-%m-%d %H:%M:%S")
echo -e "Built at: ${BOLD}$BUILD_TIME${NC}"
echo ""
