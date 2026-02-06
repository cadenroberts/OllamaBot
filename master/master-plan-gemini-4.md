# Master Plan: gemini-4
## OllamaBot + obot Harmonization - Final Verified Position

**Agent:** gemini-4
**Model:** Claude Opus 4.6 (recovery context)
**Prior Model Context:** gemini-3-pro-preview (planning context)
**Rounds Participated:** 0, 1, 2, 3
**Status:** FLOW EXIT COMPLETE

---

## 1. Verified Position

After participating in Rounds 0 through 3 of the multi-agent consolidation loop, gemini-4 endorses the following as the definitive harmonization strategy:

- **Master Plan:** `final-master-plan-composer-2.md` (Round 2)
- **Architecture:** Go Bridge ("CLI as Engine, IDE as GUI")
- **Protocols:** 6 Unified Protocols (UOP, UTR, UCP, UMC, UC, USF)
- **Implementation:** 52 discrete plans (IMPL-01 through IMPL-52)

---

## 2. Architecture: Go Bridge + 6 Protocols

### 2.1 Core Decision

Reject Rust rewrite. Use obot (Go) as the shared execution engine. OllamaBot (Swift) becomes a lightweight UI client communicating via JSON-RPC.

### 2.2 The 6 Protocols

1. **UOP (Unified Orchestration Protocol):** 5-schedule state machine (Knowledge, Plan, Implement, Scale, Production) with strict 1-2-3 process navigation.
2. **UTR (Unified Tool Registry):** 22 canonical tools across 6 categories (Core, Files, System, Delegation, Web, Git).
3. **UCP (Unified Context Protocol):** Token budgeting with priority-based allocation (System 15%, Files 35%, Task 25%, History 12%, Memory 12%, Errors 2%).
4. **UMC (Unified Model Coordinator):** RAM-based tier detection combined with intent routing. Maps {Role}.{Tier} to specific model tags.
5. **UC (Unified Configuration):** Single shared config at ~/.ollamabot/config.yaml consumed by both CLI and IDE.
6. **USF (Unified State Format):** Portable session.json enabling seamless CLI-to-IDE and IDE-to-CLI handoff.

---

## 3. Implementation Scope (52 Items)

### Phase 1: Foundation (Weeks 1-4)
- IMPL-01: UOP Schema Definition
- IMPL-02: UTR Schema Definition
- IMPL-03: UCP Schema Definition
- IMPL-04: UMC Configuration Schema
- IMPL-05: UC Configuration Schema
- IMPL-06: USF State Schema

### Phase 2: CLI Enhancements (Weeks 3-8)
- IMPL-07: Enhanced Context Manager (Go port from Swift)
- IMPL-08: Intent Routing System
- IMPL-09: Multi-Model Delegation Support
- IMPL-10: Web Search Tool
- IMPL-11: Vision Model Integration
- IMPL-12: Advanced Git Tools
- IMPL-13: Think Tool for Planning
- IMPL-14: Ask User Tool with Timeout
- IMPL-15: File Search Capabilities
- IMPL-16: Sophisticated File Operations
- IMPL-17: Screenshot Integration
- IMPL-18: Quality Preset Enforcement
- IMPL-19: Human Consultation Framework
- IMPL-20: Session State Management (USF)
- IMPL-21: Configuration Migration to YAML

### Phase 3: IDE Enhancements (Weeks 5-8)
- IMPL-22: Orchestration Framework (UOP in Swift)
- IMPL-23: 5-Schedule Workflow UI
- IMPL-24: Process Navigation State Machine
- IMPL-25: Flow Code Tracking Display
- IMPL-26: Quality Preset Selection UI
- IMPL-27: Human Consultation Modal Dialogs
- IMPL-28: Line Range Editing Capabilities
- IMPL-29: Dry-Run Preview Mode
- IMPL-30: Cost Tracking Integration
- IMPL-31: Session Export/Import (USF)
- IMPL-32: Configuration Schema Compliance
- IMPL-33: Tool Validation Framework

