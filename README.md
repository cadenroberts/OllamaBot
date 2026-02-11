# OllamaBot

A native macOS IDE and Go CLI for local AI code fixes and orchestration, powered by Ollama.

- **Infinite Mode** — Autonomous agent that works until task completion
- **Explore Mode** — Continuous autonomous project improvement
- **Multi-Model Orchestration** — 4 specialized AI models (Orchestrator, Coder, Researcher, Vision)
- **100% Local** — No API costs, no usage limits, complete privacy
- **Offline-capable** — All models run locally via Ollama
- **Telemetry** — All session and usage data stored locally; no external reporting

---

## Model Roles

| Model | Role | Specialization |
|-------|------|----------------|
| Qwen3 32B | Orchestrator | Planning, task delegation |
| Command-R 35B | Researcher | Research, RAG, documentation |
| Qwen2.5-Coder 32B | Coder | Code generation, debugging, refactoring |
| Qwen3-VL 32B | Vision | Image analysis, UI inspection |

---

## Features

### Infinite Mode

```
┌─────────────────────────────────────────────────────────────┐
│                     YOU GIVE A TASK                         │
│           "Add user authentication to this app"             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              QWEN3 (ORCHESTRATOR) - The Brain               │
│                                                             │
│   Uses tools: think, read_file, search_files, list_dir,    │
│   delegate_to_coder, delegate_to_researcher, etc.          │
└─────────────────────────────────────────────────────────────┘
           ↓                    ↓                    ↓
    ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
    │ COMMAND-R    │   │ QWEN-CODER   │   │ QWEN3-VL     │
    │ (Research)   │   │ (Coding)     │   │ (Vision)     │
    └──────────────┘   └──────────────┘   └──────────────┘
                              ↓
              [Results fed back to Orchestrator]
                              ↓
                [Loop continues until complete]
```

**18 Agent Tools:**

| Category | Tool | Description |
|----------|------|-------------|
| **Core** | `think` | Plan and reason about the task |
| | `complete` | Signal task completion |
| | `ask_user` | Request user input |
| **Files** | `read_file` | Read file contents |
| | `write_file` | Create or overwrite files |
| | `edit_file` | Search and replace in files |
| | `search_files` | Search text across the codebase |
| | `list_directory` | Explore directory structure |
| **System** | `run_command` | Execute shell commands |
| | `take_screenshot` | Capture screen for vision analysis |
| **AI Delegation** | `delegate_to_coder` | Send coding tasks to Qwen-Coder |
| | `delegate_to_researcher` | Send research tasks to Command-R |
| | `delegate_to_vision` | Send image analysis to Qwen-VL |
| **Web** | `web_search` | Search the web via DuckDuckGo |
| | `fetch_url` | Fetch and extract web page content |
| **Git** | `git_status` | Get repository status |
| | `git_diff` | View file or repo diffs |
| | `git_commit` | Stage and commit changes |

### Explore Mode

Explore Mode continuously improves a project beyond a single task:

```
Original Goal: "Build a sandwich app"
     │
     ▼  EXPLORE CYCLE
┌────────────────────────────────────┐
│  1. UNDERSTANDING - Analyze codebase│
│  2. EXPANDING - Add new features    │
│  3. SPECIFYING - Edge cases, errors │
│  4. STANDARDIZING - Apply patterns  │
│  5. DOCUMENTING - Auto-update docs  │
│  6. REFLECTING - Plan next cycle    │
└────────────────────────────────────┘
     │
     ▼  REPEAT FOREVER
Basic deli app → Ordering system → Route optimization → ...
```

Configure via `.obotrules`:
```markdown
## Explore Mode Rules
- Maximum expansion depth: 3 levels
- Focus areas: [performance, features, testing]
- Auto-document after: 5 changes
- Expansion style: balanced
```

### Chat Mode

- Quick conversations with any model
- **Auto-routing** based on question type
- Manual model override with keyboard shortcuts
- Context-aware — includes open files and selections
- `@filename` mentions for additional context
- **Persistent chat history** — conversations saved across sessions

### IDE

