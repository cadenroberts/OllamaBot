# 🤖 OllamaBot

<div align="center">

![OllamaBot Banner](https://img.shields.io/badge/OllamaBot-Local_AI_IDE-7dcfff?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiM3ZGNmZmYiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIj48cGF0aCBkPSJNMTggOGE2IDYgMCAwIDAtMTIgMGMwIDcgMTIgNyAxMiAwWiIvPjxjaXJjbGUgY3g9IjEyIiBjeT0iOCIgcj0iNiIvPjwvc3ZnPg==)

**A native macOS IDE with Infinite Mode — autonomous AI agents powered by local Ollama models**

[![macOS](https://img.shields.io/badge/macOS-14.0+-000000?style=flat-square&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![Ollama](https://img.shields.io/badge/Ollama-Local_AI-white?style=flat-square)](https://ollama.ai)
[![License](https://img.shields.io/badge/License-MIT-9ece6a?style=flat-square)](LICENSE)

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Architecture](#-architecture) • [Configuration](#-configuration)

</div>

---

## ✨ What Makes OllamaBot Different

Traditional AI coding tools wait for your commands. **OllamaBot's Infinite Mode** flips this paradigm:

- 🔄 **Autonomous Operation** — Give it a task, watch it work until completion
- 🧠 **Multi-Model Orchestration** — 4 specialized AI models working in coordination  
- 💻 **100% Local** — No API costs, no usage limits, complete privacy
- ⚡ **Apple Silicon Optimized** — Built for M1/M2/M3 performance

---

## 🎭 The Model Orchestra

OllamaBot coordinates four specialized 32B parameter models, each excelling at different tasks:

| Model | Role | Color | Specialization |
|-------|------|-------|----------------|
| **Qwen3 32B** | 🧠 Orchestrator | ![#bb9af7](https://via.placeholder.com/12/bb9af7/bb9af7.png) Purple | Thinking, planning, delegating tasks |
| **Command-R 35B** | 🔍 Researcher | ![#7aa2f7](https://via.placeholder.com/12/7aa2f7/7aa2f7.png) Blue | Research, RAG, documentation |
| **Qwen2.5-Coder 32B** | 💻 Coder | ![#ff9e64](https://via.placeholder.com/12/ff9e64/ff9e64.png) Orange | Code generation, debugging, refactoring |
| **Qwen3-VL 32B** | 👁️ Vision | ![#9ece6a](https://via.placeholder.com/12/9ece6a/9ece6a.png) Green | Image analysis, UI inspection |

---

## 🚀 Features

### 🔮 Infinite Mode (The Star Feature)

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

**13 Built-in Agent Tools:**

| Tool | Description |
|------|-------------|
| `think` | Plan and reason about the task |
| `read_file` | Read file contents |
| `write_file` | Create or overwrite files |
| `edit_file` | Search and replace in files |
| `search_files` | Search text across the codebase |
| `list_directory` | Explore directory structure |
| `run_command` | Execute shell commands |
| `ask_user` | Request user input |
| `delegate_to_coder` | Send coding tasks to Qwen-Coder |
| `delegate_to_researcher` | Send research tasks to Command-R |
| `delegate_to_vision` | Send image analysis to Qwen-VL |
| `take_screenshot` | Capture screen for vision analysis |
| `complete` | Signal task completion |

### 💬 Chat Mode

- Quick conversations with any model
- **Auto-routing** based on question type
- Manual model override with keyboard shortcuts
- Context-aware — includes open files and selections
- `@filename` mentions for additional context

### 🖥️ Full IDE

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

### ⚡ Performance Optimized

| Layer | Optimization |
|-------|-------------|
| **File I/O** | Memory-mapped for files >64KB |
| **Caching** | LRU with `os_unfair_lock` |
| **Search** | Parallel trigram + word indexing |
| **Ollama** | Task-specific temperature/tokens |
| **Memory** | Auto-clear under pressure |
| **Models** | Pre-warmed on launch |

---

## 📦 Installation

### Prerequisites

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** Mac (M1/M2/M3)
- **32GB RAM** minimum (for 32B models)
- **Ollama** installed

### Step 1: Install Ollama

```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

### Step 2: Pull the Models

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

### Step 3: Clone & Build

```bash
git clone https://github.com/cadenroberts/ollamabot.git
cd ollamabot

# Generate app icon (requires ImageMagick: brew install imagemagick)
./scripts/generate-icon.sh

# Build the app bundle
./scripts/build-app.sh --release
```

### Step 4: Install & Run

```bash
# Install to Applications
cp -r build/OllamaBot.app /Applications/

# Or run directly
open build/OllamaBot.app
```

Or for development:
```bash
swift run OllamaBot
```

Or open in Xcode:
```bash
open Package.swift
```

---

## 🎯 Usage

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

## 🏗️ Architecture

```
OllamaBot/
├── Sources/
│   ├── OllamaBotApp.swift           # App entry, state management
│   ├── Agent/
│   │   ├── AgentExecutor.swift      # Infinite Mode engine
│   │   └── AgentTools.swift         # 13 tool definitions
│   ├── Models/
│   │   ├── ChatMessage.swift        # Chat data model
│   │   ├── FileItem.swift           # File tree model
│   │   └── OllamaModel.swift        # Model enum + metadata
│   ├── Services/
│   │   ├── OllamaService.swift      # Ollama API client
│   │   ├── IntentRouter.swift       # Model routing logic
│   │   ├── ContextBuilder.swift     # Prompt construction
│   │   ├── FileIndexer.swift        # Background search index
│   │   ├── FileSystemService.swift  # File operations
│   │   └── ConfigurationService.swift
│   ├── Utilities/
│   │   ├── DesignSystem.swift       # UI components & tokens
│   │   ├── PerformanceCore.swift    # Caches, async I/O
│   │   ├── SyntaxHighlighter.swift  # Code highlighting
│   │   └── Benchmarks.swift         # Performance testing
│   └── Views/
│       ├── MainView.swift           # Main layout
│       ├── AgentView.swift          # Infinite Mode UI
│       ├── ChatView.swift           # Chat panel
│       ├── EditorView.swift         # Code editor
│       ├── TerminalView.swift       # Terminal emulator
│       └── ...
│
├── Resources/
│   ├── Info.plist                   # App bundle metadata
│   ├── AppIcon.icns                 # App icon
│   └── icon.svg                     # Source icon
│
├── scripts/
│   ├── build-app.sh                 # Build .app bundle
│   └── generate-icon.sh             # Generate .icns from SVG
│
├── Package.swift                    # Swift Package Manager
├── push.sh                          # Git push script
└── README.md
```

---

## ⚙️ Configuration

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

## 🎨 Design System

OllamaBot uses a **Tokyo Night**-inspired color palette:

```swift
// Core Colors
background:     #1a1b26  // Deep background
surface:        #1f2335  // Cards, panels
accent:         #7dcfff  // Brand cyan

// Model Colors  
orchestrator:   #bb9af7  // Purple (Qwen3)
researcher:     #7aa2f7  // Blue (Command-R)
coder:          #ff9e64  // Orange (Qwen-Coder)
vision:         #9ece6a  // Green (Qwen-VL)

// Semantic
success:        #9ece6a
warning:        #e0af68
error:          #f7768e
```

---

## 🔧 Troubleshooting

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

## 📊 Performance

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

## 🤝 Contributing

Contributions welcome! This is an experiment in local AI autonomy.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `swift build` to verify
5. Submit a pull request

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- [Ollama](https://ollama.ai) for making local LLMs accessible
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) for terminal emulation
- [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) for color inspiration

---

<div align="center">

**Built with ❤️ for local AI enthusiasts**

*Your AI should work FOR you, not wait ON you.*

</div>
