#!/bin/bash
#
# 🤖 OllamaBot Setup Script
# The fastest, smartest way to get your local AI IDE running
#
# Features:
# - Intelligent system diagnostics
# - Parallel model downloads (optimized for your connection)
# - Real-time progress with ETA
# - Resume interrupted downloads
#
# Compatible with macOS default bash (3.2+)
#

set -eo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Model definitions
MODEL_1_NAME="qwen3:32b"
MODEL_1_SIZE=20
MODEL_1_ROLE="🧠 Orchestrator"
MODEL_1_DESC="thinking, planning, delegating"
MODEL_1_REQ=1

MODEL_2_NAME="command-r:35b"
MODEL_2_SIZE=20
MODEL_2_ROLE="🔍 Researcher"
MODEL_2_DESC="RAG, documentation"
MODEL_2_REQ=0

MODEL_3_NAME="qwen2.5-coder:32b"
MODEL_3_SIZE=20
MODEL_3_ROLE="💻 Coder"
MODEL_3_DESC="code generation, debugging"
MODEL_3_REQ=0

MODEL_4_NAME="qwen3-vl:32b"
MODEL_4_SIZE=20
MODEL_4_ROLE="👁️ Vision"
MODEL_4_DESC="image analysis"
MODEL_4_REQ=0

MODEL_COUNT=4

# Get model info by index (1-based)
get_model_name() { eval "echo \$MODEL_${1}_NAME"; }
get_model_size() { eval "echo \$MODEL_${1}_SIZE"; }
get_model_role() { eval "echo \$MODEL_${1}_ROLE"; }
get_model_desc() { eval "echo \$MODEL_${1}_DESC"; }
get_model_req()  { eval "echo \$MODEL_${1}_REQ"; }

# System requirements
MIN_RAM_GB=16
RECOMMENDED_RAM_GB=32
MIN_DISK_GB=25
RECOMMENDED_DISK_GB=100

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# Symbols
CHECK="✓"
CROSS="✗"
BULLET="•"
PROGRESS_FULL="█"
PROGRESS_EMPTY="░"

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

print_color() {
    local color="$1"
    shift
    echo -e "${color}$*${NC}"
}

print_status() {
    local icon="$1"
    local color="$2"
    shift 2
    echo -e "  ${color}${icon}${NC} $*"
}

print_header() {
    echo
    print_color "$CYAN" "═══════════════════════════════════════════════════════════════"
    print_color "$WHITE$BOLD" "  $1"
    print_color "$CYAN" "═══════════════════════════════════════════════════════════════"
    echo
}

print_subheader() {
    echo
    print_color "$BLUE" "───────────────────────────────────────────────────────────────"
    print_color "$WHITE" "  $1"
    print_color "$BLUE" "───────────────────────────────────────────────────────────────"
}

