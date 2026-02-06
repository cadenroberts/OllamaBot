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

# ═══════════════════════════════════════════════════════════════════════════════
# MODEL TIERS - RAM-aware model selection
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# Tier: MINIMAL (8GB RAM) - 1.5B-3B models
# These models ACTUALLY run smoothly on 8GB without swapping
# macOS needs ~3-4GB, leaving ~4-5GB for the model
# ═══════════════════════════════════════════════════════════════════════════════
MINIMAL_1_NAME="qwen2.5:1.5b"          # Best small orchestrator (1.2GB loaded)
MINIMAL_1_SIZE=1
MINIMAL_2_NAME="phi3:mini"             # Good small reasoning (2.3GB loaded) - Microsoft's efficient model
MINIMAL_2_SIZE=2
MINIMAL_3_NAME="deepseek-coder:1.3b"   # Best tiny coder! Surprisingly capable (1GB loaded)
MINIMAL_3_SIZE=1
MINIMAL_4_NAME="moondream:1.8b"        # Best tiny vision model (1.5GB loaded)
MINIMAL_4_SIZE=1
MINIMAL_TOTAL=5

# ═══════════════════════════════════════════════════════════════════════════════
# Tier: COMPACT (16GB RAM) - 7B models
# These models run well on 16GB with room for system overhead
# macOS needs ~3-4GB, leaving ~12GB for models
# 7B models use ~4-5GB, so comfortable single-model operation
# ═══════════════════════════════════════════════════════════════════════════════
COMPACT_1_NAME="qwen2.5:7b"            # Excellent small orchestrator (4.7GB loaded)
COMPACT_1_SIZE=5
COMPACT_2_NAME="mistral:7b"            # Strong research/reasoning (4.1GB loaded)
COMPACT_2_SIZE=4
COMPACT_3_NAME="deepseek-coder:6.7b"   # Excellent small coder! (4GB loaded)
COMPACT_3_SIZE=4
COMPACT_4_NAME="llava:7b"              # Solid vision model (4.5GB loaded)
COMPACT_4_SIZE=5
COMPACT_TOTAL=18

# Tier: BALANCED (24GB RAM) - 14B models
BALANCED_1_NAME="qwen3:14b"
BALANCED_1_SIZE=9
BALANCED_2_NAME="command-r:14b"
BALANCED_2_SIZE=9
BALANCED_3_NAME="qwen2.5-coder:14b"
BALANCED_3_SIZE=9
BALANCED_4_NAME="qwen2-vl:14b"
BALANCED_4_SIZE=9
BALANCED_TOTAL=36

# ═══════════════════════════════════════════════════════════════════════════════
# Tier: PERFORMANCE (32GB RAM) - 32B models  
# Best single-model operation with full 32B capability
# ═══════════════════════════════════════════════════════════════════════════════
PERF_1_NAME="qwen3:32b"
PERF_1_SIZE=20
PERF_2_NAME="command-r:35b"
PERF_2_SIZE=20
PERF_3_NAME="qwen2.5-coder:32b"
PERF_3_SIZE=20
PERF_4_NAME="qwen3-vl:32b"
PERF_4_SIZE=20
PERF_TOTAL=80

# ═══════════════════════════════════════════════════════════════════════════════
# Tier: ADVANCED (64GB RAM) - 70B models
# macOS needs ~5GB, leaving ~59GB for models
# Can run single 70B model, or 70B + smaller models
# VERIFIED sizes from ollama.com/library
# ═══════════════════════════════════════════════════════════════════════════════
ADVANCED_1_NAME="llama3.1:70b"           # Meta's flagship (40GB disk) - VERIFIED
ADVANCED_1_SIZE=40
ADVANCED_2_NAME="command-r:35b"          # Cohere research model (19GB disk) - VERIFIED  
ADVANCED_2_SIZE=19
ADVANCED_3_NAME="deepseek-coder:33b"     # Excellent large coder (20GB disk) - VERIFIED
ADVANCED_3_SIZE=20
ADVANCED_4_NAME="llama3.2-vision:11b"    # Vision model (8GB disk) - VERIFIED
ADVANCED_4_SIZE=8
ADVANCED_TOTAL=87

# ═══════════════════════════════════════════════════════════════════════════════
# Tier: MAXIMUM (128GB RAM) - Largest models + parallel execution
# macOS needs ~6GB, leaving ~122GB for models
# Can run multiple 70B models simultaneously
# Includes 90B vision model for best image understanding
# VERIFIED sizes from ollama.com/library
# ═══════════════════════════════════════════════════════════════════════════════
MAXIMUM_1_NAME="qwen2.5:72b"              # Alibaba's flagship orchestrator (42GB disk) - VERIFIED
MAXIMUM_1_SIZE=42
MAXIMUM_2_NAME="command-r-plus:104b"     # Cohere's best RAG model (59GB disk) - VERIFIED
MAXIMUM_2_SIZE=59
MAXIMUM_3_NAME="deepseek-coder:33b"      # Excellent large coder (20GB disk) - VERIFIED
MAXIMUM_3_SIZE=20
MAXIMUM_4_NAME="llama3.2-vision:90b"     # Best vision model available (55GB disk) - VERIFIED
MAXIMUM_4_SIZE=55
MAXIMUM_TOTAL=176

