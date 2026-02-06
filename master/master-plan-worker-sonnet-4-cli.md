# Master Plan: sonnet-4 — obot CLI Harmonization

**Agent:** sonnet-4  
**Round:** 2  
**Product:** obot CLI (Go)  
**Date:** 2026-02-05  

---

## Architecture

obot CLI becomes the "Engine" — the single source of truth for orchestration, context management, model coordination, and tool execution. It gains a JSON-RPC server mode (`obot server`) that the IDE consumes.

### Core Changes

**New Files:**
- `cmd/server/main.go` (~300 lines) — JSON-RPC server entry point
- `internal/rpc/server.go` (~400 lines) — RPC message handling
- `internal/rpc/handlers.go` (~300 lines) — method handlers
- `internal/config/yaml.go` (~200 lines) — YAML config loader
- `internal/obotrules/parser.go` (~300 lines) — .obotrules parser
- `internal/mention/parser.go` (~200 lines) — @mention parser
- `internal/mention/resolver.go` (~300 lines) — mention resolution
- `pkg/context/manager.go` (~500 lines) — token-budgeted context (ported from IDE)
- `pkg/context/compression.go` (~200 lines) — semantic compression

**Modified Files:**
- `internal/config/config.go` (+100 lines) — add YAML support
- `cmd/cli/root.go` (+50 lines) — add `server` subcommand
- `internal/agent/tools.go` (+200 lines) — add missing tools

**Total: ~3,050 new lines + ~350 modified lines**

### JSON-RPC Server

```go
type OptimizedServer struct {
    orchestrator   *orchestrator.Engine
    contextManager *context.EnhancedManager
    sessionManager *session.Manager
    bridge         *bridge.IntelligentBridge
    metrics        *MetricCollector
}

// RPC Methods
func (s *OptimizedServer) handleRequest(ctx context.Context, req *RPCRequest) *RPCResponse {
    switch req.Method {
    case "agent.execute":
        return s.handleAgentExecute(ctx, req)
    case "orchestration.start":
        return s.handleOrchestrationStart(ctx, req)
    case "orchestration.continue":
        return s.handleOrchestrationContinue(ctx, req)
    case "context.build":
        return s.handleContextBuild(ctx, req)
    case "session.save":
        return s.handleSessionSave(ctx, req)
    case "session.load":
        return s.handleSessionLoad(ctx, req)
    case "health.check":
        return s.handleHealthCheck(ctx, req)
    default:
        return methodNotFound(req)
    }
}
```

**Server Modes:**
```bash
# Interactive mode for IDE
obot server --mode=interactive --format=json

# Batch mode for scripting
obot server --mode=batch --input=session.json

# Legacy CLI mode (unchanged)
obot main.go "fix the authentication"
```

### Enhanced Context Manager (ported from IDE)

```go
type EnhancedManager struct {
    config       *Config
    tokenizer    *Tokenizer
    compressor   *SemanticCompressor
    memoryStore  *MemoryStore
    errorLearner *ErrorLearner
}

func (em *EnhancedManager) BuildContext(task string, workDir string, files []string, history []Step) (*UCPContext, error) {
    ctx := &UCPContext{Version: "2.1"}
    ctx.Task = em.processTask(task)
    ctx.Files = em.processFiles(files, workDir)      // parallel loading with caching
    ctx.History = em.processHistory(history)
    ctx.Memory = em.processMemory(task)
    ctx.ErrorWarnings = em.processErrors(task, files)
    return ctx, em.validateTokenBudget(ctx)
}
```

Token budget allocation (from IDE excellence):
- System prompt: 7.1%
- Project rules: 3.6%
- Task description: 14.3%
- File content: 41.8%
- Project structure: 10.5%
- Conversation history: 14.0%
- Memory patterns: 5.2%
- Error warnings: 3.5%

### Intelligent Bridge (sonnet-4 innovation)

