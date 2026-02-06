# Master Plan: sonnet-2 — OllamaBot IDE

**Agent:** sonnet-2  
**Product:** OllamaBot IDE (Swift/macOS)  
**Recovery Date:** 2026-02-06  

---

## Verified Artifacts Produced

| File | Bytes | Content |
|------|-------|---------|
| Sources/Services/HarmonyProtocol.swift | 15,838 | Complete Swift implementation of all 6 Unified Protocols |
| .obot/protocols/unified-orchestration.yaml | 3,440 | UOP v1.0 schema |
| .obot/protocols/unified-tool-registry.yaml | 8,348 | UTR v1.0 schema |
| .obot/protocols/unified-context.yaml | 3,032 | UCP v1.0 schema |
| .obot/protocols/unified-models.yaml | 4,160 | UMC v1.0 schema |
| .obot/protocols/unified-config.yaml | 4,548 | UC v1.0 schema |
| .obot/protocols/unified-state.yaml | 4,391 | USF v1.0 schema |

## HarmonyProtocol.swift Contents

Implements the following types with behavioral parity to the Go harmony package:

- `HarmonySchedule` — enum with 5 cases (knowledge, plan, implement, scale, production), each carrying process definitions and primary model role.
- `HarmonyProcess` — struct with id, name, and consultation requirement (none/optional/mandatory).
- `HarmonyNavigator` — static `isValidTransition(from:to:)` enforcing 1-2-3 adjacency rules. Static `canTerminatePrompt(scheduleCounts:lastSchedule:)` requiring all 5 schedules run and Production last.
- `HarmonyToolID` — enum with 22 cases matching canonical UTR tool IDs character-for-character with Go constants.
- `HarmonyModelRole` — enum: orchestrator, coder, researcher, vision.
- `HarmonyTier` — enum: minimal (8GB), compact (16GB), balanced (24GB), performance (32GB), advanced (64GB). Static `detect()` reads `ProcessInfo.processInfo.physicalMemory`. Static `fromRAM(_:)` uses identical thresholds to Go `TierFromRAM`.
- `HarmonyIntentRouter` — static `route(input:hasImage:hasCodeContext:)` with identical keyword lists and priority order as Go `IntentRoute`.
- `HarmonyConfig` — Codable struct matching UC v1.0 schema. Nested sections: OllamaSection, ModelsSection, GenerationSection, QualitySection, AgentSection, ContextSection, SessionSection, OrchestrationSection. Static `load()` checks project-local then global `~/.obot/config.yaml`.
- `HarmonySession` — Codable struct matching USF v1.0. Nested: OrchestrationState, ExecutionState, ActionRecord, NoteRecord, Stats. Instance `save()` writes JSON to `~/.obot/sessions/{id}/session.json`. Static `load(id:)` reads back.

## IDE-Specific Harmonization Items

### What the IDE gained from CLI via protocols
- 5-schedule orchestration framework (UOP) — IDE previously had only Infinite Mode and Explore Mode.
- Quality presets (fast/balanced/thorough) — defined in UC, not previously in IDE.
- Flow code tracking (S1P123 format) — defined in UOP.
- Human consultation with timeout and AI fallback — defined in UOP consultation types.
- Session persistence in portable JSON — IDE previously used in-memory only.

### What the IDE retains uniquely
- SwiftUI visual interface, syntax highlighting, file explorer, terminal.
- Multi-model delegation tools (delegate.coder, delegate.researcher, delegate.vision) — already implemented.
- @Mention system (14+ types) — already implemented in MentionService.swift.
- .obotrules and OBot system — already implemented in OBotService.swift.
- Checkpoint system — already implemented in CheckpointService.swift.
- Real-time streaming UI with frame-coalesced updates.
- take_screenshot tool (vision model input).

### IDE tech debt acknowledged
- AgentExecutor.swift at 1,069 lines — flagged by every agent as requiring split into OrchestratorEngine + ExecutionAgent.
- ContextManager.swift token counting uses `content.count / 4` heuristic — functional but imprecise.
- ConfigurationService.swift uses UserDefaults — needs to read shared YAML config for cross-product settings, retain UserDefaults only for IDE-specific visual preferences.

## Architectural Position

Protocols over code. The IDE implements the 6 Unified Protocols natively in Swift. No Rust FFI, no CLI-as-server bridge, no shared binaries. Behavioral equivalence is achieved through identical schemas and identical logic (same keyword lists, same RAM thresholds, same navigation truth tables) verified by matching Go and Swift implementations side by side.

---

*sonnet-2 | IDE master plan | 7 artifacts verified on disk*