- **File Explorer** with syntax-colored icons
- **Code Editor** with line numbers, syntax highlighting
- **Integrated Terminal** with PTY support
- **Multiple Tabs** with modification indicators
- **Breadcrumb Navigation**
- **Status Bar** with model/connection info
- **Command Palette** (`⌘⇧P`)
- **Quick Open** (`⌘P`)
- **Global Search** (`⌘⇧F`)
- **Find & Replace** (`⌘F` / `⌘⌥F`)
- **Go to Line** (`⌃G`)

### System Integration

- **RAM Monitoring** — Real-time memory tracking with Activity Monitor-like interface
- **Process Manager** — Force quit memory-hungry apps directly from OllamaBot
- **Network Aware** — Detects WiFi/Ethernet, gracefully degrades offline
- **Power Loss Recovery** — Auto-save state, recover interrupted sessions
- **Model Configuration** — Custom 1-4 model setups with performance analysis

### Resilience

- **Checkpoints** — Save/restore code states
- **Autosave** — State saved every 30 seconds while agents run
- **Graceful Degradation** — Works offline (all models are local)
- **Recovery Alert** — Offers to restore interrupted work on launch
- **Safe Operations** — Confirmation before destructive actions

### Performance

| Layer | Optimization |
|-------|-------------|
| **File I/O** | Memory-mapped for files >64KB |
| **Caching** | LRU with `os_unfair_lock` |
| **Search** | Parallel trigram + word indexing |
| **Ollama** | Task-specific temperature/tokens |
| **Memory** | Auto-clear under pressure |
| **Models** | Pre-warmed on launch |

---

## Installation

### One-Line Setup

```bash
git clone https://github.com/cadenroberts/OllamaBot.git && cd OllamaBot && ./scripts/setup.sh
```

The setup script will:
- Check system requirements (RAM, disk, macOS version)
- Test network speed and optimize download parallelism
- Calculate disk space for your model selection
- Install Ollama if needed
- Download models in parallel
- Build the macOS app
- Install to /Applications

### Prerequisites

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** Mac (M1/M2/M3)
- **32GB RAM** recommended (16GB minimum)
- **20-80GB disk space** (depending on model selection)

### Manual Installation

<details>
<summary>Click to expand manual steps</summary>

#### Step 1: Install Ollama

```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

#### Step 2: Pull the Models

```bash
# Orchestrator (required)
ollama pull qwen3:32b

# Research Model
ollama pull command-r:35b

# Coding Model
ollama pull qwen2.5-coder:32b

# Vision Model (optional)
ollama pull qwen3-vl:32b
```

#### Step 3: Clone & Build

```bash
git clone https://github.com/cadenroberts/OllamaBot.git
cd OllamaBot

# Generate app icon (requires ImageMagick: brew install imagemagick)
./scripts/generate-icon.sh

# Build the app bundle
./scripts/build-app.sh --release
```

#### Step 4: Install & Run

```bash
# Install to Applications
cp -r build/OllamaBot.app /Applications/

# Or run directly
open build/OllamaBot.app
```

</details>

### Setup Script Options

```bash
./scripts/setup.sh              # Full interactive setup
./scripts/setup.sh --diagnose   # System diagnostics only
./scripts/setup.sh --space      # Disk space analysis only
./scripts/setup.sh --models     # Download models only
./scripts/setup.sh --build      # Build app only
```

### Development Mode

```bash
swift build               # Build from source
swift run OllamaBot       # Run from source
open Package.swift        # Open in Xcode
```

### obot CLI (Go)

The repository also includes `obot`, a standalone Go CLI for local AI code fixes and orchestration. For full documentation, see [README_CLI.md](README_CLI.md).

```bash
# Build & Install
make build && make install

# Usage
obot main.go                     # Fix entire file (default: balanced quality)
obot main.go -10 +25             # Fix lines 10-25
obot main.go "add error handling" --quality fast  # Fast fix with instruction
obot main.go -i                  # Interactive multi-turn mode

# Advanced Orchestration
obot orchestrate "Build an API"  # Full 5-schedule autonomous orchestration
obot plan src/                   # Generate an implementation plan
obot review main.go              # Expert code review (Expert Judge system)

# Session & Checkpoint Management
obot session list                # List USF (Unified Session Format) sessions
obot session show <id>           # Inspect detailed session history
obot session export <id>         # Export session for use in IDE
obot checkpoint save             # Save a snapshot of the current code state
obot checkpoint list             # List all available checkpoints