# Model roles (same across tiers)
MODEL_1_ROLE="🧠 Orchestrator"
MODEL_1_DESC="thinking, planning, delegating"
MODEL_2_ROLE="🔍 Researcher"
MODEL_2_DESC="RAG, documentation"
MODEL_3_ROLE="💻 Coder"
MODEL_3_DESC="code generation, debugging"
MODEL_4_ROLE="👁️ Vision"
MODEL_4_DESC="image analysis"

MODEL_COUNT=4
SELECTED_TIER=""

# Get model info based on selected tier
get_model_name() {
    local idx=$1
    case "$SELECTED_TIER" in
        minimal)   eval "echo \$MINIMAL_${idx}_NAME" ;;
        compact)   eval "echo \$COMPACT_${idx}_NAME" ;;
        balanced)  eval "echo \$BALANCED_${idx}_NAME" ;;
        performance) eval "echo \$PERF_${idx}_NAME" ;;
        advanced)  eval "echo \$ADVANCED_${idx}_NAME" ;;
        maximum)   eval "echo \$MAXIMUM_${idx}_NAME" ;;
        *)         eval "echo \$PERF_${idx}_NAME" ;;
    esac
}

get_model_size() {
    local idx=$1
    case "$SELECTED_TIER" in
        minimal)   eval "echo \$MINIMAL_${idx}_SIZE" ;;
        compact)   eval "echo \$COMPACT_${idx}_SIZE" ;;
        balanced)  eval "echo \$BALANCED_${idx}_SIZE" ;;
        performance) eval "echo \$PERF_${idx}_SIZE" ;;
        advanced)  eval "echo \$ADVANCED_${idx}_SIZE" ;;
        maximum)   eval "echo \$MAXIMUM_${idx}_SIZE" ;;
        *)         eval "echo \$PERF_${idx}_SIZE" ;;
    esac
}

get_model_role() { eval "echo \$MODEL_${1}_ROLE"; }
get_model_desc() { eval "echo \$MODEL_${1}_DESC"; }

get_tier_total() {
    case "$SELECTED_TIER" in
        minimal)     echo "$MINIMAL_TOTAL" ;;
        compact)     echo "$COMPACT_TOTAL" ;;
        balanced)    echo "$BALANCED_TOTAL" ;;
        performance) echo "$PERF_TOTAL" ;;
        advanced)    echo "$ADVANCED_TOTAL" ;;
        maximum)     echo "$MAXIMUM_TOTAL" ;;
        *)           echo "$PERF_TOTAL" ;;
    esac
}

# Determine recommended tier based on RAM
get_recommended_tier() {
    local ram=$1
    if [ "$ram" -ge 128 ]; then
        echo "maximum"       # 128GB+ - largest models
    elif [ "$ram" -ge 64 ]; then
        echo "advanced"      # 64GB+ - 70B models
    elif [ "$ram" -ge 32 ]; then
        echo "performance"   # 32GB - 32B models
    elif [ "$ram" -ge 24 ]; then
        echo "balanced"      # 24GB - 14B models
    elif [ "$ram" -ge 16 ]; then
        echo "compact"       # 16GB - 7B models
    else
        echo "minimal"       # 8GB - 1.5B models
    fi
}

# System requirements
MIN_RAM_GB=16
RECOMMENDED_RAM_GB=32
MIN_DISK_GB=25
RECOMMENDED_DISK_GB=100

