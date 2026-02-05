#!/bin/bash
#
# 🔧 obot Setup Script
# Installs Go, Ollama, downloads coder models, and builds obot
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/croberts/obot/main/scripts/setup.sh | bash
#   # or
#   ./scripts/setup.sh
#

set -eo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

GO_VERSION="1.22.0"
OBOT_REPO="https://github.com/croberts/obot.git"
INSTALL_DIR="/usr/local/bin"

# Model tiers based on RAM
MINIMAL_MODEL="deepseek-coder:1.3b"    # 8GB RAM
COMPACT_MODEL="deepseek-coder:6.7b"    # 16GB RAM
BALANCED_MODEL="qwen2.5-coder:14b"     # 24GB RAM
PERFORMANCE_MODEL="qwen2.5-coder:32b"  # 32GB RAM
ADVANCED_MODEL="deepseek-coder:33b"    # 64GB+ RAM

# ═══════════════════════════════════════════════════════════════════════════════
# COLORS
# ═══════════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_color() {
    printf "${1}${2}${NC}\n"
}

print_step() {
    echo ""
    print_color "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_color "$CYAN$BOLD" "  $1"
    print_color "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_success() {
    print_color "$GREEN" "✓ $1"
}

print_warning() {
    print_color "$YELLOW" "⚠ $1"
}

print_error() {
    print_color "$RED" "✗ $1"
}

print_info() {
    print_color "$GRAY" "  $1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SYSTEM DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

detect_os() {
    case "$(uname -s)" in
        Darwin*)  echo "darwin" ;;
        Linux*)   echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)        echo "unknown" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        armv7l)        echo "armv6l" ;;
        *)             echo "unknown" ;;
    esac
}

detect_ram_gb() {
    local os=$(detect_os)
    
    if [ "$os" = "darwin" ]; then
        # macOS: use sysctl
        local bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
        echo $((bytes / 1024 / 1024 / 1024))
    elif [ "$os" = "linux" ]; then
        # Linux: parse /proc/meminfo
        local kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
        echo $((kb / 1024 / 1024))
    else
        echo "16" # Default fallback
    fi
}

select_tier() {
    local ram=$1
    
    if [ "$ram" -ge 64 ]; then
        echo "advanced"
    elif [ "$ram" -ge 32 ]; then
        echo "performance"
    elif [ "$ram" -ge 24 ]; then
        echo "balanced"
    elif [ "$ram" -ge 16 ]; then
        echo "compact"
    else
        echo "minimal"
    fi
}

get_model_for_tier() {
    local tier=$1
    
    case "$tier" in
        minimal)     echo "$MINIMAL_MODEL" ;;
        compact)     echo "$COMPACT_MODEL" ;;
        balanced)    echo "$BALANCED_MODEL" ;;
        performance) echo "$PERFORMANCE_MODEL" ;;
        advanced)    echo "$ADVANCED_MODEL" ;;
        *)           echo "$COMPACT_MODEL" ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# GO INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════

check_go() {
    if command -v go &> /dev/null; then
        local version=$(go version | grep -oE 'go[0-9]+\.[0-9]+' | head -1)
        print_success "Go already installed: $version"
        return 0
    fi
    return 1
}

