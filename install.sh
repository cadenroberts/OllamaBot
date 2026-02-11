#!/bin/bash
# Quick installer for obot
# Usage: curl -fsSL https://raw.githubusercontent.com/cadenroberts/ollamabot/main/install.sh | bash

set -e

echo "🔧 Installing obot..."
echo ""

# Run the full setup script
curl -fsSL https://raw.githubusercontent.com/cadenroberts/ollamabot/main/scripts/setup.sh | bash