### Phase 4: Shared Infrastructure (Weeks 7-10)
- IMPL-34: Unified Configuration Validator
- IMPL-35: Protocol Compliance Testing Framework
- IMPL-36: Cross-Product Session Converter
- IMPL-37: Schema Validation Libraries
- IMPL-38: Shared Error Handling Patterns
- IMPL-39: Performance Monitoring Integration
- IMPL-40: Documentation Generation System
- IMPL-41: Migration Tooling

### Phase 5: Quality and Testing (Weeks 9-12)
- IMPL-42: Protocol Compliance Test Suite
- IMPL-43: Feature Parity Validation Tests
- IMPL-44: Performance Regression Testing
- IMPL-45: Cross-Product Integration Tests
- IMPL-46: Schema Validation Tests
- IMPL-47: User Acceptance Testing Framework
- IMPL-48: Automated Quality Gates

### Phase 6: Documentation and Deployment (Weeks 11-12)
- IMPL-49: User Migration Guides
- IMPL-50: Developer Implementation Guides
- IMPL-51: Protocol Specification Documentation
- IMPL-52: Deployment and Rollout Strategy

---

## 4. Key Contributions by gemini-4

### Round 0
- Identified the "Engine & Cockpit" metaphor (obot is the engine, ollamabot is the cockpit).
- Proposed the Orchestration Protocol standard based on CLI's 5-schedule system.
- Proposed shared configuration at ~/.ollamabot/config.yaml.

### Round 1
- Consolidated Round 0 plans from Sonnet, Opus, Composer, and Gemini.
- Rejected Rust rewrite as too high-risk for March timeline.
- Adopted "Contract-First" approach (Opus/Sonnet) over "Rewrite" approach (Composer).
- Defined the "4 Pillars of Unity" (Config, Session, Orchestration, Tools).

### Round 2
- Endorsed final-master-plan-composer-2.md as the definitive master plan.
- Endorsed PLAN_TO_MAKE_ALL_PLANS.md as the coordination strategy.
- Generated all 52 implementation plans (IMPL-01 through IMPL-52).

### Round 3
- Monitored for late-arriving plans from other agents.
- Confirmed convergence with master-plan-gemini-7.md (Go Bridge consensus).
- No contradictions detected.

---

## 5. Success Metrics

- **Config Parity:** 100% of settings shareable between CLI and IDE.
- **Session Portability:** Zero data loss when switching interfaces.
- **Protocol Strictness:** IDE and CLI produce identical flow codes for identical tasks.
- **Tool Parity:** 22/22 tools available in both products.
- **Test Coverage:** 80% target for shared logic.
- **Performance:** No regression greater than 5%.

---

## 6. Artifacts Produced

| Artifact | Location |
|----------|----------|
| Round 0 Plan | obot/plans_0/plan-0-gemini-4.md |
| Round 0 Plan | ollamabot/plans_0/plan-0-gemini-4.md |
| Round 1 Plan | obot/plans_1/plan-1-gemini-4.md |
| Round 1 Plan | ollamabot/plans_1/plan-1-gemini-4.md |
| Round 2 Endorsement | obot/plans_2/plan-2-gemini-4.md |
| Round 2 Endorsement | ollamabot/plans_2/plan-2-gemini-4.md |
| Round 2 Flow Exit | obot/plans_2/FLOW_EXIT_GEMINI-4.md |
| Round 2 Flow Exit | ollamabot/plans_2/FLOW_EXIT_GEMINI-4.md |
| Round 3 Status | obot/plans_3/plan-3-gemini-4.md |
| Round 3 Status | ollamabot/plans_3/plan-3-gemini-4.md |
| 52 IMPL Plans | implementation_plans/IMPL-01 through IMPL-52 |
| This Master Plan | obot/master/master-plan-gemini-4.md |
| This Master Plan | ollamabot/master/master-plan-gemini-4.md |

---

**END OF MASTER PLAN gemini-4**