# Colors - Blue-only palette for consistent branding
# All user-facing colors are blue variants for visual consistency
BLUE='\033[0;34m'
CYAN='\033[0;36m'
LIGHT_BLUE='\033[1;34m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# Legacy color aliases - all map to blue variants
RED="$CYAN"           # Use cyan instead of red
GREEN="$LIGHT_BLUE"   # Use light blue instead of green
YELLOW="$CYAN"        # Use cyan instead of yellow
PURPLE="$BLUE"        # Use blue instead of purple

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
        local chip_info
        chip_info=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon")
        # Detect specific chip variant
        local chip_variant=""
        if echo "$chip_info" | grep -q "M1"; then
            chip_variant="M1"
        elif echo "$chip_info" | grep -q "M2"; then
            chip_variant="M2"
        elif echo "$chip_info" | grep -q "M3"; then
            chip_variant="M3"
        elif echo "$chip_info" | grep -q "M4"; then
            chip_variant="M4"
        else
            chip_variant="Apple Silicon"
        fi
        
        # Check for Pro/Max/Ultra variants
        local gpu_cores
        gpu_cores=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -i "Total Number of Cores" | head -1 | awk '{print $NF}')
        local chip_tier=""
        if [ -n "$gpu_cores" ]; then
            if [ "$gpu_cores" -ge 30 ]; then
                chip_tier=" Ultra"
            elif [ "$gpu_cores" -ge 24 ]; then
                chip_tier=" Max"
            elif [ "$gpu_cores" -ge 14 ]; then
                chip_tier=" Pro"
            fi
        fi
        
        print_status "$CHECK" "$GREEN" "Architecture: ${chip_variant}${chip_tier} (optimal for local AI)"
    else
        print_status "$CROSS" "$RED" "Architecture: Intel (Apple Silicon strongly recommended)"
        warnings="${warnings}Intel Macs have significantly reduced performance with 32B models\n"
    fi
    
    # RAM - with specific recommendations
    local ram
    ram=$(get_ram_gb)
    local model_recommendation=""
    
    if [ "$ram" -ge 128 ]; then
        print_status "$CHECK" "$GREEN" "Memory: ${ram}GB (can run multiple 32B models simultaneously)"
        model_recommendation="all models with room to spare"
    elif [ "$ram" -ge 64 ]; then
        print_status "$CHECK" "$GREEN" "Memory: ${ram}GB (excellent for all 32B models)"
        model_recommendation="all models comfortably"
    elif [ "$ram" -ge "$RECOMMENDED_RAM_GB" ]; then
        print_status "$CHECK" "$GREEN" "Memory: ${ram}GB (good for 32B models)"
        model_recommendation="32B models (one at a time)"
    elif [ "$ram" -ge 24 ]; then
        print_status "$BULLET" "$YELLOW" "Memory: ${ram}GB (tight for 32B, consider 8B)"
        warnings="${warnings}24GB RAM - 32B models may be slow, recommend qwen3:8b variants\n"
        model_recommendation="8B-14B models recommended"
    elif [ "$ram" -ge "$MIN_RAM_GB" ]; then
        print_status "$BULLET" "$YELLOW" "Memory: ${ram}GB (minimum met)"
        warnings="${warnings}16GB RAM - use smaller model variants (qwen3:8b)\n"
        model_recommendation="8B models only"
    else
        print_status "$CROSS" "$RED" "Memory: ${ram}GB (minimum ${MIN_RAM_GB}GB required)"
        all_pass=0
    fi
    
    if [ -n "$model_recommendation" ]; then
        print_color "$GRAY" "    Recommended: $model_recommendation"
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
    
    # GPU / Neural Engine info (critical for AI inference)
    echo
    print_color "$WHITE" "  AI Acceleration:"
    if is_apple_silicon; then
        # Get GPU cores
        local gpu_cores
        gpu_cores=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -i "Total Number of Cores" | head -1 | awk '{print $NF}')
        if [ -n "$gpu_cores" ]; then
            print_color "$GRAY" "    GPU Cores: $gpu_cores"
        fi
        
        # Neural Engine (all Apple Silicon has it)
        print_color "$GRAY" "    Neural Engine: Available (16-core)"
        print_color "$GRAY" "    Metal Support: Yes (optimized for Ollama)"
    else
        print_color "$YELLOW" "    Metal GPU: Limited support on Intel"
        print_color "$YELLOW" "    Neural Engine: Not available"
        warnings="${warnings}No Neural Engine - inference will be significantly slower\n"
    fi
    
    # Network Speed
    echo
    print_color "$WHITE" "  Network:"
    printf "    Testing download speed... "
    local speed
    speed=$(test_download_speed)
    if [ "$speed" != "0" ] && [ "$speed" -gt 10 ]; then
        print_color "$GREEN" "${speed} Mbps $CHECK"
        
        # Estimate download times
        local est_time_20gb=$((20 * 1024 * 8 / speed / 60))  # minutes
        if [ "$est_time_20gb" -gt 0 ]; then
            print_color "$GRAY" "    Est. time per 20GB model: ~${est_time_20gb} minutes"
        fi
    elif [ "$speed" != "0" ]; then
        print_color "$YELLOW" "${speed} Mbps (slow connection)"
        local est_time_20gb=$((20 * 1024 * 8 / speed / 60))
        print_color "$YELLOW" "    Est. time per 20GB model: ~${est_time_20gb} minutes"
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
# MODEL TIER SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