# Configuration & Stats
obot config migrate              # Migrate legacy JSON config to unified YAML
obot config unified              # View active unified configuration
obot stats --saved               # View accumulated cost savings vs GPT-4/Claude

# Project Setup & Diagnostics
obot init                        # Scaffold .obot/ directory with rules templates
obot scan                        # Health check: config, Ollama, models, resources
obot models                      # List available Ollama models

# Code Index & Search
obot index build [path]          # Build local code index for fast lookup
obot search <query>              # Search indexed files and symbols
obot symbols <query>             # Search indexed symbols specifically

# Filesystem Helpers (scripted workflows)
echo "content" | obot fs write <path>   # Write stdin to file
obot fs delete <path> --force           # Delete file or directory
```

Build requires Go 1.24+ and a running Ollama instance. The CLI auto-detects system RAM to select the optimal model.

#### Quality Presets
The CLI supports the same quality presets as the IDE via the `--quality` flag:
- `fast`: Single-pass execution, optimized for speed.
- `balanced`: Plan → Execute → Review loop (default).
- `thorough`: Plan → Execute → Review → Revise loop with Expert Judge.

#### Unified Configuration

Both CLI and IDE read shared settings from `~/.config/ollamabot/config.yaml`:

```yaml
version: "2.0"
models:
  orchestrator: { default: "qwen3:32b" }
  coder:        { default: "qwen2.5-coder:32b" }
  researcher:   { default: "command-r:35b" }
  vision:       { default: "qwen3-vl:32b" }
quality:
  fast:     { iterations: 1, verification: "none" }
  balanced: { iterations: 2, verification: "llm_review" }
  thorough: { iterations: 3, verification: "expert_judge" }
context:
  max_tokens: 32768
  compression: { enabled: true, strategy: "semantic_truncate" }
orchestration:
  schedules: [knowledge, plan, implement, scale, production]
```

Migrate from the old JSON config with `obot config migrate`. A backward-compatible symlink from `~/.config/obot/` is created automatically.

---

## Usage

### Infinite Mode

1. Press `⌘⇧I` or click the **∞** button
2. Describe your task:
   - *"Add dark mode support to all views"*
   - *"Refactor this codebase to use async/await"*
   - *"Create unit tests for the user service"*
   - *"Document all public functions"*
3. Click **Start** and watch it work
4. **Stop** anytime to take control

### Chat Mode

Type in the chat panel on the right. The model auto-selects based on your question, or force a specific model:

| Shortcut | Model |
|----------|-------|
| `⌘⇧1` | Qwen3 (Writing) |
| `⌘⇧2` | Command-R (Research) |
| `⌘⇧3` | Qwen-Coder (Coding) |
| `⌘⇧4` | Qwen-VL (Vision) |
| `⌘⇧0` | Auto-route |

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘O` | Open folder |
| `⌘N` | New file |
| `⌘S` | Save file |
| `⌘P` | Quick open |
| `⌘⇧P` | Command palette |
| `⌘F` | Find in file |
| `⌘⇧F` | Search in files |
| `⌘⌥F` | Find and replace |
| `⌃G` | Go to line |
| `⌘B` | Toggle sidebar |
| `⌃\`` | Toggle terminal |
| `⌘⇧I` | Toggle Infinite Mode |

---

## Architecture

### Project Structure