format_time() {
    local seconds=$1
    if [ "$seconds" -ge 3600 ]; then
        printf "%dh %dm" $((seconds / 3600)) $(((seconds % 3600) / 60))
    elif [ "$seconds" -ge 60 ]; then
        printf "%dm %ds" $((seconds / 60)) $((seconds % 60))
    else
        printf "%ds" "$seconds"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# SYSTEM DIAGNOSTICS
# ═══════════════════════════════════════════════════════════════════════════════

get_macos_version() {
    sw_vers -productVersion
}

is_apple_silicon() {
    [ "$(uname -m)" = "arm64" ]
}

get_ram_gb() {
    local bytes
    bytes=$(sysctl -n hw.memsize)
    echo $((bytes / 1073741824))
}

get_disk_space_gb() {
    local path="${1:-$HOME}"
    df -g "$path" 2>/dev/null | awk 'NR==2 {print $4}'
}

get_cpu_info() {
    sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon"
}

check_ollama_installed() {
    command -v ollama >/dev/null 2>&1
}

check_ollama_running() {
    curl -s --connect-timeout 2 http://localhost:11434/api/tags >/dev/null 2>&1
}

get_installed_models() {
    if check_ollama_running; then
        ollama list 2>/dev/null | tail -n +2 | awk '{print $1}'
    fi
}

is_model_installed() {
    local model="$1"
    local installed
    installed=$(get_installed_models)
    echo "$installed" | grep -q "^${model}$"
}

test_download_speed() {
    local test_url="https://speed.cloudflare.com/__down?bytes=5242880"  # 5MB
    local speed
    speed=$(curl -s -o /dev/null -w "%{speed_download}" --connect-timeout 5 --max-time 10 "$test_url" 2>/dev/null || echo "0")
    # Convert bytes/sec to Mbps
    if [ -n "$speed" ] && [ "$speed" != "0" ]; then
        echo "$speed" | awk '{printf "%.0f", $1 * 8 / 1000000}'
    else
        echo "0"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# DIAGNOSTICS REPORT
# ═══════════════════════════════════════════════════════════════════════════════

run_diagnostics() {
    print_header "🔍 System Diagnostics"
    
    local all_pass=1
    local warnings=""
    
    # macOS Version
    local macos_ver
    macos_ver=$(get_macos_version)
    local macos_major
    macos_major=$(echo "$macos_ver" | cut -d. -f1)
    if [ "$macos_major" -ge 14 ]; then
        print_status "$CHECK" "$GREEN" "macOS Version: $macos_ver (Sonoma+)"
    else
        print_status "$CROSS" "$RED" "macOS Version: $macos_ver (requires 14.0+)"
        all_pass=0
    fi
    
    # Apple Silicon
    if is_apple_silicon; then
        local cpu
        cpu=$(get_cpu_info)
        print_status "$CHECK" "$GREEN" "Architecture: Apple Silicon"
    else
        print_status "$CROSS" "$RED" "Architecture: Intel (Apple Silicon recommended)"
        warnings="${warnings}Intel Macs have reduced performance with large models\n"
    fi
    
    # RAM
    local ram
    ram=$(get_ram_gb)
    if [ "$ram" -ge "$RECOMMENDED_RAM_GB" ]; then
        print_status "$CHECK" "$GREEN" "Memory: ${ram}GB (excellent for 32B models)"
    elif [ "$ram" -ge "$MIN_RAM_GB" ]; then
        print_status "$BULLET" "$YELLOW" "Memory: ${ram}GB (minimum met, 32GB recommended)"
        warnings="${warnings}With ${ram}GB RAM, consider smaller models\n"
    else
        print_status "$CROSS" "$RED" "Memory: ${ram}GB (minimum ${MIN_RAM_GB}GB required)"
        all_pass=0
    fi
    
    # Disk Space
    local disk
    disk=$(get_disk_space_gb "$HOME")
    if [ "$disk" -ge "$RECOMMENDED_DISK_GB" ]; then
        print_status "$CHECK" "$GREEN" "Disk Space: ${disk}GB available (excellent)"
    elif [ "$disk" -ge "$MIN_DISK_GB" ]; then
        print_status "$BULLET" "$YELLOW" "Disk Space: ${disk}GB available (minimum for 1 model)"
        warnings="${warnings}Limited disk space - may not fit all models\n"
    else
        print_status "$CROSS" "$RED" "Disk Space: ${disk}GB available (need ${MIN_DISK_GB}GB)"
        all_pass=0
    fi
    
    # Ollama Installation
    if check_ollama_installed; then
        local ollama_ver
        ollama_ver=$(ollama --version 2>/dev/null | head -1 || echo "installed")
        print_status "$CHECK" "$GREEN" "Ollama: $ollama_ver"
    else
        print_status "$CROSS" "$RED" "Ollama: Not installed"
        all_pass=0
    fi
    
    # Ollama Running
    if check_ollama_running; then
        print_status "$CHECK" "$GREEN" "Ollama Service: Running"
    else
        print_status "$BULLET" "$YELLOW" "Ollama Service: Not running (will start)"
    fi
    
    # Network Speed
    echo
    print_color "$WHITE" "  Network:"
    printf "    Testing download speed... "
    local speed
    speed=$(test_download_speed)
    if [ "$speed" != "0" ] && [ "$speed" -gt 10 ]; then
        print_color "$GREEN" "${speed} Mbps $CHECK"
    elif [ "$speed" != "0" ]; then
        print_color "$YELLOW" "${speed} Mbps (slow connection)"
    else
        print_color "$GRAY" "Could not test"
    fi
    
    # Installed Models
    echo
    print_color "$WHITE" "  Installed Models:"
    local installed
    installed=$(get_installed_models)
    if [ -n "$installed" ]; then
        echo "$installed" | while read -r model; do
            print_status "$CHECK" "$GREEN" "$model"
        done
    else
        print_color "$GRAY" "    No models installed yet"
    fi
    
    # Print warnings
    if [ -n "$warnings" ]; then
        echo
        print_color "$YELLOW" "  ⚠️  Warnings:"
        echo -e "$warnings" | while read -r warning; do
            if [ -n "$warning" ]; then
                print_color "$YELLOW" "    $BULLET $warning"
            fi
        done
    fi
    
    echo
    if [ "$all_pass" -eq 1 ]; then
        print_status "$CHECK" "${GREEN}${BOLD}" "System check passed! Ready to install."
        return 0
    else
        print_status "$CROSS" "${RED}${BOLD}" "System requirements not met."
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# SPACE ANALYSIS
# ═══════════════════════════════════════════════════════════════════════════════

show_space_analysis() {
    print_subheader "💾 Disk Space Analysis"
    
    local disk_available
    disk_available=$(get_disk_space_gb "$HOME")
    local installed
    installed=$(get_installed_models)
    
    echo
    print_color "$WHITE" "  Model Space Requirements:"
    echo
    
    printf "  ${GRAY}%-25s %8s %12s${NC}\n" "MODEL" "SIZE" "STATUS"
    printf "  ${GRAY}%-25s %8s %12s${NC}\n" "─────────────────────────" "────────" "────────────"
    
    local total_needed=0
    local total_installed=0
    
    for i in $(seq 1 $MODEL_COUNT); do
        local name size status color
        name=$(get_model_name $i)
        size=$(get_model_size $i)
        
        if echo "$installed" | grep -q "^${name}$"; then
            status="✓ Installed"
            color="$GREEN"
            total_installed=$((total_installed + size))
        else
            status="To download"
            color="$YELLOW"
            total_needed=$((total_needed + size))
        fi
        
        printf "  %-25s %6dGB  ${color}%s${NC}\n" "$name" "$size" "$status"
    done
    
    echo
    printf "  ${GRAY}%-25s %8s${NC}\n" "─────────────────────────" "────────"
    printf "  ${WHITE}%-25s %6dGB${NC}\n" "Already installed:" "$total_installed"
    printf "  ${CYAN}%-25s %6dGB${NC}\n" "Need to download:" "$total_needed"
    printf "  ${WHITE}%-25s %6dGB${NC}\n" "Available disk:" "$disk_available"
    echo
    
    if [ "$total_needed" -gt "$disk_available" ]; then
        local shortage=$((total_needed - disk_available))
        print_status "$CROSS" "$RED" "Insufficient space! Need ${shortage}GB more."
        echo
        print_color "$YELLOW" "  Options:"
        print_color "$GRAY" "    1. Free up disk space"
        print_color "$GRAY" "    2. Install fewer models (orchestrator only: ~20GB)"
        print_color "$GRAY" "    3. Use smaller variants (qwen3:8b)"
        return 1
    else
        local remaining=$((disk_available - total_needed))
        print_status "$CHECK" "$GREEN" "Sufficient space! ${remaining}GB will remain."
        return 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MODEL SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

select_models() {
    print_subheader "🎭 Model Selection"
    
    local disk_available
    disk_available=$(get_disk_space_gb "$HOME")
    local installed
    installed=$(get_installed_models)
    
    echo
    print_color "$WHITE" "  Available models:"
    echo
    
    for i in $(seq 1 $MODEL_COUNT); do
        local name size role desc req status=""
        name=$(get_model_name $i)
        size=$(get_model_size $i)
        role=$(get_model_role $i)
        desc=$(get_model_desc $i)
        req=$(get_model_req $i)
        
        if echo "$installed" | grep -q "^${name}$"; then
            status="${GREEN}[installed]${NC}"
        fi
        
        local required=""
        if [ "$req" -eq 1 ]; then
            required="${YELLOW}[REQUIRED]${NC}"
        fi
        
        printf "  ${WHITE}%d.${NC} %-22s ${GRAY}%3dGB${NC} %s %s %s\n" \
            "$i" "$name" "$size" "$role" "$required" "$status"
        printf "     ${GRAY}%s${NC}\n" "$desc"
    done
    
    echo
    print_color "$GRAY" "  Available disk: ${disk_available}GB"
    echo
    print_color "$CYAN" "  Choose installation option:"
    echo
    print_color "$WHITE" "  A) Full Suite - All 4 models (~80GB)"
    print_color "$WHITE" "  B) Essential  - Orchestrator + Coder (~40GB)"
    print_color "$WHITE" "  C) Minimal    - Orchestrator only (~20GB)"
    print_color "$WHITE" "  D) Custom     - Choose specific models"
    echo
    
    read -p "  Your choice [A/B/C/D]: " -r choice
    echo
    
    local selected=""
    
    case "$(echo "$choice" | tr '[:lower:]' '[:upper:]')" in
        A)
            selected="$MODEL_1_NAME $MODEL_2_NAME $MODEL_3_NAME $MODEL_4_NAME"
            ;;
        B)
            selected="$MODEL_1_NAME $MODEL_3_NAME"
            ;;
        C)
            selected="$MODEL_1_NAME"
            ;;
        D)
            print_color "$CYAN" "  Enter model numbers (e.g., 1 3 4):"
            read -r selections
            for sel in $selections; do
                if [ "$sel" -ge 1 ] && [ "$sel" -le "$MODEL_COUNT" ]; then
                    local model_name
                    model_name=$(get_model_name "$sel")
                    selected="$selected $model_name"
                fi
            done
            # Always include orchestrator
            if ! echo "$selected" | grep -q "$MODEL_1_NAME"; then
                selected="$MODEL_1_NAME $selected"
                print_color "$YELLOW" "  Added $MODEL_1_NAME (required orchestrator)"
            fi
            ;;
        *)
            print_color "$YELLOW" "  Invalid choice, defaulting to Essential"
            selected="$MODEL_1_NAME $MODEL_3_NAME"
            ;;
    esac
    
    echo "$selected"
}