select_tier() {
    local ram=$1
    local recommended
    recommended=$(get_recommended_tier "$ram")
    
    print_subheader "📊 System RAM Analysis"
    echo
    
    # ═══════════════════════════════════════════════════════════════════════════
    # CRITICAL RAM WARNING (8GB)
    # ═══════════════════════════════════════════════════════════════════════════
    
    if [ "$ram" -lt 16 ]; then
        echo
        printf "  ${RED}╔══════════════════════════════════════════════════════════════════════════╗${NC}\n"
        printf "  ${RED}║${NC}                                                                          ${RED}║${NC}\n"
        printf "  ${RED}║${NC}   ${RED}🚨🚨🚨  CRITICAL: SEVERELY INSUFFICIENT RAM  🚨🚨🚨${NC}                  ${RED}║${NC}\n"
        printf "  ${RED}║${NC}                                                                          ${RED}║${NC}\n"
        printf "  ${RED}╠══════════════════════════════════════════════════════════════════════════╣${NC}\n"
        printf "  ${RED}║${NC}                                                                          ${RED}║${NC}\n"
        printf "  ${RED}║${NC}   Your Mac has only ${WHITE}${ram}GB RAM${NC}.                                         ${RED}║${NC}\n"
        printf "  ${RED}║${NC}                                                                          ${RED}║${NC}\n"
        printf "  ${RED}║${NC}   OllamaBot is designed for ${WHITE}32GB+ unified memory${NC}.                       ${RED}║${NC}\n"
        printf "  ${RED}║${NC}   Running on 8GB is ${RED}NOT RECOMMENDED${NC} and will result in:                  ${RED}║${NC}\n"
        printf "  ${RED}║${NC}                                                                          ${RED}║${NC}\n"
        printf "  ${RED}║${NC}     ${RED}✗${NC} ${WHITE}Extremely limited model capability${NC} (3B models only)              ${RED}║${NC}\n"
        printf "  ${RED}║${NC}     ${RED}✗${NC} ${WHITE}Poor code generation quality${NC}                                     ${RED}║${NC}\n"
        printf "  ${RED}║${NC}     ${RED}✗${NC} ${WHITE}Frequent errors and hallucinations${NC}                               ${RED}║${NC}\n"
        printf "  ${RED}║${NC}     ${RED}✗${NC} ${WHITE}No multi-model orchestration${NC} (single model only)                 ${RED}║${NC}\n"
        printf "  ${RED}║${NC}     ${RED}✗${NC} ${WHITE}Possible system instability${NC}                                      ${RED}║${NC}\n"
        printf "  ${RED}║${NC}                                                                          ${RED}║${NC}\n"
        printf "  ${RED}║${NC}   ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}   ${RED}║${NC}\n"
        printf "  ${RED}║${NC}                                                                          ${RED}║${NC}\n"
        printf "  ${RED}║${NC}   ${WHITE}STRONG RECOMMENDATION:${NC}                                                 ${RED}║${NC}\n"
        printf "  ${RED}║${NC}                                                                          ${RED}║${NC}\n"
        printf "  ${RED}║${NC}   Upgrade to a Mac with ${GREEN}32GB+ unified memory${NC} for:                       ${RED}║${NC}\n"
        printf "  ${RED}║${NC}     • Full OllamaBot experience                                          ${RED}║${NC}\n"
        printf "  ${RED}║${NC}     • State-of-the-art 32B models                                        ${RED}║${NC}\n"
        printf "  ${RED}║${NC}     • Multi-model AI orchestration                                       ${RED}║${NC}\n"
        printf "  ${RED}║${NC}     • Professional-grade code generation                                 ${RED}║${NC}\n"
        printf "  ${RED}║${NC}                                                                          ${RED}║${NC}\n"
        printf "  ${RED}║${NC}   Consider: MacBook Pro M3 Pro (36GB) or Mac Studio M2 Max (32GB+)       ${RED}║${NC}\n"
        printf "  ${RED}║${NC}                                                                          ${RED}║${NC}\n"
        printf "  ${RED}╚══════════════════════════════════════════════════════════════════════════╝${NC}\n"
        echo
        
        print_color "$RED" "  Are you SURE you want to continue with severely limited functionality?"
        print_color "$RED" "  Type 'I UNDERSTAND' to proceed (or press Enter to exit):"
        read -r confirm
        if [ "$confirm" != "I UNDERSTAND" ]; then
            print_color "$CYAN" "  Setup cancelled. Consider upgrading your Mac for the full experience."
            exit 0
        fi
        echo
        print_color "$YELLOW" "  Proceeding with MINIMAL tier (3B models)..."
        echo
        
    # ═══════════════════════════════════════════════════════════════════════════
    # LOW RAM WARNING (16-31GB)
    # ═══════════════════════════════════════════════════════════════════════════
        
    elif [ "$ram" -lt 32 ]; then
        echo
        printf "  ${RED}╔══════════════════════════════════════════════════════════════════╗${NC}\n"
        printf "  ${RED}║${NC}  ${YELLOW}⚠️  LOW RAM WARNING${NC}                                             ${RED}║${NC}\n"
        printf "  ${RED}╠══════════════════════════════════════════════════════════════════╣${NC}\n"
        printf "  ${RED}║${NC}                                                                  ${RED}║${NC}\n"
        printf "  ${RED}║${NC}  Your Mac has ${WHITE}${ram}GB RAM${NC}. OllamaBot is designed for ${WHITE}32GB+${NC}.      ${RED}║${NC}\n"
        printf "  ${RED}║${NC}                                                                  ${RED}║${NC}\n"
        printf "  ${RED}║${NC}  With less RAM, you will experience:                            ${RED}║${NC}\n"
        printf "  ${RED}║${NC}    • ${YELLOW}Slower inference${NC} (models may not fit in memory)            ${RED}║${NC}\n"
        printf "  ${RED}║${NC}    • ${YELLOW}Reduced model quality${NC} (smaller models have less capability)${RED}║${NC}\n"
        printf "  ${RED}║${NC}    • ${YELLOW}Limited multi-model coordination${NC}                           ${RED}║${NC}\n"
        printf "  ${RED}║${NC}                                                                  ${RED}║${NC}\n"
        printf "  ${RED}║${NC}  ${WHITE}Recommendation:${NC} Upgrade to a Mac with 32GB+ unified memory    ${RED}║${NC}\n"
        printf "  ${RED}║${NC}  for the full OllamaBot experience.                             ${RED}║${NC}\n"
        printf "  ${RED}║${NC}                                                                  ${RED}║${NC}\n"
        printf "  ${RED}╚══════════════════════════════════════════════════════════════════╝${NC}\n"
        echo
        
        print_color "$YELLOW" "  Do you want to continue with reduced capabilities? [y/N]"
        read -r continue_choice
        if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
            print_color "$CYAN" "  Setup cancelled. Consider upgrading your Mac for best results."
            exit 0
        fi
        echo
    fi
    
    # ═══════════════════════════════════════════════════════════════════════════
    # TIER SELECTION
    # ═══════════════════════════════════════════════════════════════════════════
    
    print_subheader "🎯 Model Tier Selection"
    echo
    print_color "$WHITE" "  Your Mac: ${CYAN}${ram}GB RAM${NC}"
    echo
    
    # Tier comparison table
    printf "  ${GRAY}┌────────────────────┬─────────┬─────────┬─────────┬──────────┐${NC}\n"
    printf "  ${GRAY}│${NC} ${WHITE}%-18s${NC} ${GRAY}│${NC} ${WHITE}%-7s${NC} ${GRAY}│${NC} ${WHITE}%-7s${NC} ${GRAY}│${NC} ${WHITE}%-7s${NC} ${GRAY}│${NC} ${WHITE}%-8s${NC} ${GRAY}│${NC}\n" \
        "Tier" "RAM" "Quality" "Speed" "Disk"
    printf "  ${GRAY}├────────────────────┼─────────┼─────────┼─────────┼──────────┤${NC}\n"
    
    # Maximum tier (128GB+)
    if [ "$ram" -ge 128 ]; then
        printf "  ${GRAY}│${NC} ${PURPLE}1)${NC} Maximum (70B+)   ${GRAY}│${NC} 128GB+  ${GRAY}│${NC} ████████ ${GRAY}│${NC} ██░░░░░ ${GRAY}│${NC} ~182GB  ${GRAY}│${NC} ${PURPLE}← ULTIMATE${NC}\n"
    else
        printf "  ${GRAY}│${NC} ${DIM}1) Maximum (70B+)${NC}   ${GRAY}│${NC} ${RED}128GB+${NC}  ${GRAY}│${NC} ████████ ${GRAY}│${NC} ██░░░░░ ${GRAY}│${NC} ~182GB  ${GRAY}│${NC}\n"
    fi
    
    # Advanced tier (64GB)
    if [ "$ram" -ge 64 ]; then
        local adv_rec=""
        if [ "$ram" -lt 128 ]; then adv_rec=" ${GREEN}← RECOMMENDED${NC}"; fi
        printf "  ${GRAY}│${NC} ${CYAN}2)${NC} Advanced (70B)   ${GRAY}│${NC} 64GB+   ${GRAY}│${NC} ███████░ ${GRAY}│${NC} ███░░░░ ${GRAY}│${NC} ~146GB  ${GRAY}│${NC}$adv_rec\n"
    else
        printf "  ${GRAY}│${NC} ${DIM}2) Advanced (70B)${NC}   ${GRAY}│${NC} ${RED}64GB+${NC}   ${GRAY}│${NC} ███████░ ${GRAY}│${NC} ███░░░░ ${GRAY}│${NC} ~146GB  ${GRAY}│${NC}\n"
    fi
    
    # Performance tier (32GB)
    if [ "$ram" -ge 32 ]; then
        local perf_rec=""
        if [ "$ram" -ge 32 ] && [ "$ram" -lt 64 ]; then perf_rec=" ${GREEN}← RECOMMENDED${NC}"; fi
        printf "  ${GRAY}│${NC} ${GREEN}3)${NC} Perform. (32B)   ${GRAY}│${NC} 32GB+   ${GRAY}│${NC} ██████░░ ${GRAY}│${NC} ████░░░ ${GRAY}│${NC} ~80GB   ${GRAY}│${NC}$perf_rec\n"
    else
        printf "  ${GRAY}│${NC} ${DIM}3) Perform. (32B)${NC}   ${GRAY}│${NC} ${RED}32GB+${NC}   ${GRAY}│${NC} ██████░░ ${GRAY}│${NC} ████░░░ ${GRAY}│${NC} ~80GB   ${GRAY}│${NC}\n"
    fi
    
    # Balanced tier (24GB)
    if [ "$ram" -ge 24 ]; then
        printf "  ${GRAY}│${NC} ${BLUE}4)${NC} Balanced (14B)   ${GRAY}│${NC} 24GB+   ${GRAY}│${NC} █████░░░ ${GRAY}│${NC} █████░░ ${GRAY}│${NC} ~36GB   ${GRAY}│${NC}\n"
    else
        printf "  ${GRAY}│${NC} ${DIM}4) Balanced (14B)${NC}   ${GRAY}│${NC} ${RED}24GB+${NC}   ${GRAY}│${NC} █████░░░ ${GRAY}│${NC} █████░░ ${GRAY}│${NC} ~36GB   ${GRAY}│${NC}\n"
    fi
    
    # Compact tier (16GB)
    if [ "$ram" -ge 16 ]; then
        printf "  ${GRAY}│${NC} ${YELLOW}5)${NC} Compact (7B)     ${GRAY}│${NC} 16GB+   ${GRAY}│${NC} ████░░░░ ${GRAY}│${NC} ██████░ ${GRAY}│${NC} ~18GB   ${GRAY}│${NC} ${YELLOW}(limited)${NC}\n"
    else
        printf "  ${GRAY}│${NC} ${DIM}5) Compact (7B)${NC}     ${GRAY}│${NC} ${RED}16GB+${NC}   ${GRAY}│${NC} ████░░░░ ${GRAY}│${NC} ██████░ ${GRAY}│${NC} ~18GB   ${GRAY}│${NC}\n"
    fi
    
    # Minimal tier (8GB)
    if [ "$ram" -ge 8 ]; then
        printf "  ${GRAY}│${NC} ${RED}6)${NC} Minimal (1.5B)   ${GRAY}│${NC} 8GB+    ${GRAY}│${NC} ██░░░░░░ ${GRAY}│${NC} ███████ ${GRAY}│${NC} ~5GB    ${GRAY}│${NC} ${RED}(EMERGENCY)${NC}\n"
    else
        printf "  ${GRAY}│${NC} ${DIM}6) Minimal (1.5B)${NC}   ${GRAY}│${NC} ${RED}8GB+${NC}    ${GRAY}│${NC} ██░░░░░░ ${GRAY}│${NC} ███████ ${GRAY}│${NC} ~5GB    ${GRAY}│${NC}\n"
    fi
    
    printf "  ${GRAY}└────────────────────┴─────────┴─────────┴─────────┴──────────┘${NC}\n"
    
    echo
    print_color "$WHITE" "  Tier Details:"
    echo
    print_color "$PURPLE" "  1) Maximum (70B+) - ULTIMATE POWER"
    print_color "$GRAY" "     • Llama 3.1 70B + Qwen2.5 72B simultaneously"
    print_color "$GRAY" "     • DeepSeek-Coder-V2 236B (MoE) - state of the art"
    print_color "$GRAY" "     • Parallel multi-model execution"
    print_color "$GRAY" "     • For Mac Studio / Mac Pro users"
    echo
    print_color "$CYAN" "  2) Advanced (70B) - PROFESSIONAL"
    print_color "$GRAY" "     • Qwen2.5 72B - flagship orchestration"
    print_color "$GRAY" "     • Command-R Plus 104B - deep research"
    print_color "$GRAY" "     • DeepSeek-Coder 33B - excellent coding"
    print_color "$GRAY" "     • For serious professional work"
    echo
    print_color "$GREEN" "  3) Performance (32B) - RECOMMENDED"
    print_color "$GRAY" "     • Best balance of quality and speed"
    print_color "$GRAY" "     • Full multi-model orchestration"
    print_color "$GRAY" "     • Ideal for most developers"
    echo
    print_color "$BLUE" "  4) Balanced (14B)"
    print_color "$GRAY" "     • Good quality, faster inference"
    print_color "$GRAY" "     • Suitable for many tasks"
    echo
    print_color "$YELLOW" "  5) Compact (7B) - LIMITED"
    print_color "$GRAY" "     • Reduced capability"
    print_color "$GRAY" "     • For constrained systems"
    echo
    print_color "$RED" "  6) Minimal (1.5B) - EMERGENCY ONLY"
    print_color "$GRAY" "     • ${RED}Very limited - testing/demo only${NC}"
    echo
    
    # Determine default based on RAM
    local default_num="6"  # Minimal fallback
    if [ "$ram" -ge 128 ]; then 
        default_num="1"  # Maximum for 128GB+
    elif [ "$ram" -ge 64 ]; then 
        default_num="2"  # Advanced for 64GB+
    elif [ "$ram" -ge 32 ]; then 
        default_num="3"  # Performance for 32GB+
    elif [ "$ram" -ge 24 ]; then 
        default_num="4"  # Balanced for 24GB
    elif [ "$ram" -ge 16 ]; then
        default_num="5"  # Compact for 16GB
    fi
    
    while true; do
        read -p "  Select tier [1-6] (default: $default_num): " -r tier_choice
        tier_choice="${tier_choice:-$default_num}"
        
        case "$tier_choice" in
            1)
                if [ "$ram" -lt 128 ]; then
                    print_color "$RED" "  ⚠ Your Mac has ${ram}GB RAM. Maximum tier needs 128GB+."
                    print_color "$RED" "  This will cause severe disk swapping."
                    print_color "$YELLOW" "  Are you absolutely sure? [y/N]"
                    read -r force
                    if [ "$force" != "y" ] && [ "$force" != "Y" ]; then
                        continue
                    fi
                fi
                SELECTED_TIER="maximum"
                break
                ;;
            2)
                if [ "$ram" -lt 64 ]; then
                    print_color "$RED" "  ⚠ Your Mac has ${ram}GB RAM. Advanced tier needs 64GB+."
                    print_color "$RED" "  70B models will swap heavily."
                    print_color "$YELLOW" "  Are you absolutely sure? [y/N]"
                    read -r force
                    if [ "$force" != "y" ] && [ "$force" != "Y" ]; then
                        continue
                    fi
                fi
                SELECTED_TIER="advanced"
                break
                ;;
            3)
                if [ "$ram" -lt 32 ]; then
                    print_color "$RED" "  ⚠ Your Mac has ${ram}GB RAM. Performance tier needs 32GB+."
                    print_color "$YELLOW" "  Models may run slowly. Continue anyway? [y/N]"
                    read -r force
                    if [ "$force" != "y" ] && [ "$force" != "Y" ]; then
                        continue
                    fi
                fi
                SELECTED_TIER="performance"
                break
                ;;
            4)
                if [ "$ram" -lt 24 ]; then
                    print_color "$RED" "  ⚠ Your Mac has ${ram}GB RAM. Balanced tier needs 24GB+."
                    print_color "$YELLOW" "  Models may run slowly. Continue anyway? [y/N]"
                    read -r force
                    if [ "$force" != "y" ] && [ "$force" != "Y" ]; then
                        continue
                    fi
                fi
                SELECTED_TIER="balanced"
                break
                ;;
            5)
                if [ "$ram" -lt 16 ]; then
                    print_color "$RED" "  ⚠ Your Mac has ${ram}GB RAM. Compact tier needs 16GB+."
                    print_color "$YELLOW" "  Models may run slowly. Continue anyway? [y/N]"
                    read -r force
                    if [ "$force" != "y" ] && [ "$force" != "Y" ]; then
                        continue
                    fi
                fi
                SELECTED_TIER="compact"
                break
                ;;
            6)
                if [ "$ram" -lt 8 ]; then
                    print_color "$RED" "  ⚠ Your Mac has ${ram}GB RAM. Even Minimal tier needs 8GB+."
                    print_color "$RED" "  OllamaBot cannot run on this system."
                    exit 1
                fi
                print_color "$RED" "  ⚠ WARNING: Minimal tier provides severely limited functionality."
                print_color "$YELLOW" "  Continue with Minimal tier? [y/N]"
                read -r force
                if [ "$force" != "y" ] && [ "$force" != "Y" ]; then
                    continue
                fi
                SELECTED_TIER="minimal"
                break
                ;;
            *)
                print_color "$YELLOW" "  Invalid choice. Please enter 1-6."
                ;;
        esac
    done
    
    echo
    print_status "$CHECK" "$GREEN" "Selected: $(echo "$SELECTED_TIER" | tr '[:lower:]' '[:upper:]') tier"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MODEL SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

