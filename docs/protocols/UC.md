# Unified Configuration (UC)

The Unified Configuration protocol defines the shared configuration schema used by both the CLI and the IDE. It provides a structured way to manage model assignments, resource limits, and platform-specific behaviors.

## 1. Schema (YAML)

The configuration is stored in `ollamabot.config.yaml` (typically in `~/.config/ollamabot/`).

```yaml
version: "2.0"

# Model role assignments and tier mappings
models:
  tier_detection:
    auto: true
    thresholds:
      minimal: [0, 15]
      balanced: [24, 31]
  orchestrator:
    default: "qwen3:32b"
    tier_mapping:
      minimal: "qwen3:8b"
  coder:
    default: "qwen2.5-coder:32b"
  researcher:
    default: "command-r:35b"
  vision:
    default: "qwen3-vl:32b"

# Orchestration behavior
orchestration:
  default_mode: "orchestration"
  schedules:
    - id: "knowledge"
      processes: ["research", "crawl", "retrieve"]
      model: "researcher"
    - id: "plan"
      processes: ["brainstorm", "clarify", "plan"]
      model: "coder"

# Context and token management
context:
  max_tokens: 32768
  budget_allocation:
    task: 0.25
    files: 0.33
    history: 0.12
  compression:
    enabled: true
    strategy: "semantic_truncate"

# Quality presets for execution pipelines
quality:
  fast: {iterations: 1, verification: "none"}
  balanced: {iterations: 2, verification: "llm_review"}
  thorough: {iterations: 3, verification: "expert_judge"}

# Platform-specific settings
platforms:
  cli:
    verbose: true
    mem_graph: true
  ide:
    theme: "dark"
    font_size: 14

# Ollama connection settings
ollama:
  url: "http://localhost:11434"
  timeout_seconds: 120
```

## 2. Platform Mapping

- **CLI**: Reads from `~/.config/ollamabot/config.yaml`. Provides automatic migration from legacy `config.json`.
- **IDE**: Synchronizes with the shared YAML configuration. Uses `UserDefaults` or native settings only for UI-specific preferences that do not affect orchestration results.

## 3. Migration Policy

When a legacy `config.json` is detected:
1. Load legacy values.
2. Map to equivalent fields in the `UnifiedConfig` struct.
3. Save as `config.yaml`.
4. Create a backup of the original file.
5. Create a backward-compatibility symlink if necessary.