# ═══════════════════════════════════════════════════════════════════════════════
# DOWNLOAD FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

download_model_with_progress() {
    local model="$1"
    local log_file="/tmp/ollama_${model//[:\/]/_}.log"
    
    print_color "$CYAN" "  Downloading $model..."
    
    # Start download
    ollama pull "$model" 2>&1 | tee "$log_file"
    local exit_code=$?
    
    rm -f "$log_file"
    
    if [ $exit_code -eq 0 ]; then
        print_status "$CHECK" "$GREEN" "$model downloaded successfully"
        return 0
    else
        print_status "$CROSS" "$RED" "$model download failed"
        return 1
    fi
}

download_models_sequential() {
    local models="$1"
    local success=0
    local failed=0
    
    for model in $models; do
        # Skip if already installed
        if is_model_installed "$model"; then
            print_status "$CHECK" "$GREEN" "$model already installed"
            success=$((success + 1))
            continue
        fi
        
        echo
        if download_model_with_progress "$model"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
    done
    
    echo
    if [ $failed -eq 0 ]; then
        print_status "$CHECK" "${GREEN}${BOLD}" "All $success model(s) ready!"
        return 0
    else
        print_status "$CROSS" "$RED" "$failed model(s) failed"
        return 1
    fi
}

# Parallel download (2 at a time for optimal bandwidth usage)
download_models_parallel() {
    local models="$1"
    local to_download=""
    
    # Filter out already installed models
    for model in $models; do
        if ! is_model_installed "$model"; then
            to_download="$to_download $model"
        else
            print_status "$CHECK" "$GREEN" "$model already installed"
        fi
    done
    
    to_download=$(echo "$to_download" | xargs)  # Trim
    
    if [ -z "$to_download" ]; then
        print_status "$CHECK" "${GREEN}${BOLD}" "All models already installed!"
        return 0
    fi
    
    echo
    print_color "$WHITE" "  Starting parallel downloads..."
    print_color "$GRAY" "  Models to download: $to_download"
    echo
    
    # Download up to 2 at a time
    local pids=""
    local count=0
    local model_array
    # shellcheck disable=SC2086
    set -- $to_download
    
    while [ $# -gt 0 ]; do
        # Start downloads (up to 2)
        local batch=""
        for _ in 1 2; do
            if [ $# -gt 0 ]; then
                local model="$1"
                shift
                batch="$batch $model"
                
                # Start in background
                (
                    ollama pull "$model" >/dev/null 2>&1
                ) &
                pids="$pids $!"
                count=$((count + 1))
            fi
        done
        
        # Wait for batch to complete
        for pid in $pids; do
            wait "$pid" 2>/dev/null || true
        done
        pids=""
        
        # Show progress for this batch
        for model in $batch; do
            if is_model_installed "$model"; then
                print_status "$CHECK" "$GREEN" "$model"
            else
                print_status "$CROSS" "$RED" "$model (failed)"
            fi
        done
    done
    
    echo
    local installed_count=0
    for model in $to_download; do
        if is_model_installed "$model"; then
            installed_count=$((installed_count + 1))
        fi
    done
    
    if [ "$installed_count" -eq "$count" ]; then
        print_status "$CHECK" "${GREEN}${BOLD}" "All models downloaded!"
        return 0
    else
        print_status "$BULLET" "$YELLOW" "$installed_count of $count models installed"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALLATION FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

install_ollama() {
    print_subheader "📦 Installing Ollama"
    
    if check_ollama_installed; then
        print_status "$CHECK" "$GREEN" "Ollama already installed"
        return 0
    fi
    
    print_color "$CYAN" "  Downloading Ollama installer..."
    
    if curl -fsSL https://ollama.ai/install.sh | sh; then
        print_status "$CHECK" "$GREEN" "Ollama installed successfully"
        return 0
    else
        print_status "$CROSS" "$RED" "Failed to install Ollama"
        print_color "$GRAY" "  Please install manually: https://ollama.ai/download"
        return 1
    fi
}

start_ollama() {
    if check_ollama_running; then
        return 0
    fi
    
    print_color "$CYAN" "  Starting Ollama service..."
    
    # Start Ollama in background
    ollama serve >/dev/null 2>&1 &
    
    # Wait for it to be ready
    local attempts=0
    while ! check_ollama_running && [ $attempts -lt 30 ]; do
        sleep 1
        attempts=$((attempts + 1))
    done
    
    if check_ollama_running; then
        print_status "$CHECK" "$GREEN" "Ollama service started"
        return 0
    else
        print_status "$CROSS" "$RED" "Failed to start Ollama"
        return 1
    fi
}

build_ollamabot() {
    print_subheader "🔨 Building OllamaBot"
    
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_dir
    project_dir="$(dirname "$script_dir")"
    
    cd "$project_dir"
    
    # Check if already built
    if [ -d "build/OllamaBot.app" ]; then
        print_status "$CHECK" "$GREEN" "OllamaBot.app already exists"
        read -p "  Rebuild? [y/N] " -r
        echo
        if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
            return 0
        fi
    fi
    
    # Generate icon if needed
    if [ ! -f "Resources/AppIcon.icns" ]; then
        print_color "$CYAN" "  Generating app icon..."
        if [ -x "scripts/generate-icon.sh" ]; then
            ./scripts/generate-icon.sh 2>/dev/null || true
        fi
    fi
    
    # Build
    print_color "$CYAN" "  Compiling (this may take a minute)..."
    
    if ./scripts/build-app.sh --release 2>&1 | tail -5; then
        print_status "$CHECK" "$GREEN" "Build complete!"
        return 0
    else
        print_status "$CROSS" "$RED" "Build failed"
        return 1
    fi
}

install_to_applications() {
    print_subheader "📲 Installing to Applications"
    
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_dir
    project_dir="$(dirname "$script_dir")"
    local app_path="$project_dir/build/OllamaBot.app"
    
    if [ ! -d "$app_path" ]; then
        print_status "$CROSS" "$RED" "OllamaBot.app not found"
        return 1
    fi
    
    # Check if already installed
    if [ -d "/Applications/OllamaBot.app" ]; then
        print_color "$YELLOW" "  OllamaBot already in /Applications"
        read -p "  Replace? [Y/n] " -r
        echo
        if [ "$REPLY" = "n" ] || [ "$REPLY" = "N" ]; then
            return 0
        fi
        rm -rf "/Applications/OllamaBot.app"
    fi
    
    # Copy
    print_color "$CYAN" "  Copying to /Applications..."
    if cp -r "$app_path" "/Applications/"; then
        print_status "$CHECK" "$GREEN" "Installed to /Applications"
        return 0
    else
        print_status "$CROSS" "$RED" "Failed (try with sudo)"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

print_banner() {
    # Only clear if running interactively
    if [ -t 1 ]; then
        clear
    fi
    print_color "$CYAN" '
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║     ██████╗ ██╗     ██╗      █████╗ ███╗   ███╗ █████╗        ║
    ║    ██╔═══██╗██║     ██║     ██╔══██╗████╗ ████║██╔══██╗       ║
    ║    ██║   ██║██║     ██║     ███████║██╔████╔██║███████║       ║
    ║    ██║   ██║██║     ██║     ██╔══██║██║╚██╔╝██║██╔══██║       ║
    ║    ╚██████╔╝███████╗███████╗██║  ██║██║ ╚═╝ ██║██║  ██║       ║
    ║     ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝       ║
    ║                                                               ║
    ║    ██████╗  ██████╗ ████████╗                                 ║
    ║    ██╔══██╗██╔═══██╗╚══██╔══╝      Local AI IDE               ║
    ║    ██████╔╝██║   ██║   ██║         with Infinite Mode         ║
    ║    ██╔══██╗██║   ██║   ██║                                    ║
    ║    ██████╔╝╚██████╔╝   ██║         cadenroberts/OllamaBot     ║
    ║    ╚═════╝  ╚═════╝    ╚═╝                                    ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
'
    print_color "$WHITE$BOLD" "              🚀 Setup & Installation Script"
    print_color "$GRAY" "              The fastest way to local AI power"
    echo
}

main() {
    print_banner
    
    # Step 1: Diagnostics
    if ! run_diagnostics; then
        echo
        print_color "$RED" "Please resolve issues above before continuing."
        exit 1
    fi
    
    # Step 2: Install Ollama if needed
    if ! check_ollama_installed; then
        echo
        read -p "Install Ollama now? [Y/n] " -r
        echo
        if [ "$REPLY" != "n" ] && [ "$REPLY" != "N" ]; then
            install_ollama || exit 1
        else
            print_color "$RED" "Ollama is required."
            exit 1
        fi
    fi
    
    # Step 3: Start Ollama
    start_ollama || exit 1
    
    # Step 4: Model Selection
    local selected_models
    selected_models=$(select_models)
    
    # Step 5: Space Analysis
    if ! show_space_analysis; then
        echo
        read -p "Continue anyway? [y/N] " -r
        echo
        if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
            exit 1
        fi
    fi
    
    # Step 6: Download Models
    print_subheader "⬇️  Downloading Models"
    echo
    
    # Check network speed for download strategy
    local speed
    speed=$(test_download_speed)
    
    if [ "$speed" -gt 50 ]; then
        print_color "$GREEN" "  Fast connection detected (${speed} Mbps)"
        print_color "$CYAN" "  Using parallel downloads for speed..."
        download_models_parallel "$selected_models"
    else
        print_color "$YELLOW" "  Standard connection (${speed} Mbps)"
        print_color "$CYAN" "  Downloading sequentially for reliability..."
        download_models_sequential "$selected_models"
    fi
    
    # Step 7: Build OllamaBot
    echo
    read -p "Build OllamaBot.app? [Y/n] " -r
    echo
    if [ "$REPLY" != "n" ] && [ "$REPLY" != "N" ]; then
        build_ollamabot
    fi
    
    # Step 8: Install to Applications
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_dir
    project_dir="$(dirname "$script_dir")"
    
    if [ -d "$project_dir/build/OllamaBot.app" ]; then
        echo
        read -p "Install to /Applications? [Y/n] " -r
        echo
        if [ "$REPLY" != "n" ] && [ "$REPLY" != "N" ]; then
            install_to_applications
        fi
    fi
    
    # Final Summary
    print_header "🎉 Setup Complete!"
    
    echo
    print_color "${GREEN}${BOLD}" "  OllamaBot is ready!"
    echo
    print_color "$WHITE" "  Quick Start:"
    print_color "$GRAY" "    • Open OllamaBot from Applications"
    print_color "$GRAY" "    • Press ⌘O to open a project"
    print_color "$GRAY" "    • Press ⌘⇧I for Infinite Mode"
    echo
    print_color "$WHITE" "  Selected Models:"
    for model in $selected_models; do
        local role=""
        case "$model" in
            "$MODEL_1_NAME") role="(Orchestrator)" ;;
            "$MODEL_2_NAME") role="(Researcher)" ;;
            "$MODEL_3_NAME") role="(Coder)" ;;
            "$MODEL_4_NAME") role="(Vision)" ;;
        esac
        if is_model_installed "$model"; then
            print_color "$GREEN" "    $CHECK $model $role"
        else
            print_color "$RED" "    $CROSS $model $role (not installed)"
        fi
    done
    echo
    print_color "$CYAN" "  Thank you for using OllamaBot! 🤖"
    echo
    
    # Launch option
    read -p "Launch OllamaBot now? [Y/n] " -r
    echo
    if [ "$REPLY" != "n" ] && [ "$REPLY" != "N" ]; then
        if [ -d "/Applications/OllamaBot.app" ]; then
            open "/Applications/OllamaBot.app"
        elif [ -d "$project_dir/build/OllamaBot.app" ]; then
            open "$project_dir/build/OllamaBot.app"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════════

case "${1:-}" in
    --help|-h)
        print_banner
        echo "Usage: $(basename "$0") [options]"
        echo
        echo "Options:"
        echo "  --help, -h       Show this help"
        echo "  --diagnose       Run diagnostics only"
        echo "  --space          Show space analysis only"
        echo "  --models         Download models only"
        echo "  --build          Build OllamaBot only"
        echo
        exit 0
        ;;
    --diagnose)
        print_banner
        run_diagnostics
        exit $?
        ;;
    --space)
        print_banner
        if check_ollama_running || start_ollama; then
            show_space_analysis
        fi
        exit $?
        ;;
    --models)
        print_banner
        start_ollama || exit 1
        selected=$(select_models)
        show_space_analysis
        download_models_sequential "$selected"
        exit $?
        ;;
    --build)
        print_banner
        build_ollamabot
        exit $?
        ;;
    *)
        main
        ;;
esac
