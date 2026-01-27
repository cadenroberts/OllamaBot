#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
#  OllamaBot Build Script
#  Creates a proper macOS .app bundle
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
echo "║              🤖 OllamaBot Build Script                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Parse arguments
RELEASE=false
CLEAN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --release|-r)
            RELEASE=true
            shift
            ;;
        --clean|-c)
            CLEAN=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}Cleaning build directory...${NC}"
    rm -rf "$BUILD_DIR"
    rm -rf "$PROJECT_DIR/.build"
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Build configuration
if [ "$RELEASE" = true ]; then
    echo -e "${BOLD}Building for RELEASE...${NC}"
    BUILD_CONFIG="release"
    SWIFT_FLAGS="-c release"
else
    echo -e "${BOLD}Building for DEBUG...${NC}"
    BUILD_CONFIG="debug"
    SWIFT_FLAGS=""
fi

# Build the executable
echo -e "\n${BOLD}📦 Compiling Swift code...${NC}"
cd "$PROJECT_DIR"
swift build $SWIFT_FLAGS

# Get the built executable path
EXECUTABLE="$PROJECT_DIR/.build/$BUILD_CONFIG/$APP_NAME"

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
