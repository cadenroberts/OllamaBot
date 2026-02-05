#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
#  OllamaBot Build Script
#  Creates a proper macOS .app bundle (fast rebuild optimized)
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

CONFIG_DIR="$HOME/.config/ollamabot"
BUILD_CONFIG_FILE="$CONFIG_DIR/build.conf"

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              🤖 OllamaBot Build Script                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Defaults
RELEASE=false
CLEAN=false
DEEP_CLEAN=false
OPEN_APP=false
SIGN_APP=true
AUTO_TUNE=false

BUILD_JOBS=""
DISABLE_SANDBOX=""
DISABLE_INDEX_STORE=""
BUILD_SYSTEM=""

# Load saved build config (if present)
if [ -f "$BUILD_CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$BUILD_CONFIG_FILE"
fi

# Map saved config variables (if set)
if [ -n "${BUILD_DISABLE_SANDBOX:-}" ] && [ -z "${DISABLE_SANDBOX:-}" ]; then
    DISABLE_SANDBOX="$BUILD_DISABLE_SANDBOX"
fi
if [ -n "${BUILD_DISABLE_INDEX_STORE:-}" ] && [ -z "${DISABLE_INDEX_STORE:-}" ]; then
    DISABLE_INDEX_STORE="$BUILD_DISABLE_INDEX_STORE"
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --release|-r)
            RELEASE=true
            ;;
        --clean|-c)
            CLEAN=true
            ;;
        --deep-clean|--pristine)
            DEEP_CLEAN=true
            ;;
        --open|--launch)
            OPEN_APP=true
            ;;
        --no-sign)
            SIGN_APP=false
            ;;
        --sign)
            SIGN_APP=true
            ;;
        --jobs)
            BUILD_JOBS="$2"
            shift
            ;;
        --disable-sandbox)
            DISABLE_SANDBOX=1
            ;;
        --sandbox)
            DISABLE_SANDBOX=0
            ;;
        --disable-index-store)
            DISABLE_INDEX_STORE=1
            ;;
        --enable-index-store)
            DISABLE_INDEX_STORE=0
            ;;
        --build-system)
            BUILD_SYSTEM="$2"
            shift
            ;;
        --auto|--benchmark)
            AUTO_TUNE=true
            ;;
        *)
            ;;
    esac
    shift
done

# Auto-tune if requested and no config exists
if [ "$AUTO_TUNE" = true ] && [ ! -f "$BUILD_CONFIG_FILE" ]; then
    echo -e "${YELLOW}No build config found. Running benchmark...${NC}"
    python3 "$SCRIPT_DIR/benchmark-build.py" --save
    if [ -f "$BUILD_CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$BUILD_CONFIG_FILE"
    fi
fi

# Heuristic defaults if config/flags did not set values
PHYSICAL_CORES=$(sysctl -n hw.physicalcpu 2>/dev/null || echo 1)
PERF_CORES=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || echo "")

if [ -z "${BUILD_JOBS:-}" ]; then
    if [ -n "$PERF_CORES" ] && [ "$PERF_CORES" -gt 0 ]; then
        BUILD_JOBS="$PERF_CORES"
    else
        BUILD_JOBS="$PHYSICAL_CORES"
    fi
fi

if [ -z "${DISABLE_SANDBOX:-}" ]; then
    DISABLE_SANDBOX=0
fi

if [ -z "${DISABLE_INDEX_STORE:-}" ]; then
    DISABLE_INDEX_STORE=0
fi

if [ -z "${BUILD_SYSTEM:-}" ]; then
    BUILD_SYSTEM="native"
fi

# Validate jobs
if ! [[ "$BUILD_JOBS" =~ ^[0-9]+$ ]] || [ "$BUILD_JOBS" -lt 1 ]; then
    echo -e "${YELLOW}Invalid jobs count '${BUILD_JOBS}'. Falling back to ${PHYSICAL_CORES}.${NC}"
    BUILD_JOBS="$PHYSICAL_CORES"
fi

SANDBOX_LABEL="on"
if [ "$DISABLE_SANDBOX" = "1" ]; then SANDBOX_LABEL="off"; fi
INDEX_LABEL="auto"
if [ "$DISABLE_INDEX_STORE" = "1" ]; then INDEX_LABEL="off"; fi

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}Cleaning app bundle...${NC}"
    rm -rf "$APP_BUNDLE"
    rm -rf "$BUILD_DIR"
fi

