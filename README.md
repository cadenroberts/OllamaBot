# obot

**Local AI-powered code fixer CLI** — concentrate GPU power for quick code fixes without cloud APIs.

[![Go Version](https://img.shields.io/badge/Go-1.21+-00ADD8?style=flat&logo=go)](https://golang.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

```
╭─────────────────────────────────────────────────────╮
│             obot savings report                     │
├─────────────────────────────────────────────────────┤
│  Total tokens:     45,230                          │
│  Files fixed:      127                             │
│                                                     │
│  💰 Cost Savings vs Commercial APIs:               │
│  ─────────────────────────────────────             │
│  Claude Opus 4.5:  $3.84 saved                     │
│  Claude Sonnet:    $0.81 saved                     │
│  GPT-4o:           $1.02 saved                     │
╰─────────────────────────────────────────────────────╯
```

## Features

- **🚀 Zero cloud costs** — Uses local Ollama models, your code never leaves your machine
- **🎯 Smart model selection** — Auto-detects RAM and picks optimal coder model
- **⚡ Quick fixes** — One command to fix bugs, lint errors, add docs
- **💰 Cost tracking** — See how much you're saving vs Claude/GPT-4
- **📝 Line ranges** — Fix specific lines without touching the rest
- **💬 Interactive mode** — Multi-turn conversation for complex fixes

## Installation

### Quick Install (Recommended)

One command to install everything (Go, Ollama, model, and obot):

```bash
curl -fsSL https://raw.githubusercontent.com/croberts/obot/main/scripts/setup.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/croberts/obot.git
cd obot
./scripts/setup.sh
```

The setup script will:
1. Install Go (if not present)
2. Install Ollama (if not present)
3. Download the optimal coder model for your RAM
4. Build and install obot to `/usr/local/bin`

### Manual Installation

#### Prerequisites

1. **Go 1.21+** — Install from [golang.org](https://golang.org/dl/)
2. **Ollama** — Install from [ollama.ai](https://ollama.ai)
3. **Coder model** — Pull a model (auto-detected based on your RAM):

```bash
# For 32GB RAM (recommended)
ollama pull qwen2.5-coder:32b

# For 16GB RAM
ollama pull deepseek-coder:6.7b

# For 24GB RAM
ollama pull qwen2.5-coder:14b
```

#### Build from Source

```bash
git clone https://github.com/croberts/obot.git
cd obot
make install
```

#### Using Go Install

```bash
go install github.com/croberts/obot/cmd/obot@latest
```

## Usage

### Basic Usage

```bash
# Fix an entire file
obot main.go

# Fix with specific instruction
obot main.go "fix the null pointer dereference"

# Fix specific line range (lines 10-25)
obot main.go -10 +25

# Line range with instruction
obot main.go -10 +25 "add error handling"

# Increase generation quality (agentic plan + review)
obot main.go --quality thorough
```

### CLI Rules + Flags

See `CLI_RULES.md` for the full command contract and all rules. Highlights:

- `--dry-run`: do not write changes
- `--diff`: show unified diff before apply
- `--print`: print the fixed code to stdout
- `--temperature`, `--max-tokens`, `--context-window`: model controls
- `--mem-graph` / `OBOT_MEM_GRAPH=0`: memory graphic controls

### Memory Usage Graphic + Actions Summary

When obot runs, it shows a live memory usage bar and ends with a citation-based actions summary.
Disable the memory graphic by setting `OBOT_MEM_GRAPH=0`.

### Interactive Mode

```bash
obot main.go -i
```

Enter a multi-turn conversation to iteratively fix code:

```
obot> fix the error handling
[model output...]
Apply this fix? [y/N] y
✓ Fix applied

obot> now add logging
[model output...]
```

### View Cost Savings

```bash
obot --saved
# or
obot --stats
```

### Version Info

```bash
# Short version (includes platform)
obot --version

# Full build info
obot version
```

### Configuration

```bash
# Show current configuration
obot --config

# Override model
obot --model qwen2.5-coder:14b main.go

# List available models
obot models
```

### Quality Presets

`--quality` controls the agentic pipeline:

- `fast`: single-pass fix (no plan or review)
- `balanced` (default): plan + fix + review
- `thorough`: plan + fix + review + revise if reviewer flags issues

`obot` also runs a lightweight internal quality review and warns on suspicious output.

### Planning and Review (Local)

```bash
# Generate a concrete plan without calling a model
obot plan . "fix TODOs"

# Run lightweight local review checks
obot review .
```

## Model Tiers

obot automatically selects the best model for your system:

| RAM | Tier | Model | Quality | Speed |
|-----|------|-------|---------|-------|
| 8GB | Minimal | deepseek-coder:1.3b | ⭐⭐ | ⚡⚡⚡⚡⚡ |
| 16GB | Compact | deepseek-coder:6.7b | ⭐⭐⭐⭐ | ⚡⚡⚡⚡ |
| 24GB | Balanced | qwen2.5-coder:14b | ⭐⭐⭐⭐ | ⚡⚡⚡ |
| 32GB | Performance | qwen2.5-coder:32b | ⭐⭐⭐⭐⭐ | ⚡⚡ |
| 64GB+ | Advanced | deepseek-coder:33b | ⭐⭐⭐⭐⭐ | ⚡⚡ |

## Fix Types

obot automatically detects the type of fix needed, or you can specify:

- **Bug fixes** — `"fix the bug"`, `"fix null check"`
- **Lint errors** — `"fix lint"`, `"fix warnings"`
- **Refactoring** — `"refactor"`, `"clean up"`
- **TODO completion** — `"implement TODO"`, `"complete this"`
- **Optimization** — `"optimize"`, `"make faster"`
- **Documentation** — `"add docs"`, `"add comments"`
- **Type annotations** — `"fix types"`, `"add types"`

## Configuration File

Config is stored at `~/.config/obot/config.json`:

```json
{
  "tier": "performance",
  "model": "qwen2.5-coder:32b",
  "ollama_url": "http://localhost:11434",
  "verbose": true,
  "temperature": 0.3,
  "max_tokens": 4096
}
```

## API Pricing Reference

obot tracks savings vs these commercial API prices (per 1K tokens):

| Provider | Input | Output |
|----------|-------|--------|
| Claude Opus 4.5 | $0.015 | $0.075 |
| Claude Sonnet 3.5 | $0.003 | $0.015 |
| GPT-4o | $0.005 | $0.015 |

## Examples

### Fix a Go File

```bash
$ obot server.go "add error handling"

  obot v1.0.0
  Local AI code fixer

→ Checking Ollama connection...
→ Using model: qwen2.5-coder:32b
→ Reading server.go...
→ Fixing entire file (156 lines, Go)

Model thinking...
──────────────────────────────────────────────────
[streaming model output...]
──────────────────────────────────────────────────

→ Applying fix...

✓ Fixed server.go
   Tokens: 1,234 input + 567 output tokens
   Speed: 12.3 tokens/sec
   Time: 46.2s
```

### View Savings

```bash
$ obot --saved

╭─────────────────────────────────────────────────────╮
│             obot savings report                     │
├─────────────────────────────────────────────────────┤
│  Total tokens:     45,230                          │
│  Files fixed:      127                             │
│  Sessions:         34                              │
│                                                     │
│  💰 Cost Savings vs Commercial APIs:               │
│  ─────────────────────────────────────             │
│  Claude Opus 4.5:  $3.84 saved                     │
│  Claude Sonnet:    $0.81 saved                     │
│  GPT-4o:           $1.02 saved                     │
│                                                     │
│  📈 Monthly projection: $115/month (Opus rate)    │
│  🔒 Data kept local: 181 KB                        │
╰─────────────────────────────────────────────────────╯
```

## Orchestration Framework

obot includes a professional-grade orchestration system for complex agentic tasks.

### Launch Orchestration

```bash
# Start interactive orchestration
obot orchestrate

# Start with initial prompt
obot orchestrate "Build a REST API for user management"

# Create GitHub/GitLab repository alongside project
obot orchestrate --hub "my-api" "Build a REST API"
obot orchestrate --lab "my-api" "Build a REST API"

# Resume a previous session
obot orchestrate --session abc123
```

### Orchestration Architecture

The orchestration system operates through **5 schedules**, each containing **3 processes**:

| Schedule | Process 1 | Process 2 | Process 3 | Model |
|----------|-----------|-----------|-----------|-------|
| **Knowledge** | Research | Crawl | Retrieve | RAG |
| **Plan** | Brainstorm | Clarify* | Plan | Coder |
| **Implement** | Implement | Verify | Feedback** | Coder |
| **Scale** | Scale | Benchmark | Optimize | Coder |
| **Production** | Analyze | Systemize | Harmonize | Coder+Vision |

\* Human consultation allowed (on ambiguity)
\*\* Human consultation mandatory

### Navigation Rules

Processes follow strict **1↔2↔3** navigation:
- From P1: go to P1 (repeat) or P2
- From P2: go to P1, P2, or P3
- From P3: go to P2, P3, or terminate schedule

### Features

- **Live memory visualization** with predictive estimates
- **Human-in-the-loop** consultation with AI fallback (60s timeout)
- **Session persistence** with bash-only restoration (no AI required)
- **Full Git integration** (GitHub + GitLab)
- **LLM-as-judge** analysis with expert model reviews
- **Flow code tracking** (e.g., `S1P123S2P12`)

### Output Format

```
Orchestrator • Active
Schedule • Implement
Process • Verify
Agent • Ran go test ./... (exit 0)
```

### Prompt Summary

After completion, receive detailed statistics:
- Schedule/process execution counts
- Agent action breakdown (files created/edited/deleted)
- Resource usage (memory, disk, tokens)
- Generation flow with token recount
- LLM-as-judge TLDR with expert analysis

### Documentation

- `.cursor/commands/orchestrate.md` — Complete specification
- `ORCHESTRATION_PLAN.md` — Implementation details (Part 1)
- `ORCHESTRATION_PLAN_PART2.md` — Implementation details (Part 2)

## Structured Scaffolding Plan

See `SCALING_PLAN.md` for the architecture and product plan to compete with Claude Code.

## Building

```bash
# Build for current platform
make build

# Install to /usr/local/bin
make install

# Build for all platforms
make release

# Run tests
make test
```

## Troubleshooting

### "Cannot connect to Ollama"

Make sure Ollama is running:
```bash
ollama serve
```

### "Model not found"

Pull the required model:
```bash
ollama pull qwen2.5-coder:32b
```

### Slow Performance

- Ensure you're using the recommended model for your RAM
- Check that Ollama is using GPU acceleration
- Consider using a smaller model with `--model`

## Related Projects

- [ollamabot](https://github.com/croberts/ollamabot) — Full AI IDE with multi-model orchestration
- [Ollama](https://ollama.ai) — Run LLMs locally

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please read our contributing guidelines first.