```
OllamaBot/
├── Sources/                             # Swift macOS IDE (77 files)
│   ├── OllamaBotApp.swift               # App entry, state management
│   ├── Agent/                           # 9 files
│   │   ├── AgentExecutor.swift          # Infinite Mode engine
│   │   ├── AgentTools.swift             # 18 tool definitions
│   │   ├── AdvancedTools.swift          # Extended tool set (grep, glob, lint, etc.)
│   │   ├── AdvancedToolExecutor.swift   # Executor for advanced tools
│   │   ├── CycleAgentManager.swift      # Explore Mode cycle manager
│   │   └── ExploreAgentExecutor.swift   # Explore Mode engine
│   ├── Models/                          # 4 files
│   │   ├── ChatMessage.swift            # Chat data model (Codable)
│   │   ├── FileItem.swift               # File tree model
│   │   └── OllamaModel.swift           # Model enum + metadata
│   ├── Services/                        # 32 files
│   │   ├── OllamaService.swift          # Ollama API client + streaming
│   │   ├── ContextManager.swift         # Context budget + compression
│   │   ├── IntentRouter.swift           # Model routing logic
│   │   ├── FileIndexer.swift            # Background search index
│   │   ├── FileSystemService.swift      # File operations
│   │   ├── ConfigurationService.swift   # Persistent settings
│   │   ├── InlineCompletionService.swift # Tab completions
│   │   ├── GitService.swift             # Git integration
│   │   ├── WebSearchService.swift       # DuckDuckGo search
│   │   ├── ChatHistoryService.swift     # Persistent chat history
│   │   ├── CheckpointService.swift      # Save/restore code states
│   │   ├── ExternalLLMService.swift     # External LLM providers
│   │   ├── ExternalModelConfigurationService.swift # Provider config
│   │   ├── APIKeyStore.swift            # Secure API key storage
│   │   ├── MentionService.swift         # @mention resolution
│   │   ├── ModelTierManager.swift       # Model tier selection
│   │   ├── NetworkMonitorService.swift  # Connectivity detection
│   │   ├── OBotService.swift            # .obotrules + .obot/ system
│   │   ├── ResilienceService.swift      # Power loss recovery
│   │   ├── SessionStateService.swift    # Session persistence
│   │   ├── SystemMonitorService.swift   # RAM/CPU monitoring
│   │   ├── PricingService.swift         # Cost tracking
│   │   ├── PerformanceTrackingService.swift # Perf metrics
│   │   ├── PanelConfiguration.swift     # Panel layout config
│   │   ├── SharedConfigService.swift    # CLI/IDE unified config
│   │   ├── OrchestrationService.swift   # 5-schedule orchestration state
│   │   ├── ToolRegistryService.swift    # Tool registry
│   │   ├── PreviewService.swift         # Dry-run diff preview
│   │   └── UnifiedSessionService.swift  # Cross-platform session format
│   ├── Utilities/                       # 5 files
│   │   ├── DesignSystem.swift           # UI components & tokens
│   │   ├── PerformanceCore.swift        # LRU cache, async I/O
│   │   ├── SyntaxHighlighter.swift      # Code highlighting
│   │   ├── DSScrollView.swift           # Custom scroll view
│   │   └── Benchmarks.swift             # Performance testing
│   └── Views/                           # 27 files
│       ├── MainView.swift               # Main layout + overlay dialogs
│       ├── AgentView.swift              # Infinite Mode UI
│       ├── ChatView.swift               # Chat panel
│       ├── EditorView.swift             # Code editor
│       ├── TerminalView.swift           # Terminal emulator
│       ├── ExploreView.swift            # Explore Mode UI
│       ├── ComposerView.swift           # Multi-file composer
│       ├── CommandPaletteView.swift     # Command palette
│       ├── OutlineView.swift            # Symbol navigation
│       ├── ProblemsPanel.swift          # Errors/warnings
│       ├── OrchestrationView.swift      # 5-schedule orchestration UI
│       ├── CostDashboardView.swift      # Token usage & savings
│       ├── SessionHandoffView.swift     # Cross-platform session export/import
│       ├── PreviewView.swift            # Dry-run diff review
│       ├── ConsultationView.swift       # Human consultation modal
│       └── ...                          # +14 more views
│
├── cmd/obot/                            # Go CLI entry point
│   └── main.go                         # Binary entrypoint, wires version + cli.Execute()
├── internal/                            # Go CLI packages (38 packages)
│   ├── cli/                             # Commands (fix, plan, review, orchestrate, stats, checkpoint, session, config, scan, init, index, search, symbols, fs, models)
│   ├── ollama/                          # Ollama HTTP client + streaming
│   ├── fixer/                           # Code fix engine + quality presets
│   ├── orchestrate/                     # 5-schedule orchestration framework
│   ├── agent/                           # Agent executor + delegation + action recording
│   ├── analyzer/                        # File analysis + language detection
│   ├── config/                          # Configuration loading/defaults + unified YAML migration
│   ├── context/                         # Context budget, compression, memory, token management
│   ├── router/                          # Intent-based model routing
│   ├── session/                         # Session persistence + unified session format
│   ├── tools/                           # Git, web, tool registry
│   ├── tier/                            # System detection + model selection
│   ├── ui/                              # Terminal UI + memory graph
│   ├── stats/                           # Usage tracking + cost savings
│   └── ...                              # +14 more packages
│
├── Installer/                           # macOS installer app
│   ├── Package.swift
│   └── Sources/
│
├── website/                             # Marketing site
│   ├── index.html
│   └── css/js/assets
│
├── Resources/
│   ├── Info.plist                       # App bundle metadata
│   ├── AppIcon.icns                     # App icon
│   └── icon.svg                         # Source icon
│
├── scripts/
│   ├── setup.sh                         # Full interactive setup
│   ├── build-app.sh                     # Build .app bundle
│   ├── generate-icon.sh                 # Generate .icns from SVG
│   ├── rebuild.sh                       # Fast rebuild
│   └── update.sh                        # Pull + rebuild + relaunch
│
├── Package.swift                        # Swift Package Manager
├── go.mod                               # Go module definition
├── Makefile                             # Go CLI build system
└── README.md
```