select_models() {
    local ram
    ram=$(get_ram_gb)
    
    print_subheader "🎭 Model Selection"
    
    local disk_available
    disk_available=$(get_disk_space_gb "$HOME")
    local installed
    installed=$(get_installed_models)
    local tier_total
    tier_total=$(get_tier_total)
    
    echo
    print_color "$WHITE" "  Models for $(echo "$SELECTED_TIER" | tr '[:lower:]' '[:upper:]') tier:"
    echo
    
    # Get model info
    local model1 model2 model3 model4
    model1=$(get_model_name 1)
    model2=$(get_model_name 2)
    model3=$(get_model_name 3)
    model4=$(get_model_name 4)
    
    local size1 size2 size3 size4
    size1=$(get_model_size 1)
    size2=$(get_model_size 2)
    size3=$(get_model_size 3)
    size4=$(get_model_size 4)
    
    # Display models with importance indicators
    printf "  ${GRAY}┌─────┬───────────────────────────┬───────┬─────────────────────────────────┐${NC}\n"
    printf "  ${GRAY}│${NC} ${WHITE}#${NC}   ${GRAY}│${NC} ${WHITE}%-25s${NC} ${GRAY}│${NC} ${WHITE}Size${NC}  ${GRAY}│${NC} ${WHITE}Role${NC}                            ${GRAY}│${NC}\n" "Model"
    printf "  ${GRAY}├─────┼───────────────────────────┼───────┼─────────────────────────────────┤${NC}\n"
    
    for i in $(seq 1 $MODEL_COUNT); do
        local name size role desc status="" importance=""
        name=$(get_model_name $i)
        size=$(get_model_size $i)
        role=$(get_model_role $i)
        desc=$(get_model_desc $i)
        
        if echo "$installed" | grep -q "^${name}$"; then
            status=" ${GREEN}✓${NC}"
        fi
        
        # Set importance indicator
        case $i in
            1) importance="${GREEN}★ ESSENTIAL${NC}" ;;
            3) importance="${CYAN}★ RECOMMENDED${NC}" ;;
            2) importance="${GRAY}○ Optional${NC}" ;;
            4) importance="${GRAY}○ Optional${NC}" ;;
        esac
        
        printf "  ${GRAY}│${NC} ${WHITE}%d${NC}   ${GRAY}│${NC} %-25s ${GRAY}│${NC} %3dGB ${GRAY}│${NC} %s$status\n" \
            "$i" "$name" "$size" "$role"
        printf "  ${GRAY}│${NC}     ${GRAY}│${NC} ${GRAY}%-25s${NC} ${GRAY}│${NC}       ${GRAY}│${NC} %-20s\n" \
            "$desc" "$importance"
    done
    
    printf "  ${GRAY}└─────┴───────────────────────────┴───────┴─────────────────────────────────┘${NC}\n"
    
    echo
    print_color "$GRAY" "  Available disk: ${disk_available}GB"
    echo
    
    # ═══════════════════════════════════════════════════════════════════════════
    # MODEL RECOMMENDATIONS BASED ON RAM
    # ═══════════════════════════════════════════════════════════════════════════
    
    print_color "$WHITE" "  Model Selection Guide:"
    echo
    
    if [ "$ram" -ge 32 ]; then
        print_color "$GREEN" "  With ${ram}GB RAM, you can run all models effectively."
        print_color "$GRAY" "  Recommended: Full Suite for maximum capability."
    elif [ "$ram" -ge 24 ]; then
        print_color "$YELLOW" "  With ${ram}GB RAM, consider selecting 2-3 models."
        print_color "$GRAY" "  Recommended: Orchestrator + Coder (most useful combination)."
    else
        print_color "$RED" "  With ${ram}GB RAM, select only essential models."
        print_color "$GRAY" "  Recommended: Orchestrator only, add Coder if needed."
    fi
    
    echo
    print_color "$CYAN" "  Choose installation option:"
    echo
    print_color "$WHITE" "  A) Full Suite    - All 4 models (~${tier_total}GB)"
    print_color "$WHITE" "  B) Core Pair     - Orchestrator + Coder (~$((size1 + size3))GB) ${GREEN}← Most Useful${NC}"
    print_color "$WHITE" "  C) Research Pair - Orchestrator + Researcher (~$((size1 + size2))GB)"
    print_color "$WHITE" "  D) Minimal       - Orchestrator only (~${size1}GB)"
    print_color "$WHITE" "  E) Custom        - Choose specific models"
    echo
    
    # Check disk space for full suite
    if [ "$disk_available" -lt "$tier_total" ]; then
        print_color "$YELLOW" "  ⚠ Not enough disk for Full Suite. Consider a smaller option."
    fi
    
    read -p "  Your choice [A/B/C/D/E]: " -r choice
    echo
    
    local selected=""
    local selected_models=""
    
    case "$(echo "$choice" | tr '[:lower:]' '[:upper:]')" in
        A)
            selected="$model1 $model2 $model3 $model4"
            selected_models="Orchestrator, Researcher, Coder, Vision"
            ;;
        B)
            selected="$model1 $model3"
            selected_models="Orchestrator, Coder"
            ;;
        C)
            selected="$model1 $model2"
            selected_models="Orchestrator, Researcher"
            ;;
        D)
            selected="$model1"
            selected_models="Orchestrator"
            ;;
        E)
            echo
            print_color "$CYAN" "  Select models to install:"
            print_color "$GRAY" "  (Orchestrator will always be included)"
            echo
            
            # Interactive selection
            local include_researcher="n"
            local include_coder="n"
            local include_vision="n"
            
            read -p "  Include Researcher ($model2, ${size2}GB)? [y/N]: " -r include_researcher
            read -p "  Include Coder ($model3, ${size3}GB)? [y/N]: " -r include_coder
            read -p "  Include Vision ($model4, ${size4}GB)? [y/N]: " -r include_vision
            
            selected="$model1"
            selected_models="Orchestrator"
            
            if [ "$include_researcher" = "y" ] || [ "$include_researcher" = "Y" ]; then
                selected="$selected $model2"
                selected_models="$selected_models, Researcher"
            fi
            if [ "$include_coder" = "y" ] || [ "$include_coder" = "Y" ]; then
                selected="$selected $model3"
                selected_models="$selected_models, Coder"
            fi
            if [ "$include_vision" = "y" ] || [ "$include_vision" = "Y" ]; then
                selected="$selected $model4"
                selected_models="$selected_models, Vision"
            fi
            ;;
        *)
            print_color "$YELLOW" "  Invalid choice, defaulting to Core Pair (Orchestrator + Coder)"
            selected="$model1 $model3"
            selected_models="Orchestrator, Coder"
            ;;
    esac
    
    echo
    print_status "$CHECK" "$GREEN" "Selected: $selected_models"
    
    # Calculate total size
    local total_size=0
    for model in $selected; do
        case "$model" in
            "$model1") total_size=$((total_size + size1)) ;;
            "$model2") total_size=$((total_size + size2)) ;;
            "$model3") total_size=$((total_size + size3)) ;;
            "$model4") total_size=$((total_size + size4)) ;;
        esac
    done
    print_color "$GRAY" "  Total download: ~${total_size}GB"
    
    # Save configuration
    save_model_config "$selected"
    
    echo "$selected"
}

