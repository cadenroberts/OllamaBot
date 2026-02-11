# Demo

## Prerequisites

| Requirement | Version | Install |
|-------------|---------|---------|
| macOS | 14.0+ (Sonoma) | - |
| Apple Silicon | M1/M2/M3/M4 | - |
| Go | 1.24+ | `brew install go` |
| Ollama | Latest | `curl -fsSL https://ollama.ai/install.sh \| sh` |
| RAM | 16GB minimum, 32GB recommended | - |

For full orchestration, pull the required models:

```bash
ollama pull qwen3:32b
ollama pull qwen2.5-coder:32b
ollama pull command-r:35b
ollama pull qwen3-vl:32b    # optional, for vision
```

## Smoke Path (No Ollama Required)

```bash
git clone https://github.com/cadenroberts/OllamaBot.git
cd OllamaBot

# Build the CLI binary
make build

# Verify version injection
./bin/obot --version
# Expected: obot version 1.0.0

# Run all tests
go test ./internal/...
# Expected: 38 lines of "ok" output, 0 "FAIL"

# Static analysis
go vet ./internal/...
# Expected: no output (clean)
```

**Expected final state:** `bin/obot` binary exists, version prints `1.0.0`, all 38 test packages pass, vet is clean.

## Full Demo (Ollama Required)

### Step 1: Start Ollama

```bash
ollama serve
```

Verify:

```bash
curl -s http://localhost:11434/api/tags | head -c 100
# Expected: JSON with "models" key
```

### Step 2: Build and verify

```bash
make build
./bin/obot --version
# Expected: obot version 1.0.0
```

### Step 3: Health scan

```bash
./bin/obot scan
```

Expected output includes: config status, Ollama connection status, available models, system RAM.

### Step 4: Fix a file

Create a test file:

```bash
cat > /tmp/demo.go << 'EOF'
package main

func main() {
    fmt.Println("hello world")
}
EOF
```

Fix it:

```bash
./bin/obot /tmp/demo.go "add the missing import statement"
```

Expected: The tool connects to Ollama, analyzes the file, and either applies a patch adding `import "fmt"` or prints the diff (depending on `--dry-run` / `--print` flags).

### Step 5: Interactive mode

```bash
./bin/obot /tmp/demo.go -i
```

Expected: Enters multi-turn chat. Type instructions, see diffs, use `/apply` to commit changes.

### Step 6: Project initialization

```bash
mkdir /tmp/demo-project && cd /tmp/demo-project
obot init
ls -la .obot/
# Expected: rules.obotrules, cache/
```

## IDE Demo

```bash
cd OllamaBot
swift build
swift run OllamaBot
```

Or open in Xcode:

```bash
open Package.swift
```

Expected: The macOS app launches with file explorer, editor, terminal, and chat panels. Infinite Mode is available via the toolbar button.

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `make build` fails with "go: not found" | Go not installed | `brew install go` |
| `./bin/obot scan` shows "Ollama Disconnected" | Ollama not running | `ollama serve` |
| `./bin/obot` fix hangs | Model not pulled | `ollama pull qwen3:32b` |
| `swift build` fails | Missing Xcode CLI tools | `xcode-select --install` |
| High memory usage during orchestration | Multiple 32B models loaded | Use `--model qwen3:32b` to limit to one model |
| Tests fail with timeout | Network-dependent test | Retry with `go test -count=1 ./internal/...` |
