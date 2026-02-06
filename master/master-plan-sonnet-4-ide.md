# Master Plan: OllamaBot IDE Harmonization

**Agent:** sonnet-4
**Date:** 2026-02-05
**Product:** OllamaBot IDE (Swift/SwiftUI)
**Scope:** IDE-side changes required for harmonization with obot CLI

---

## Current IDE State

- ~34,489 LOC Swift across 63 files
- 5 core modules: Agent, Models, Services, Utilities, Views
- 18+ tools in AgentExecutor.swift (read-write capable)
- 4-model orchestration: orchestrator (qwen3), coder (qwen2.5-coder), researcher (command-r), vision (qwen3-vl)
- Sophisticated ContextManager with token budgeting and semantic compression
- OBot ecosystem: .obotrules, bots, context snippets, templates
- Configuration via UserDefaults (macOS preferences)
- Session state: in-memory only, no persistence
- No orchestration framework (infinite loop + explore mode only)
- No quality presets
- No flow code tracking
- No cost tracking

## 6 Protocols — IDE Implementation Requirements

### 1. Unified Configuration (UC)

**Current:** UserDefaults (macOS property list, not portable)
**Target:** Read shared YAML config at `~/.ollamabot/config.yaml`, retain UserDefaults for IDE-only visual preferences

**New File:** `Sources/Services/SharedConfigService.swift`

```swift
@Observable
final class SharedConfigService {
    struct SharedConfig: Codable {
        var version: String
        var platform: PlatformConfig
        var models: ModelsConfig
        var quality: QualityConfig
        var context: ContextConfig
        var orchestration: OrchestrationConfig
    }

    private let configPath: URL  // ~/.ollamabot/config.yaml
    var config: SharedConfig

    func load() throws -> SharedConfig
    func save(_ config: SharedConfig) throws
    func watchForChanges()  // FSEvents watcher for hot-reload
}
```

**Modified File:** `Sources/Services/ConfigurationService.swift`
- Read shared settings from SharedConfigService
- Keep UserDefaults only for: theme, editor font size, window position, panel layout

### 2. Unified Tool Registry (UTR)

**Current:** 18 tools hardcoded in `Sources/Agent/AgentTools.swift`
**Target:** Load tool definitions from UTR schema, validate tool calls against registry

**New File:** `Sources/Agent/ToolValidator.swift`

```swift
struct ToolDefinition: Codable {
    let id: String          // e.g. "file.read"
    let name: String
    let platforms: [String] // ["cli", "ide"]
    let parameters: [ParameterDef]
}

final class ToolValidator {
    private let registry: [String: ToolDefinition]

    func validate(toolCall: ToolCall) -> Result<Void, ToolValidationError>
    func availableTools(for platform: String) -> [ToolDefinition]
}
```

**Modified File:** `Sources/Agent/AgentTools.swift`
- Normalize tool names to UTR canonical IDs
- Add missing tools: file.delete, git.push, core.note

### 3. Unified Context Protocol (UCP)

**Current:** ContextManager.swift with sophisticated token budgeting (already the reference implementation)
**Target:** Validate output against UCP JSON schema, add export capability for CLI consumption

**Modified File:** `Sources/Services/ContextManager.swift`

```swift
extension ContextManager {
    /// Export current context state as UCP-compliant JSON
    func exportUCP() throws -> Data {
        let context = UCPContext(
            version: "1.0",
            tokenBudget: currentBudget,
            files: relevantFiles,
            history: compressedHistory,
            memory: relevantMemories
        )
        return try JSONEncoder().encode(context)
    }

    /// Import context from CLI-generated UCP JSON
    func importUCP(from data: Data) throws {
        let context = try JSONDecoder().decode(UCPContext.self, from: data)
        // Restore state from imported context
    }
}
```

Token budget allocation (already implemented, now formalized):

| Section | Budget |
|---------|--------|
| System prompt | 7% |
| Project rules | 4% |
| Task description | 14% |
| File content | 42% |
| Project structure | 10% |
| Conversation history | 14% |
| Memory patterns | 5% |
| Error warnings | 4% |

### 4. Unified Orchestration Protocol (UOP)

**Current:** No orchestration framework. AgentExecutor runs infinite loop until `complete` tool called.
**Target:** Add orchestration mode alongside existing infinite/explore modes.

**New File:** `Sources/Services/OrchestratorService.swift`

```swift
@Observable
final class OrchestratorService {
    enum Schedule: Int, CaseIterable {
        case knowledge = 1
        case plan = 2
        case implement = 3
        case scale = 4
        case production = 5
    }

    enum Process: Int, CaseIterable {
        case p1 = 1, p2 = 2, p3 = 3
    }

    var currentSchedule: Schedule?
    var currentProcess: Process?
    var flowCode: String = ""

    func canNavigate(from: Process, to: Process) -> Bool {
        switch (from, to) {
        case (.p1, .p1), (.p1, .p2): return true
        case (.p2, .p1), (.p2, .p2), (.p2, .p3): return true
        case (.p3, .p2), (.p3, .p3): return true
        default: return false
        }
    }

    func appendFlowCode(schedule: Schedule, process: Process) {
        flowCode += "S\(schedule.rawValue)P\(process.rawValue)"
    }

    func canTerminate() -> Bool {
        currentSchedule == .production && currentProcess == .p3
    }
}
```

