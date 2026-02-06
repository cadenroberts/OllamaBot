# Master Plan: Worker sonnet-1 -- CLI (obot)

**Agent ID:** sonnet-1  
**Scope:** obot CLI (Go)  
**Rounds Active:** 0, 1, 2  
**Status:** Final recovered master

---

## Architectural Position

The obot CLI adopted the role of canonical execution engine ("Engine") in the Pragmatic Bridge architecture. All complex logic -- orchestration state machines, context management, model coordination, tool execution, session persistence -- resided in Go. The CLI operated standalone as a terminal tool and also exposed a JSON-RPC 2.0 server mode over stdio for consumption by the IDE.

---

## CLI-Specific Protocol Implementations

### UCS v2.1 (Configuration)

The CLI read shared configuration from ~/.ollamabot/config.yaml using gopkg.in/yaml.v3. A LoadUnifiedConfig() function parsed YAML, validated against the JSON schema, and applied CLI flag overrides. CLI-specific keys were honored; IDE-specific keys were ignored. A migration tool (obot config migrate) converted legacy ~/.config/obot/config.json to shared YAML with automatic backup.

### UTS v2.1 (Tool Registry)

The CLI loaded tool definitions from ~/.ollamabot/tools/registry.yaml and mapped them to its existing action system via alias resolution. All 22 tools were implemented natively in Go. Execution mode was always local when running standalone; when serving as IDE backend, tools executed on behalf of the IDE client.

Tools added to CLI from IDE: core.think, core.ask_user, file.search, file.list, ai.delegate.coder, ai.delegate.researcher, ai.delegate.vision, web.search, web.fetch, obot.execute_bot, obot.load_context.

### UCP v2.1 (Context)

A new internal/context/manager.go ported the IDE's ContextManager.swift logic to Go. Token budget allocation matched shared percentages. Semantic compression used preserve-patterns strategy. Conversation memory store with relevance scoring (keyword 40%, semantic 40%, recency 20%). Error pattern learning with occurrence tracking. Optional Rust library bindings for token counting (tiktoken-rs) and compression.

### UOP v2.0 (Orchestration)

The CLI's existing internal/orchestrate/ package already implemented the 5-schedule framework. Under harmonization it was enhanced with: flow code generation and regex validation, UOP v2.0 schema compliance, consultation timeout configuration from shared config, integration with multi-model coordinator.

### USF v2.0 (Sessions)

The CLI's existing internal/session/ package was enhanced to produce USF v2.0 compliant JSON. Session files written to ~/.ollamabot/sessions/{id}/session.json. Bash restoration scripts generated. Checkpoint snapshots stored as file hashes with git state. IDE sessions importable via obot session import. CLI sessions exportable via obot session export --format json.

---

## CLI Enhancements Adopted from IDE

- Multi-model coordination (4 models) via internal/ollama/coordinator.go
- Intent-based routing via keyword classification in model coordinator
- Token-budgeted context via internal/context/manager.go
- .obotrules support via internal/obot/parser.go
- @mention resolution via internal/mention/resolver.go
- Checkpoint system via internal/checkpoint/manager.go
- Web search and fetch tools via internal/tools/web.go
- AI delegation tools via internal/tools/delegation.go

---

## CLI Server Mode

obot server command started JSON-RPC 2.0 server over stdio. Read newline-delimited requests from stdin, wrote responses and streaming events to stdout. Supported methods: agent.execute, orchestration.start, orchestration.continue, context.build, session.save, session.load, health.check. Performance warmup on startup. Graceful shutdown on SIGINT/SIGTERM with session auto-save.

---

## CLI Package Consolidation

Package count reduced from 27 to 12: internal/agent (from actions+agent+recorder), internal/cli (from cli+theme), internal/config (from config+tier+model), internal/context (from context+summary), internal/fixer (from fixer+review+quality+analyzer), internal/git, internal/judge, internal/ollama (from ollama+coordinator), internal/orchestrate (from orchestrate+navigator+flowcode), internal/session (from session+stats), internal/ui (from ui+display+memory+ansi), internal/consultation.

---

## Performance Optimization

Optional Rust library bindings for token counting (tiktoken-rs CGO) and semantic compression. Multi-layer caching: L1 in-memory 50MB, L2 disk 500MB, semantic cache 100MB. Performance metrics collection for latency, compression ratios, cache hit rates, Rust library overhead.

---

## Migration Tooling

obot-migrate / obot config migrate handled: auto-detection of ~/.config/obot/config.json, YAML conversion with schema validation, automatic backup, session format migration to USF v2.0, validation report generation, rollback capability.

---

## CLI Artifact Inventory

| Round | Path |
|-------|------|
| 0 | plans_0/optimization-strategy-sonnet-1.md |
| 1 | plans_1/unified-implementation-strategy-sonnet-1.md |
| 2 | plans_2/definitive-technical-roadmap-sonnet-1.md |
| 2 | plans_2/OPTIMIZED-IMPLEMENTATION-STRATEGY-sonnet-1.md |

---

*End of CLI master plan for worker sonnet-1.*