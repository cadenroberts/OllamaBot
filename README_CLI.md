# OllamaBot CLI (obot)

`obot` is a professional-grade Go CLI for local AI code fixes, autonomous orchestration, and session management. It shares configuration and session data with the OllamaBot macOS IDE.

## 🚀 Installation

```bash
# From the repository root
make build && make install
```

This installs the `obot` binary to `~/.local/bin` (ensure this is in your PATH).

## 🛠️ Usage

### Basic Code Fixes
Fix entire files or specific line ranges using the default quality preset (balanced).

```bash
obot main.go                     # Fix entire file
obot main.go -10 +25             # Fix lines 10-25
obot main.go "add error handling" # Fix with specific instruction
```

### 💬 Interactive Mode
Enter a multi-turn chat session with the AI directly in your terminal. This mode is perfect for brainstorming, exploring a file, or applying a series of changes.

```bash
obot main.go -i                  # Start interactive session for a specific file
obot -i                          # Start interactive session for the current directory
```

**Inside Interactive Mode:**
- Type your instructions naturally.
- The AI will provide suggestions and diffs.
- Use `/apply` to commit proposed changes.
- Use `/undo` to revert the last applied change.
- Use `/exit` or `Ctrl+C` to quit.

### New: Structured External Tools
Run project-aware linters, formatters, and tests.

```bash
obot lint path/to/file.go        # Run linter (e.g., go vet)
obot format path/to/file.go      # Run formatter (e.g., go fmt)
obot test path/to/file_test.go   # Run tests (e.g., go test)
```

### Advanced Orchestration
Launch the full 5-schedule autonomous orchestration engine.

```bash
obot orchestrate "Build a REST API"
```

The orchestrator follows the Unified Orchestration Protocol (UOP), progressing through Knowledge, Plan, Implement, Scale, and Production schedules.

## ✨ Quality Presets

Control the depth of AI reasoning and verification via the `--quality` flag.

- `fast`: Single-pass execution. Best for simple fixes.
- `balanced`: Plan → Execute → Review loop (Default).
- `thorough`: Plan → Execute → Review → Revise loop with Expert Judge verification.

```bash
obot main.go "refactor" --quality thorough
```

## 💾 Session & Checkpoint Management

Sessions are saved in the Unified Session Format (USF), allowing you to move between the CLI and IDE.

```bash
obot session list                # List all sessions
obot session show <id>           # View session history and stats
obot session export <id>         # Export session to JSON
obot session import <path>       # Import session from JSON
```

### 🔄 Session Resumption
Resume any previous orchestration session from where it left off.

```bash
obot orchestrate --resume <id>   # Resume a specific session
```

You can even start a session in the macOS IDE and finish it in the CLI, or vice-versa, thanks to the Unified Session Format (USF).

### Checkpoints
Save and restore the entire state of your workspace.

```bash
obot checkpoint save             # Create a new checkpoint
obot checkpoint list             # List available checkpoints
obot checkpoint restore <id>     # Restore workspace to a previous state
```

## ⚙️ Configuration

`obot` uses a unified YAML configuration located at `~/.config/ollamabot/config.yaml`.

```bash
obot config migrate              # Migrate legacy JSON config to YAML
obot config unified              # View active configuration
obot stats --saved               # View cost savings vs commercial APIs
```

## 🔍 Diagnostics & Telemetry

```bash
obot stats                       # Show system info, model assignments, and performance metrics
obot stats --saved               # View accumulated cost savings vs commercial APIs
obot --version                   # Show version and platform info
```

The `obot stats` command provides a comprehensive summary of your local AI performance, including:
- **First Token Latency**: Average time to start receiving responses.
- **Patch Success Rate**: Percentage of AI-generated edits that applied cleanly.
- **User Acceptance Rate**: Percentage of AI suggestions you accepted.
- **Median Time to Fix**: Typical duration for a successful code fix.
- **Resource Usage**: Real-time memory and token consumption.

### 💰 Cost Savings & Efficiency

The `obot stats --saved` command calculates how much you've saved by using local AI instead of commercial APIs (like GPT-4o or Claude 3.5 Sonnet).

- **Total Tokens Processed**: Lifetime count of input and output tokens.
- **Estimated Savings**: Dollar amount saved based on current market rates for comparable models.
- **Inference Efficiency**: Tokens per second and total compute time used.

> [!IMPORTANT]
> **Privacy Guarantee**: All telemetry data is stored strictly on your local machine at `~/.config/ollamabot/telemetry/stats.json`. No data is ever sent to external servers.
