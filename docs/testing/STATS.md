# Testing Statistics — OllamaBot

> Generated: 2026-02-10 | Scope: CLI (Go) + IDE (Swift)

## Summary

| Metric | Value |
|---|---|
| Total source LOC (Go) | 26,173 |
| Total source LOC (Swift) | 38,656 |
| Total test LOC (Go) | 2,114 |
| Total test LOC (Swift) | 81 |
| Test-to-source ratio (Go) | 8.1% |
| Test-to-source ratio (Swift) | 0.2% |
| Go test files | 23 |
| Swift test files | 2 |
| Go test functions | 57 |
| Go packages total | 40 |
| Go packages with tests | 15 (37.5%) |
| Go packages without tests | 25 (62.5%) |

## Go Package Coverage Matrix

### Packages WITH Tests (15)

| Package | Source LOC | Test File(s) | Test Funcs | Coverage Target |
|---|---|---|---|---|
| agent | 2,008 | executor_test, plugins_test | 3 | 90% |
| analyzer | 570 | language_test | 4 | — |
| consultation | 422 | handler_test | 3 | — |
| fixer | 1,029 | extract_test | 3 | 85% |
| git | 640 | github_test | 2 | — |
| index | 762 | index_test, language_test | 4 | — |
| integration | — | search_test, patch_test | 2 | — |
| orchestrate | 1,866 | types_test | 6 | 80% |
| patch | 360 | patch_test, validate_test, rollback_test, backup_test | 5 | — |
| session | 1,891 | manager_test, cross_platform_test, notes_test | 5 | 75% |
| stats | 344 | savings_test | 4 | — |
| telemetry | 153 | service_test | 1 | — |
| test | 129 | golden_test | 3 | — |
| tier | 332 | detect_test | 4 | — |
| ui | 1,751 | memory_test | 8 | 60% |

### Packages WITHOUT Tests (25)

| Package | Source LOC | Priority | Rationale |
|---|---|---|---|
| cli | 3,013 | **HIGH** | Largest untested; user-facing entry points |
| context | 1,100 | **HIGH** | Token budgeting, memory — correctness-critical |
| judge | 1,042 | **HIGH** | Quality coordination — correctness-critical |
| schedule | 823 | **HIGH** | Recurrence/factory logic — state machine |
| ollama | 814 | **HIGH** | LLM client — integration boundary |
| tools | 735 | **HIGH** | Registry + exec — agent foundation |
| error | 784 | MEDIUM | Error recovery paths |
| config | 688 | MEDIUM | Defaults, validation, migration |
| resource | 565 | MEDIUM | Monitor — system boundary |
| summary | 507 | MEDIUM | Generator — LLM dependent |
| model | 474 | MEDIUM | Coordinator — integration boundary |
| planner | 389 | MEDIUM | Plan decomposition |
| scan | 426 | MEDIUM | Code scanning |
| obotgit | 389 | LOW | Git abstraction |
| intent | 381 | LOW | Intent detection |
| obotrules | 277 | LOW | Rules engine |
| mention | 299 | LOW | Mention parsing |
| review | 256 | LOW | Review logic |
| delegation | 237 | LOW | Delegation routing |
| monitor | 226 | LOW | Resource monitoring |
| oberror | 314 | LOW | Error types |
| actions | 100 | LOW | Thin action wrappers |
| router | 101 | LOW | Routing logic |
| process | 145 | LOW | Process management |
| fsutil | 105 | LOW | FS utilities |
| version | 140 | LOW | Version info |

## Swift (IDE) Test Status

| Component | Test File | LOC | Status |
|---|---|---|---|
| Models | OllamaModelTests.swift | 14 | Stub only |
| Services | OrchestrationServiceTests.swift | 67 | Minimal |

**Gap**: No tests for AgentExecutor, AgentTools, CostTrackingService, DelegationHandler, ErrorRecovery, QualityPresetService, VerificationEngine, SharedConfigService, PreviewService, UnifiedSessionService, ToolRegistryService, PerformanceTrackingService, or any Views.

## 12 Priority Testing Items

Based on coverage targets, source LOC, and risk:

| # | Item | Package(s) | Est. LOC | Weeks (2 dev) |
|---|---|---|---|---|
| 1 | CLI command tests | cli | 800 | 1.0 |
| 2 | Context budget + memory | context | 600 | 0.5 |
| 3 | Judge coordinator | judge | 500 | 0.5 |
| 4 | Schedule factory + recurrence | schedule | 400 | 0.5 |
| 5 | Ollama client mocking | ollama | 500 | 0.5 |
| 6 | Tool registry + execution | tools | 500 | 0.5 |
| 7 | Config validation + migration | config | 400 | 0.5 |
| 8 | Error recovery paths | error | 400 | 0.5 |
| 9 | Agent executor expansion | agent | 600 | 0.5 |
| 10 | Orchestrator expansion | orchestrate | 500 | 0.5 |
| 11 | Session state + manager | session | 400 | 0.5 |
| 12 | Swift IDE test bootstrap | Sources/* | 1,400 | 1.0 |
| | **TOTAL** | | **7,100** | **6.5** |

## Gap Analysis: Current → Target

| Coverage Target Zone | Current State | Gap |
|---|---|---|
| Agent Execution (90%) | 3 funcs / ~2000 LOC | ~70% uncovered |
| Tools (85%) | 0 funcs / 735 LOC | 100% uncovered |
| Context (80%) | 0 funcs / 1100 LOC | 100% uncovered |
| Orchestration (80%) | 6 funcs / ~1866 LOC | ~60% uncovered |
| Fixer (85%) | 3 funcs / 1029 LOC | ~50% uncovered |
| Sessions (75%) | 5 funcs / 1891 LOC | ~50% uncovered |
| UI (60%) | 8 funcs / 1751 LOC | ~40% uncovered |

## Test Infrastructure

- **Golden testing**: `internal/test/golden.go` — functional, 3 test funcs
- **Integration tests**: `internal/integration/` — 2 test files (search, patch)
- **Swift test target**: Present in `Tests/` but not wired in `Package.swift`
- **CI coverage command**: `go test -coverprofile=coverage.out ./...`
- **Golden update**: `UPDATE_GOLDEN=true go test ./internal/...`

## Recommendations

1. Wire Swift test target in `Package.swift` immediately (blocker for items 12).
2. Start with items 2 (context) and 6 (tools) — highest coverage-gap-to-effort ratio.
3. Use table-driven tests throughout for consistency with existing patterns.
4. Add integration test for full CLI round-trip (item 1).
5. Establish `go test -coverprofile` in CI before adding tests, so progress is measurable.
