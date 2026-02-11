# Evaluation

## Correctness Criteria

### Go CLI

| Criterion | Definition | Command |
|-----------|-----------|---------|
| Build succeeds | `make build` exits 0, produces `bin/obot` | `make build` |
| Version injection works | `./bin/obot --version` prints `obot version 1.0.0` | `./bin/obot --version` |
| All tests pass | 38/38 packages exit 0 | `go test ./internal/...` |
| Static analysis clean | `go vet` reports no issues | `go vet ./internal/...` |
| Dependencies consistent | `go mod tidy` produces no diff | `go mod tidy && git diff go.mod go.sum` |

### Swift IDE

| Criterion | Definition | Command |
|-----------|-----------|---------|
| Build succeeds | `swift build` exits 0 | `swift build` |
| Tests pass | `swift test` exits 0 | `swift test` |

## Smoke Test (No Ollama Required)

```bash
make build && ./bin/obot --version && go test ./internal/... && go vet ./internal/...
```

**Pass criteria:** All four commands exit 0. Version output matches `obot version 1.0.0`.

## Full Test (Ollama Required)

```bash
# Ensure Ollama is running
ollama serve &
ollama pull qwen3:32b

# Build and test
make build
go test -count=1 -cover ./internal/...

# Functional test: fix a file
echo 'package main\nfunc main() { fmt.Println("hello") }' > /tmp/test.go
./bin/obot /tmp/test.go "add missing import"

# Functional test: health scan
./bin/obot scan
```

**Pass criteria:** Build succeeds. All tests pass. Fix command produces a diff or patch. Scan command completes without error.

## Performance Expectations

| Metric | Target | Notes |
|--------|--------|-------|
| `make build` time | < 10s | On M1/M2 Mac |
| `go test ./internal/...` time | < 30s | Cached; ~60s cold |
| CLI startup (no Ollama) | < 100ms | Config load + flag parse |
| Code fix (balanced, small file) | < 60s | Depends on Ollama inference speed |
| Orchestration (5 schedules) | 10-60 min | Depends on task complexity and model speed |

## Coverage Targets

Current weighted average: ~30%.

| Package | Current | Target |
|---------|---------|--------|
| actions | 100.0% | 100% |
| router | 90.0% | 90% |
| process | 85.7% | 85% |
| telemetry | 85.6% | 85% |
| obotrules | 78.3% | 80% |
| scan | 70.0% | 75% |
| resource | 68.5% | 75% |
| fsutil | 65.5% | 70% |
| session | 56.6% | 60% |
| patch | 49.0% | 60% |
| index | 45.1% | 50% |
| agent | 22.4% | 40% |
| cli | 7.9% | 20% |
| ollama | 5.4% | 15% |
| judge | 0.0% | 10% |

## Pass/Fail Definitions

**PASS:** `make build` exits 0, `go test ./internal/...` reports 38/38 ok, `go vet` clean, `./bin/obot --version` prints correct version.

**FAIL:** Any of the above commands exits non-zero, or version output does not match the Makefile `VERSION` variable.
