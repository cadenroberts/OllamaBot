#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
#  OllamaBot Icon Generator
#  Creates AppIcon.icns from SVG
# ═══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$PROJECT_DIR/Resources"
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"

echo "🎨 Generating OllamaBot App Icon..."

# Create iconset directory
mkdir -p "$ICONSET_DIR"

# Create SVG icon (Tokyo Night themed infinity symbol with neural ring)
cat > "$RESOURCES_DIR/icon.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1a1b26"/>
      <stop offset="100%" style="stop-color:#24283b"/>
    </linearGradient>
    <linearGradient id="ringGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#bb9af7"/>
      <stop offset="50%" style="stop-color:#7dcfff"/>
      <stop offset="100%" style="stop-color:#2ac3de"/>
    </linearGradient>
    <linearGradient id="infinityGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" style="stop-color:#bb9af7"/>
      <stop offset="100%" style="stop-color:#7dcfff"/>
    </linearGradient>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="20" result="coloredBlur"/>
      <feMerge>
        <feMergeNode in="coloredBlur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  
  <!-- Background circle -->
  <circle cx="512" cy="512" r="480" fill="url(#bgGrad)"/>
  
  <!-- Outer ring with gradient -->
  <circle cx="512" cy="512" r="440" fill="none" stroke="url(#ringGrad)" stroke-width="24" opacity="0.8"/>
  
  <!-- Inner glow ring -->
  <circle cx="512" cy="512" r="380" fill="none" stroke="url(#ringGrad)" stroke-width="4" opacity="0.4"/>
  
  <!-- Infinity symbol -->
  <g filter="url(#glow)" transform="translate(512, 512)">
    <path d="M-180,0 
             C-180,-100 -100,-100 0,0 
             C100,100 180,100 180,0 
             C180,-100 100,-100 0,0 
             C-100,100 -180,100 -180,0 Z" 
          fill="none" 
          stroke="url(#infinityGrad)" 
          stroke-width="48" 
          stroke-linecap="round"/>
  </g>
  
  <!-- Neural dots around the ring -->
  <g fill="#7dcfff" opacity="0.6">
    <circle cx="512" cy="72" r="12"/>
    <circle cx="832" cy="212" r="10"/>
    <circle cx="952" cy="512" r="12"/>
    <circle cx="832" cy="812" r="10"/>
    <circle cx="512" cy="952" r="12"/>
    <circle cx="192" cy="812" r="10"/>
    <circle cx="72" cy="512" r="12"/>
    <circle cx="192" cy="212" r="10"/>
  </g>
  
  <!-- Accent highlights -->
  <circle cx="280" cy="280" r="40" fill="#bb9af7" opacity="0.15"/>
  <circle cx="744" cy="744" r="30" fill="#7dcfff" opacity="0.1"/>
</svg>
EOF

echo "✓ SVG created"

# Check if we have the tools to convert
if command -v rsvg-convert &> /dev/null; then
    CONVERT_CMD="rsvg-convert"
elif command -v convert &> /dev/null; then
    CONVERT_CMD="convert"
else
    echo "⚠️  Neither rsvg-convert nor ImageMagick found."
    echo "   Install with: brew install librsvg"
    echo "   Or: brew install imagemagick"
    echo ""
    echo "   For now, creating a placeholder PNG..."
    
    # Use sips to create placeholder (won't work with SVG, but leaving SVG for manual conversion)
    echo "   SVG saved to: $RESOURCES_DIR/icon.svg"
    echo "   Convert manually using an online tool or install librsvg"
    exit 0
fi

# Generate all icon sizes
SIZES="16 32 64 128 256 512 1024"

for SIZE in $SIZES; do
    echo "   Generating ${SIZE}x${SIZE}..."
    if [ "$CONVERT_CMD" = "rsvg-convert" ]; then
        rsvg-convert -w $SIZE -h $SIZE "$RESOURCES_DIR/icon.svg" > "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png"
        if [ $SIZE -le 512 ]; then
            DOUBLE=$((SIZE * 2))
            rsvg-convert -w $DOUBLE -h $DOUBLE "$RESOURCES_DIR/icon.svg" > "$ICONSET_DIR/icon_${SIZE}x${SIZE}@2x.png"
        fi
    else
        convert -background none -resize ${SIZE}x${SIZE} "$RESOURCES_DIR/icon.svg" "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png"
        if [ $SIZE -le 512 ]; then
            DOUBLE=$((SIZE * 2))
            convert -background none -resize ${DOUBLE}x${DOUBLE} "$RESOURCES_DIR/icon.svg" "$ICONSET_DIR/icon_${SIZE}x${SIZE}@2x.png"
        fi
    fi
done

# Rename to Apple's expected format
cd "$ICONSET_DIR"
mv icon_16x16.png icon_16x16.png 2>/dev/null || true
mv icon_32x32.png icon_32x32.png 2>/dev/null || true
mv icon_64x64.png icon_32x32@2x.png 2>/dev/null || true
mv icon_128x128.png icon_128x128.png 2>/dev/null || true
mv icon_256x256.png icon_256x256.png 2>/dev/null || true
mv icon_512x512.png icon_512x512.png 2>/dev/null || true
mv icon_1024x1024.png icon_512x512@2x.png 2>/dev/null || true

# Create icns file
echo "✓ Creating .icns file..."
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

# Cleanup
rm -rf "$ICONSET_DIR"

echo ""
echo "✅ Icon generated: $RESOURCES_DIR/AppIcon.icns"