**New File:** `Sources/Views/OrchestrationView.swift`
- Schedule/process selector UI
- Flow code display (S1P123S2P12 format)
- Progress visualization

**New File:** `Sources/Views/FlowCodeView.swift`
- Visual flow code tracking

**New File:** `Sources/Views/ConsultationView.swift`
- Human consultation modal with countdown timer
- AI fallback after timeout

**Modified File:** `Sources/Agent/AgentExecutor.swift`
- Add orchestration mode alongside existing infinite mode and explore mode
- When orchestration mode active, delegate to OrchestratorService for schedule/process navigation

### 5. Unified Session Format (USF)

**Current:** In-memory only. SessionStateService auto-saves every 30s but no portable format.
**Target:** Save/load sessions in USF JSON format, compatible with CLI sessions.

**New File:** `Sources/Services/UnifiedSessionService.swift`

```swift
struct UnifiedSession: Codable {
    let version: String        // "1.0"
    let sessionId: String
    let createdAt: Date
    let sourcePlatform: String // "ide"
    let task: TaskDescription
    let workspace: WorkspaceInfo
    var orchestrationState: OrchestrationState?
    var conversationHistory: [Message]
    var filesModified: [String]
    var checkpoints: [Checkpoint]
    var stats: SessionStats
}

final class UnifiedSessionService {
    func save(_ session: UnifiedSession, to url: URL) throws
    func load(from url: URL) throws -> UnifiedSession
    func exportForCLI(_ session: UnifiedSession) throws -> Data
    func importFromCLI(_ data: Data) throws -> UnifiedSession
}
```

**Modified File:** `Sources/Services/SessionStateService.swift`
- Write USF format alongside existing auto-save
- Store at `~/.ollamabot/sessions/{session_id}.json`

**Modified File:** `Sources/Services/CheckpointService.swift`
- Include checkpoint data in USF session exports

### 6. Unified Model Coordinator (UMC)

**Current:** ModelTierManager.swift with 6 tiers, IntentRouter.swift for intent-based routing
**Target:** Read tier mappings from shared config instead of hardcoded values

**Modified File:** `Sources/Services/ModelTierManager.swift`
- Read model tier mappings from `~/.ollamabot/config.yaml` models section
- Fall back to hardcoded defaults if config unavailable

**Modified File:** `Sources/Services/IntentRouter.swift`
- Validate intent keywords against shared config
- Share keyword lists with CLI via config

---

## Additional IDE Features (From CLI)

### Quality Presets

**New File:** `Sources/Views/QualityPresetView.swift`

```swift
enum QualityPreset: String, CaseIterable, Codable {
    case fast       // Single pass, no verification
    case balanced   // Plan + execute + review
    case thorough   // Plan + execute + review + revise
}
```

### Cost Tracking

**New File:** `Sources/Services/CostTrackingService.swift`
- Track token usage per model
- Calculate savings vs commercial APIs (Claude, GPT-4)
- Display in status bar

### Dry-Run Preview

**New File:** `Sources/Services/PreviewService.swift`
- Show proposed file changes as diffs before applying
- Allow selective acceptance

### Line Range Editing

**Modified File:** `Sources/Views/EditorView.swift`
- Add line range selection for targeted agent edits
- Match CLI's `-start +end` syntax semantics

---

## IDE File Change Summary

| File | Action | Purpose |
|------|--------|---------|
| Sources/Services/SharedConfigService.swift | NEW | YAML config reader |
| Sources/Services/OrchestratorService.swift | NEW | 5-schedule orchestration |
| Sources/Services/UnifiedSessionService.swift | NEW | USF session persistence |
| Sources/Services/CostTrackingService.swift | NEW | Token cost tracking |
| Sources/Services/PreviewService.swift | NEW | Dry-run mode |
| Sources/Agent/ToolValidator.swift | NEW | UTR compliance |
| Sources/Views/OrchestrationView.swift | NEW | Orchestration UI |
| Sources/Views/FlowCodeView.swift | NEW | Flow code display |
| Sources/Views/ConsultationView.swift | NEW | Human consultation modal |
| Sources/Views/QualityPresetView.swift | NEW | Quality selector |
| Sources/Services/ConfigurationService.swift | MODIFY | Read shared config |
| Sources/Services/ContextManager.swift | MODIFY | Add UCP export/import |
| Sources/Services/ModelTierManager.swift | MODIFY | Read config tiers |
| Sources/Services/IntentRouter.swift | MODIFY | Share keywords via config |
| Sources/Services/SessionStateService.swift | MODIFY | Write USF format |
| Sources/Services/CheckpointService.swift | MODIFY | USF checkpoint export |
| Sources/Agent/AgentTools.swift | MODIFY | Normalize to UTR IDs |
| Sources/Agent/AgentExecutor.swift | MODIFY | Add orchestration mode |
| Sources/Views/EditorView.swift | MODIFY | Line range editing |

---

## Verification Criteria

- Shared config loads from `~/.ollamabot/config.yaml`
- All tool calls validate against UTR schema
- Context can be exported as UCP JSON and imported by CLI
- Orchestration mode runs 5-schedule framework with correct navigation rules
- Sessions save/load in USF format compatible with CLI
- Model selection reads tier mappings from shared config
- Quality presets (fast/balanced/thorough) available in UI
- Cost tracking displays token usage and savings
- Flow code tracks S{n}P{n} format correctly