if [ "$DEEP_CLEAN" = true ]; then
    echo -e "${YELLOW}Deep cleaning build caches...${NC}"
    rm -rf "$BUILD_DIR"
    rm -rf "$PROJECT_DIR/.build"
    rm -rf "$PROJECT_DIR/.swiftpm"
    rm -rf ~/Library/Developer/Xcode/DerivedData/*OllamaBot* 2>/dev/null || true
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Build configuration
if [ "$RELEASE" = true ]; then
    echo -e "${BOLD}Building for RELEASE...${NC}"
    BUILD_CONFIG="release"
else
    echo -e "${BOLD}Building for DEBUG...${NC}"
    BUILD_CONFIG="debug"
fi

# Build the executable
echo -e "\n${BOLD}📦 Compiling Swift code...${NC}"
echo -e "  Config: ${BUILD_CONFIG} | Jobs: ${BUILD_JOBS} | Sandbox: ${SANDBOX_LABEL} | Index: ${INDEX_LABEL} | Build system: ${BUILD_SYSTEM}"
cd "$PROJECT_DIR"

SWIFT_ARGS=(build --configuration "$BUILD_CONFIG" --product "$APP_NAME" --jobs "$BUILD_JOBS")
if [ "$DISABLE_SANDBOX" = "1" ]; then SWIFT_ARGS+=(--disable-sandbox); fi
if [ "$DISABLE_INDEX_STORE" = "1" ]; then SWIFT_ARGS+=(--disable-index-store); fi
if [ -n "$BUILD_SYSTEM" ] && [ "$BUILD_SYSTEM" != "native" ]; then
    SWIFT_ARGS+=(--build-system "$BUILD_SYSTEM")
fi

swift "${SWIFT_ARGS[@]}"

# Get the built executable path
SHOW_BIN_ARGS=(build --show-bin-path --configuration "$BUILD_CONFIG")
if [ -n "$BUILD_SYSTEM" ] && [ "$BUILD_SYSTEM" != "native" ]; then
    SHOW_BIN_ARGS+=(--build-system "$BUILD_SYSTEM")
fi
BIN_PATH=$(swift "${SHOW_BIN_ARGS[@]}")
EXECUTABLE="$BIN_PATH/$APP_NAME"

if [ ! -f "$EXECUTABLE" ]; then
    echo -e "${RED}Error: Executable not found at $EXECUTABLE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Compilation successful${NC}"

# Create app bundle structure
echo -e "\n${BOLD}📁 Creating app bundle...${NC}"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
echo "  ✓ Copied executable"

# Copy Info.plist
if [ -f "$PROJECT_DIR/Resources/Info.plist" ]; then
    cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"
    echo "  ✓ Copied Info.plist"
else
    echo -e "${YELLOW}  ⚠ Info.plist not found, creating default...${NC}"
    cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.cadenroberts.ollamabot</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Caden Roberts</string>
</dict>
</plist>
EOF
fi

# Copy icon if it exists
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
    echo "  ✓ Copied AppIcon.icns"
else
    echo -e "${YELLOW}  ⚠ AppIcon.icns not found. Run scripts/generate-icon.sh first.${NC}"
fi

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"
echo "  ✓ Created PkgInfo"

# Set executable permissions
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Touch the app to update Finder
touch "$APP_BUNDLE"

# Ad-hoc code signing to prevent caching issues
if [ "$SIGN_APP" = true ]; then
    codesign --force --deep --sign - "$APP_BUNDLE"
    echo "  ✓ Code signed"
else
    echo -e "${YELLOW}  ⚠ Skipped code signing${NC}"
fi

echo -e "\n${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Build Complete!                         ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  App Bundle: build/OllamaBot.app                              ║"
echo "║  Config:     $BUILD_CONFIG                                         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Show app size
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo -e "📊 App size: ${BOLD}$APP_SIZE${NC}"

# Instructions
echo -e "\n${BOLD}To run:${NC}"
echo "  open $APP_BUNDLE"
echo ""
echo -e "${BOLD}To install:${NC}"
echo "  cp -r $APP_BUNDLE /Applications/"
echo ""

# Optionally open the build folder
if [ "$RELEASE" = true ]; then
    echo -e "${CYAN}Opening build folder...${NC}"
    open "$BUILD_DIR"
fi

if [ "$OPEN_APP" = true ]; then
    echo -e "${CYAN}Launching app...${NC}"
    open "$APP_BUNDLE"
fi