### Context Management

AI models have limited context windows (8K-32K tokens). The context manager:
1. **Prioritize** what context to include (selected code > open files > project structure)
2. **Compress** large contexts without losing critical information
3. **Pass context** between the orchestrator and specialist models
4. **Remember** past interactions and learn from errors

### ContextManager Architecture

```
                    ┌─────────────────────────────────────┐
                    │           ContextManager            │
                    ├─────────────────────────────────────┤
                    │  • Token Budget Allocation          │
                    │  • Semantic Compression             │
                    │  • Inter-Agent Context Passing      │
                    │  • Conversation Memory              │
                    │  • Error Pattern Learning           │
                    └─────────────────────────────────────┘
                           │                    │
        ┌──────────────────┴───────┐ ┌─────────┴──────────────────┐
        │   OrchestratorContext    │ │    DelegationContext       │
        ├──────────────────────────┤ ├────────────────────────────┤
        │  • Task description      │ │  • Optimized for specialist│
        │  • Project structure     │ │  • Relevant files included │
        │  • Recent steps summary  │ │  • Context compressed      │
        │  • Relevant memories     │ │  • Model-specific prompts  │
        │  • Error warnings        │ │                            │
        └──────────────────────────┘ └────────────────────────────┘
```

### Token Budget Allocation

Each context section has a priority-based budget:

| Section | Priority | Max % of Budget |
|---------|----------|-----------------|
| **Task** | Critical | 25% |
| **File Content** | High | 33% |
| **Project** | High | 16% |
| **History** | Medium | 12% |
| **Memory** | Medium | 12% |
| **Errors** | High | 6% |

### Inter-Agent Context Flow

```
User Task: "Fix the authentication bug"
                    │
                    ▼
    ┌───────────────────────────────┐
    │   ORCHESTRATOR (Qwen3)        │
    │                               │
    │  ContextManager builds:       │
    │  • Full task + project map    │
    │  • Past relevant memories     │
    │  • Error warnings             │
    └───────────────────────────────┘
                    │
                    │ delegate_to_coder(task="Fix login validation")
                    ▼
    ┌───────────────────────────────┐
    │   CODER (Qwen2.5-Coder)       │
    │                               │
    │  ContextManager builds:       │
    │  • Task (compressed)          │
    │  • Relevant files (extracted) │
    │  • Specialist system prompt   │
    │  • NO orchestrator bloat      │
    └───────────────────────────────┘
                    │
                    │ Returns: Fixed code
                    ▼
    ┌───────────────────────────────┐
    │   ORCHESTRATOR (Qwen3)        │
    │                               │
    │  Records:                     │
    │  • Tool result for reference  │
    │  • Memory entry for future    │
    │  • Verifies output validity   │
    └───────────────────────────────┘
```

### Memory and Learning

The ContextManager maintains:

1. **Conversation Memory** - Past task/result pairs with relevance scoring
2. **Tool Results Buffer** - Recent 50 tool executions for reference
3. **Error Patterns** - Tracks recurring errors to warn the orchestrator

```swift
// Example: If "permissions" errors occur 2+ times, future tasks get warned:
"⚠️ WATCH OUT: Previously encountered issues with 'permissions'. Be careful."
```

### Streaming Performance

