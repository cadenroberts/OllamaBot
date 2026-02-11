# Unified Model Coordination (UMC)

The Unified Model Coordination protocol defines how tasks are routed to specific models based on the current schedule, process, and intent.

## 1. Model Roles

- **Orchestrator**: Planning, schedule selection, and process navigation.
- **Coder**: Code implementation, refactoring, and optimization.
- **Researcher**: RAG, information retrieval, and knowledge analysis.
- **Vision**: UI/UX polish, screenshot analysis, and visual consistency checks.

## 2. Routing Rules

- **Knowledge Schedule** → Researcher Model.
- **Plan/Implement/Scale Schedules** → Coder Model.
- **Production Harmonize** → Vision Model + Coder Model.
- **Any State Transition** → Orchestrator Model.

## 3. Fallback Chains

If a specialized model is unavailable or fails, the system follows a predefined fallback path:
1. `Vision` → `Coder`
2. `Researcher` → `Coder`
3. `Coder` → `Orchestrator`
4. `Orchestrator` → System Error / Suspension