# Save model configuration for app to read
save_model_config() {
    local selected="$1"
    local ram
    ram=$(get_ram_gb)
    
    local model1 model2 model3 model4
    model1=$(get_model_name 1)
    model2=$(get_model_name 2)
    model3=$(get_model_name 3)
    model4=$(get_model_name 4)
    
    # Determine which models are selected
    local has_orchestrator="false"
    local has_researcher="false"
    local has_coder="false"
    local has_vision="false"
    
    for model in $selected; do
        case "$model" in
            "$model1") has_orchestrator="true" ;;
            "$model2") has_researcher="true" ;;
            "$model3") has_coder="true" ;;
            "$model4") has_vision="true" ;;
        esac
    done
    
    local config_dir="$HOME/.config/ollamabot"
    mkdir -p "$config_dir"
    
    cat > "$config_dir/tier.json" << EOF
{
    "tier": "$SELECTED_TIER",
    "ram_gb": $ram,
    "selected_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "models": {
        "orchestrator": $([ "$has_orchestrator" = "true" ] && echo "\"$model1\"" || echo "null"),
        "researcher": $([ "$has_researcher" = "true" ] && echo "\"$model2\"" || echo "null"),
        "coder": $([ "$has_coder" = "true" ] && echo "\"$model3\"" || echo "null"),
        "vision": $([ "$has_vision" = "true" ] && echo "\"$model4\"" || echo "null")
    },
    "enabled": {
        "orchestrator": $has_orchestrator,
        "researcher": $has_researcher,
        "coder": $has_coder,
        "vision": $has_vision
    }
}
EOF
    print_color "$GRAY" "  Configuration saved to $config_dir/tier.json"
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
    
    # Step 3.5: Tier Selection (RAM-aware)
    local ram
    ram=$(get_ram_gb)
    select_tier "$ram"
    
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
        local ram
        ram=$(get_ram_gb)
        select_tier "$ram"
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