Naive implementation updates `@Observable` state on every token (~60/sec):
```swift
// ❌ BAD: 60 state mutations/sec = 60 SwiftUI diffs/sec = choppy UI
for try await chunk in stream {
    chatMessages[index].content += chunk
}
```

Frame-coalesced updates solve this:

```swift
// ✅ GOOD: Batch updates to 30fps (every 33ms)
var buffer = ""
var lastUpdate = CACurrentMediaTime()

for try await chunk in stream {
    buffer.append(chunk)
    
    if CACurrentMediaTime() - lastUpdate >= 0.033 {  // 30fps
        chatMessages[index].content = buffer  // Single diff
        lastUpdate = CACurrentMediaTime()
    }
}
```

Additional optimizations:

| Component | Optimization |
|-----------|-------------|
| **MessageRow** | `Equatable` conformance - only re-renders when content changes |
| **AssistantContentView** | Cached markdown parsing - reparse only on content change |
| **OllamaService** | Buffer tokens to ~50 chars before yielding |
| **Throttler** | Rate-limits scroll, resize, search events |
| **Debouncer** | Delays expensive operations (search, highlight) |

### Model Routing (IntentRouter)

The IntentRouter automatically selects the best model based on the user's question:

```swift
// Keyword-based classification
"How do I implement async/await?" → Coder (detected: "implement", "async", "await")
"What is quantum computing?"     → Researcher (detected: "what is")
"Write me a haiku about coding"  → Writing (detected: "write")
[Image attached]                 → Vision (automatic)
```

Priority order:
1. **Vision** - If images attached
2. **Coder** - Code keywords + code context open
3. **Researcher** - Question words, "explain", "compare"
4. **Writing** - Default for general tasks

### Tool Execution Pipeline

Agent tools execute in parallel when possible:

```
Tool Calls: [read_file(A), read_file(B), search_files(C)]
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    [Read File A]   [Read File B]   [Search Files]
           │               │               │
           └───────────────┼───────────────┘
                           ▼
              [Results aggregated & returned]
```

Non-parallelizable tools (write_file, run_command) execute sequentially.

---

## Configuration

Access settings via `⌘,` or the menu bar.

### Editor
- Font family & size
- Tab size & spaces
- Word wrap
- Line numbers
- Minimap
- Auto-close brackets
- Format on save

### AI
- Default model
- Temperature (0.0 - 1.0)
- Max tokens
- Context window size
- Include file context
- Stream responses

### Agent (Infinite Mode)
- Max steps limit
- Allow terminal commands
- Allow file writes
- Confirm destructive actions

### Appearance
- Theme (System/Light/Dark)
- Sidebar width
- Status bar visibility
- Breadcrumbs

---

## Design System

OllamaBot uses a **Tokyo Night**-inspired color palette with a **blue-only** unified theme:

```swift
// Core Colors
background:     #1a1b26  // Deep background
surface:        #1f2335  // Cards, panels
accent:         #7dcfff  // Brand cyan-blue
accentAlt:      #2ac3de  // Teal-blue

// Model Colors (Blue Spectrum)
orchestrator:   #7aa2f7  // Royal blue (Qwen3)
researcher:     #2ac3de  // Teal blue (Command-R)
coder:          #7dcfff  // Cyan blue (Qwen-Coder)
vision:         #5a8fd4  // Steel blue (Qwen-VL)

// Semantic (Blue variants)
success:        #73c0ff  // Light blue
info:           #7aa2f7  // Info blue
```

---

## Troubleshooting

### "Ollama Disconnected"
```bash
ollama serve
```

### Slow Model Switching
Normal — 32B models take ~30s to load. The orchestrator stays warm.

### High Memory Usage
Use **Debug → Clear Caches** or restart the app.

### Agent Seems Stuck
Check the step list — it may be thinking or waiting. Stop and retry with a more specific task.

---

## Performance

Run benchmarks: **Debug → Run Performance Benchmarks**

Typical results on M1 Max 32GB:

| Metric | Value |
|--------|-------|
| Cache ops | ~400,000/sec |
| File reads (small) | ~35,000/sec |
| File reads (1MB) | ~20/sec (mmap) |
| Parallel speedup | 3.5x |
| First AI response | ~instant (warmed) |

---

## License

MIT License — see [LICENSE](LICENSE) for details.
