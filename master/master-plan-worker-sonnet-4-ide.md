# Master Plan: sonnet-4 — OllamaBot IDE Harmonization

**Agent:** sonnet-4  
**Round:** 2  
**Product:** OllamaBot IDE (Swift/macOS)  
**Date:** 2026-02-05  

---

## Architecture

OllamaBot IDE becomes the "Cockpit" — a visualization and control layer that delegates execution to the obot Go core via JSON-RPC over stdio.

### Core Changes

**Remove (move logic to Go core):**
- OllamaService.swift — replaced by OBotClient.swift
- ContextManager.swift — replaced by RPC calls to Go context engine
- ModelTierManager.swift — replaced by RPC calls to Go tier detection
- OBotService.swift — replaced by RPC calls to Go bot engine

**Add:**
- CLIBridgeService.swift (~400 lines) — JSON-RPC client over stdio
- SharedConfigService.swift (~300 lines) — YAML config reader
- OrchestrationView.swift (~450 lines) — 5-schedule orchestration UI
- QualityPresetPicker.swift (~100 lines) — fast/balanced/thorough selector
- ConsultationView.swift (~200 lines) — human consultation modal with timeout

**Modify:**
- AgentExecutor.swift (+150 lines) — add orchestration mode with UOP state machine
- ChatView.swift (+50 lines) — quality preset selector integration
- MainView.swift (+100 lines) — orchestration panel and flow code display

### Swift Client Architecture

```swift
@Observable
final class OBotClient {
    private let process: Process
    private let rpcClient: JSONRPCClient

    func startSession(prompt: String) async throws -> SessionResponse
    func executeStep(step: AgentStep) async throws -> StepResult
    func getAvailableModels() async throws -> [Model]
    func updateConfiguration(_ config: Config) async throws
    func streamUpdates() -> AsyncThrowingStream<Update, Error>
}

@Observable
final class StreamingSession {
    let client: OBotClient
    @Published var currentState: SystemState
    @Published var messages: [ChatMessage]

    func processStream() async {
        for await chunk in try await client.streamResponse() {
            await MainActor.run {
                self.messages.append(chunk.toMessage())
            }
        }
    }
}
```

### Intelligent Bridge Routing (sonnet-4 innovation)

```swift
final class IntelligentCLIBridgeService {
    enum ExecutionStrategy {
        case local
        case delegated
        case hybrid
    }

    func executeTask(_ task: String, files: [String], quality: QualityPreset) async throws -> TaskResult {
        let complexity = analyzeTaskComplexity(task, files: files)
        let strategy = selectOptimalStrategy(complexity)
        switch strategy {
        case .local:
            return try await localAgentExecutor.execute(task, quality: quality)
        case .delegated:
            return try await obotServerExecutor.execute(task, quality: quality)
        case .hybrid:
            return try await hybridExecutor.execute(task, quality: quality)
        }
    }

    private func selectOptimalStrategy(_ indicators: ComplexityIndicators) -> ExecutionStrategy {
        switch (indicators.toolCount, indicators.hasMultiModel, indicators.multiFile) {
        case (1...3, false, false): return .local
        case (4...10, true, _):     return .delegated
        case (_, _, true):          return .hybrid
        default:                    return .delegated
        }
    }
}
```

---

## 6 Unified Protocols — IDE Responsibilities

### UCS (Unified Config Schema)
- Read from ~/.ollamabot/config.yaml
- Override with UserDefaults for UI-specific preferences (theme, font size)
- Validate against JSON Schema on load

### UTS (Universal Tool Specification)
- Normalize existing IDE tools to canonical IDs (write_file -> file.write)
- Support all 22+ tools via bridge delegation
- Local execution for simple tools, delegated for complex

### UCP (Unified Context Protocol)
- Delegate context building to Go core via RPC
- Display token budget usage in UI (context indicator)
- Pass file focus changes to engine for smart context updates

### UOP (Unified Orchestration Protocol)
- New OrchestrationView renders 5-schedule state machine
- Display flow code (S1P123S2P12) in status bar
- Support human consultation via modal dialogs with timeout

### UC (Unified Configuration)
- SharedConfigService reads unified YAML
- IDE-specific section (ide:) for theme, font, UI preferences
- Changes written back to shared config file

### USF (Unified State Format)
- CheckpointService updated to write USF JSON
- Session import/export for CLI handoff
- Session list UI showing both CLI and IDE sessions

---

## IDE-Specific Features Gained from Harmonization

1. 5-Schedule Orchestration — structured workflow from CLI
2. Quality Presets — fast/balanced/thorough/expert selection
3. Human Consultation — modal dialogs with timeout fallback
4. Flow Code Tracking — visual S1P123 flow display
5. Session Portability — open CLI sessions, export IDE sessions
6. LLM-as-Judge — code quality analysis from CLI
7. Performance Monitoring — real-time metrics dashboard

---

## Timeline (IDE Track)

| Week | Deliverables |
|------|-------------|
| 1 | SharedConfigService + YAML config loading |
| 2 | CLIBridgeService + JSON-RPC client |
| 3 | OrchestrationView + QualityPresetPicker + ConsultationView |
| 4 | Session portability + testing + polish |

---

## Success Metrics

- 90%+ feature parity with CLI capabilities
- 100% session portability (import/export)
- Sub-50ms RPC latency for bridge communication
- Zero regression in existing IDE functionality
- 80%+ test coverage for new bridge code