install_go() {
    local os=$(detect_os)
    local arch=$(detect_arch)
    
    if [ "$os" = "unknown" ] || [ "$arch" = "unknown" ]; then
        print_error "Unsupported platform: $os/$arch"
        print_info "Please install Go manually from https://golang.org/dl/"
        exit 1
    fi
    
    print_step "Installing Go $GO_VERSION"
    
    local go_tar="go${GO_VERSION}.${os}-${arch}.tar.gz"
    local go_url="https://golang.org/dl/${go_tar}"
    local tmp_dir=$(mktemp -d)
    
    print_info "Downloading from $go_url..."
    
    # Download Go
    if command -v curl &> /dev/null; then
        curl -fsSL "$go_url" -o "$tmp_dir/$go_tar"
    elif command -v wget &> /dev/null; then
        wget -q "$go_url" -O "$tmp_dir/$go_tar"
    else
        print_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    # Extract Go
    print_info "Extracting Go..."
    
    if [ "$os" = "darwin" ] || [ "$os" = "linux" ]; then
        # Remove existing Go installation
        if [ -d "/usr/local/go" ]; then
            print_info "Removing existing Go installation..."
            sudo rm -rf /usr/local/go
        fi
        
        # Extract to /usr/local
        sudo tar -C /usr/local -xzf "$tmp_dir/$go_tar"
        
        # Add to PATH
        local shell_rc=""
        if [ -f "$HOME/.zshrc" ]; then
            shell_rc="$HOME/.zshrc"
        elif [ -f "$HOME/.bashrc" ]; then
            shell_rc="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            shell_rc="$HOME/.bash_profile"
        fi
        
        if [ -n "$shell_rc" ]; then
            # Check if Go path is already in rc file
            if ! grep -q '/usr/local/go/bin' "$shell_rc" 2>/dev/null; then
                print_info "Adding Go to PATH in $shell_rc..."
                echo '' >> "$shell_rc"
                echo '# Go' >> "$shell_rc"
                echo 'export PATH=$PATH:/usr/local/go/bin' >> "$shell_rc"
                echo 'export PATH=$PATH:$HOME/go/bin' >> "$shell_rc"
            fi
        fi
        
        # Export for current session
        export PATH=$PATH:/usr/local/go/bin
        export PATH=$PATH:$HOME/go/bin
    fi
    
    # Cleanup
    rm -rf "$tmp_dir"
    
    # Verify installation
    if command -v /usr/local/go/bin/go &> /dev/null; then
        print_success "Go $GO_VERSION installed successfully"
        print_info "Restart your terminal or run: source $shell_rc"
    else
        print_error "Go installation failed"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# OLLAMA INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════

check_ollama() {
    if command -v ollama &> /dev/null; then
        local version=$(ollama --version 2>/dev/null | head -1 || echo "unknown")
        print_success "Ollama already installed: $version"
        return 0
    fi
    return 1
}

install_ollama() {
    local os=$(detect_os)
    
    print_step "Installing Ollama"
    
    if [ "$os" = "darwin" ]; then
        # macOS: Check for Homebrew first
        if command -v brew &> /dev/null; then
            print_info "Installing via Homebrew..."
            brew install ollama
        else
            print_info "Installing via official installer..."
            curl -fsSL https://ollama.ai/install.sh | sh
        fi
    elif [ "$os" = "linux" ]; then
        print_info "Installing via official installer..."
        curl -fsSL https://ollama.ai/install.sh | sh
    else
        print_error "Please install Ollama manually from https://ollama.ai"
        exit 1
    fi
    
    if command -v ollama &> /dev/null; then
        print_success "Ollama installed successfully"
    else
        print_error "Ollama installation failed"
        exit 1
    fi
}

start_ollama() {
    print_info "Checking if Ollama is running..."
    
    if curl -s http://localhost:11434/api/tags &> /dev/null; then
        print_success "Ollama is running"
        return 0
    fi
    
    print_info "Starting Ollama..."
    
    local os=$(detect_os)
    
    if [ "$os" = "darwin" ]; then
        # macOS: Start Ollama in background
        ollama serve &> /dev/null &
        sleep 3
    elif [ "$os" = "linux" ]; then
        # Linux: Try systemd first, then manual
        if command -v systemctl &> /dev/null; then
            sudo systemctl start ollama 2>/dev/null || ollama serve &> /dev/null &
        else
            ollama serve &> /dev/null &
        fi
        sleep 3
    fi
    
    # Verify it's running
    if curl -s http://localhost:11434/api/tags &> /dev/null; then
        print_success "Ollama started"
    else
        print_warning "Could not start Ollama automatically"
        print_info "Please run 'ollama serve' in another terminal"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MODEL DOWNLOAD
# ═══════════════════════════════════════════════════════════════════════════════

download_model() {
    local model=$1
    
    print_info "Downloading $model..."
    print_info "This may take several minutes depending on your internet speed."
    echo ""
    
    ollama pull "$model"
    
    if [ $? -eq 0 ]; then
        print_success "Model $model downloaded"
    else
        print_error "Failed to download $model"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# OBOT BUILD
# ═══════════════════════════════════════════════════════════════════════════════

build_obot() {
    print_step "Building obot"
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_dir="$(dirname "$script_dir")"
    
    # Check if we're in the obot directory
    if [ ! -f "$project_dir/go.mod" ]; then
        print_info "Cloning obot repository..."
        local tmp_dir=$(mktemp -d)
        git clone "$OBOT_REPO" "$tmp_dir/obot"
        project_dir="$tmp_dir/obot"
    fi
    
    cd "$project_dir"
    
    # Use the correct Go binary
    local GO_BIN="go"
    if [ -x "/usr/local/go/bin/go" ]; then
        GO_BIN="/usr/local/go/bin/go"
    fi
    
    print_info "Downloading dependencies..."
    $GO_BIN mod download
    $GO_BIN mod tidy
    
    print_info "Building binary..."
    mkdir -p bin
    local COMMIT="none"
    if command -v git &> /dev/null; then
        COMMIT=$(git -C "$project_dir" rev-parse --short=12 HEAD 2>/dev/null || echo "none")
    fi
    local BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local BUILT_BY=$(id -un 2>/dev/null || echo "unknown")

    $GO_BIN build -ldflags "-s -w -X main.Version=1.0.0 -X main.Commit=$COMMIT -X main.Date=$BUILD_DATE -X main.BuiltBy=$BUILT_BY" -o bin/obot ./cmd/obot
    
    if [ -f "bin/obot" ]; then
        print_success "Build successful"
        
        # Install to /usr/local/bin
        print_info "Installing to $INSTALL_DIR..."
        sudo cp bin/obot "$INSTALL_DIR/"
        sudo chmod +x "$INSTALL_DIR/obot"
        
        print_success "obot installed to $INSTALL_DIR/obot"
    else
        print_error "Build failed"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

save_config() {
    local tier=$1
    local model=$2
    local ram=$3
    
    local config_dir="$HOME/.config/obot"
    mkdir -p "$config_dir"
    
    cat > "$config_dir/config.json" << EOF
{
  "tier": "$tier",
  "model": "$model",
  "ram_gb": $ram,
  "ollama_url": "http://localhost:11434",
  "verbose": true,
  "temperature": 0.3,
  "max_tokens": 4096,
  "auto_detect_tier": true
}
EOF
    
    print_success "Configuration saved to $config_dir/config.json"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    echo ""
    print_color "$CYAN$BOLD" "  ┌─────────────────────────────────────────┐"
    print_color "$CYAN$BOLD" "  │          obot Setup Script              │"
    print_color "$CYAN$BOLD" "  │    Local AI-powered code fixer CLI      │"
    print_color "$CYAN$BOLD" "  └─────────────────────────────────────────┘"
    echo ""
    
    # Detect system
    local os=$(detect_os)
    local arch=$(detect_arch)
    local ram=$(detect_ram_gb)
    local tier=$(select_tier $ram)
    local model=$(get_model_for_tier $tier)
    
    print_step "System Detection"
    print_info "OS: $os"
    print_info "Architecture: $arch"
    print_info "RAM: ${ram}GB"
    print_info "Selected tier: $tier"
    print_info "Model: $model"
    
    # Install Go if needed
    print_step "Checking Go"
    if ! check_go; then
        install_go
    fi
    
    # Install Ollama if needed
    print_step "Checking Ollama"
    if ! check_ollama; then
        install_ollama
    fi
    
    # Start Ollama
    start_ollama
    
    # Download model
    print_step "Model Download"
    print_info "Recommended model for your system: $model"
    echo ""
    read -p "$(print_color "$YELLOW" "Download $model? [Y/n] ")" -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        download_model "$model"
    else
        print_warning "Skipping model download"
        print_info "You can download later with: ollama pull $model"
    fi
    
    # Build obot
    build_obot
    
    # Save configuration
    save_config "$tier" "$model" "$ram"
    
    # Done!
    print_step "Setup Complete!"
    echo ""
    print_color "$GREEN$BOLD" "  obot is ready to use!"
    echo ""
    print_info "Quick start:"
    print_color "$CYAN" "    obot myfile.go              # Fix a file"
    print_color "$CYAN" "    obot myfile.go -10 +20      # Fix lines 10-20"
    print_color "$CYAN" "    obot myfile.go -i           # Interactive mode"
    print_color "$CYAN" "    obot --saved                # View cost savings"
    echo ""
    print_info "Make sure Ollama is running:"
    print_color "$CYAN" "    ollama serve"
    echo ""
    
    # Remind to restart terminal if Go was installed
    if [ ! -z "$GO_INSTALLED" ]; then
        print_warning "Restart your terminal or run: source ~/.zshrc (or ~/.bashrc)"
    fi
}

# Run main
main "$@"