```go
type IntelligentBridge struct {
    orchestrator   *orchestrator.Engine
    contextManager *context.Manager
    localExecutor  Executor
    serverExecutor Executor
    hybridExecutor Executor
    metrics        *ExecutionMetrics
}

func (ib *IntelligentBridge) Execute(ctx context.Context, req *ExecutionRequest) (*ExecutionResult, error) {
    complexity := ib.analyzeComplexity(req)
    strategy := ib.selectStrategy(complexity, req.Preferences)
    switch strategy {
    case StrategyLocal:
        return ib.localExecutor.Execute(ctx, req)
    case StrategyServer:
        return ib.serverExecutor.Execute(ctx, req)
    case StrategyHybrid:
        return ib.hybridExecutor.Execute(ctx, req)
    }
    return nil, errors.New("unknown strategy")
}
```

---

## 6 Unified Protocols — CLI Responsibilities

### UCS (Unified Config Schema)
- Migrate from `~/.config/obot/config.json` to `~/.ollamabot/config.yaml`
- Automatic migration tool for existing users
- Validate against JSON Schema on load

### UTS (Universal Tool Specification)
- Add missing tools: think, ask_user, delegate.coder, delegate.researcher, delegate.vision, web.search, web.fetch, git.status, git.diff, git.commit
- Normalize action names to canonical IDs
- Generate Ollama tool definitions from registry

### UCP (Unified Context Protocol)
- Major new implementation: `pkg/context/manager.go` (~700 lines ported from Swift)
- Token budget allocation with semantic compression
- Conversation memory with relevance scoring
- Error pattern learning across sessions

### UOP (Unified Orchestration Protocol)
- Already implements 5-schedule system — validate against UOP schema
- Add schema validation for flow codes
- Expose orchestration state via RPC for IDE consumption

### UC (Unified Configuration)
- Primary owner of unified config file
- Read/write `~/.ollamabot/config.yaml`
- CLI-specific section (`cli:`) for verbose, colors, mem_graph

### USF (Unified State Format)
- Update session serialization to USF JSON schema
- Support session import from IDE format
- Add `obot session list`, `obot session resume`, `obot session export`

---

## CLI-Specific Features Gained from Harmonization

1. **Multi-Model Delegation** — delegate.coder, delegate.researcher, delegate.vision tools
2. **Advanced Context Management** — token budgeting, semantic compression, memory
3. **@Mention System** — @file:path, @bot:name, @context:id resolution
4. **.obotrules Support** — project-level bot definitions and rules
5. **Web Search Integration** — web.search and web.fetch tools
6. **Vision Model Support** — delegate.vision for image analysis
7. **Session Portability** — import/export sessions compatible with IDE

---

## OBot Rules Engine (new)

```go
type OBotEngine struct {
    rules     *OBotRules
    bots      map[string]*Bot
    templates map[string]*Template
    contexts  map[string]*ContextSnippet
}

func (engine *OBotEngine) ParseMention(input string) []Mention {
    // @file:path, @bot:name, @context:id, @codebase
}

func (engine *OBotEngine) ExecuteBot(name string, args []string) (*BotResult, error) {
    // Execute YAML-defined bots from .obot/bots/
}
```

---

## Migration Tool

```bash
obot migrate config    # Migrate config.json -> config.yaml
obot migrate sessions  # Migrate session files to USF format
obot migrate validate  # Validate migration completeness
obot migrate rollback  # Restore pre-migration state from backup
```

Features:
- Auto-detection of existing configurations
- Preview mode (--dry-run)
- Automatic backup before migration
- Validation after migration
- Rollback on failure

---

## Timeline (CLI Track)

| Week | Deliverables |
|------|-------------|
| 1 | YAML config + migration tool + protocol schemas |
| 2 | Enhanced context manager + obot server mode |
| 3 | Missing tools + .obotrules + @mention system |
| 4 | Session portability + testing + polish |

---

## Success Metrics

- 100% protocol schema compliance
- 90%+ feature parity with IDE capabilities
- 100% backward compatibility (existing commands unchanged)
- Sub-5% performance overhead from RPC bridge
- 80%+ test coverage for new code
- Zero breaking changes for existing CLI users
