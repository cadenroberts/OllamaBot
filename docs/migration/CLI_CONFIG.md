# CLI Configuration Migration Guide

This guide explains how to migrate your OllamaBot configuration from the legacy JSON format (`config.json`) to the new unified YAML format (`config.yaml`).

## 1. Why Migrate?

The new YAML-based configuration provides:
- **Unified Settings**: Shared configuration between the CLI and the IDE.
- **Model Roles**: Better control over which models are used for different tasks (Orchestrator, Coder, Researcher, Vision).
- **Quality Presets**: Structured presets for Fast, Balanced, and Thorough execution.
- **Improved Context Management**: Granular control over token budgets and compression.
- **Orchestration Control**: Customizable schedules and processes.

## 2. Automatic Migration

OllamaBot version 2.0+ automatically attempts to migrate your configuration on the first run.

- **System-wide**: `~/.config/obot/config.json` → `~/.config/ollamabot/config.yaml`
- **Project-local**: `config/obot-config.json` → `config/ollamabot-config.yaml`

A backup of your old configuration is created with a `.bak-TIMESTAMP` suffix.

### Symlinks for Backward Compatibility
For system-wide configurations, a symlink is created at `~/.config/obot` pointing to `~/.config/ollamabot` to ensure legacy scripts continue to work.

## 3. Manual Migration

If you prefer to migrate manually, you can use the CLI command:

```bash
obot config migrate
```

Or you can manually create the `config.yaml` file using the following mapping guide.

## 4. Mapping Guide

### 4.1 Basic Fields

| Old JSON Field | New YAML Field | Note |
|:---|:---|:---|
| `"ollama_url"` | `ollama.url` | e.g., `http://localhost:11434` |
| `"max_tokens"` | `context.max_tokens` | Total context window size. |
| `"verbose"` | `platforms.cli.verbose` | Enable/disable verbose output. |
| `"model"` | `models.coder.default` | Default model for coding tasks. |
| `"tier"` | `models.tier_detection.auto` | `auto` maps to `true`. |

### 4.2 Model Tiers

The new configuration uses structured tiers based on available RAM.

```yaml
models:
  tier_detection:
    auto: true
    thresholds:
      minimal: [0, 15]      # 0-15GB RAM
      compact: [16, 23]     # 16-23GB RAM
      balanced: [24, 31]    # 24-31GB RAM
      performance: [32, 63] # 32-63GB RAM
      advanced: [64, 999]   # 64GB+ RAM
```

### 4.3 Role Assignments

You can now specify models per role with optional tier overrides.

```yaml
models:
  orchestrator:
    default: "qwen3:32b"
    tier_mapping:
      minimal: "qwen3:8b"
      balanced: "qwen3:14b"
  coder:
    default: "qwen2.5-coder:32b"
    tier_mapping:
      minimal: "deepseek-coder:1.3b"
      balanced: "qwen2.5-coder:14b"
```

### 4.4 Quality Presets

Define iteration counts and verification levels.

```yaml
quality:
  fast:
    iterations: 1
    verification: "none"
  balanced:
    iterations: 2
    verification: "llm_review"
  thorough:
    iterations: 3
    verification: "expert_judge"
```

## 5. Example `config.yaml`

```yaml
# obot + ollamabot unified configuration
version: "2.0"

models:
  tier_detection:
    auto: true
  orchestrator:
    default: "qwen3:32b"
  coder:
    default: "qwen2.5-coder:32b"
  researcher:
    default: "command-r:35b"
  vision:
    default: "qwen3-vl:32b"

orchestration:
  default_mode: "orchestration"
  schedules:
    - id: "knowledge"
      processes: ["research", "crawl", "retrieve"]
      model: "researcher"
    - id: "plan"
      processes: ["brainstorm", "clarify", "plan"]
      model: "coder"
      consultation:
        clarify: {type: "optional", timeout: 60}
    - id: "implement"
      processes: ["implement", "verify", "feedback"]
      model: "coder"
      consultation:
        feedback: {type: "mandatory", timeout: 300}

context:
  max_tokens: 32768
  budget_allocation:
    task: 0.25
    files: 0.33
    project: 0.16
    history: 0.12
    memory: 0.12
    errors: 0.06
    reserve: 0.06
  compression:
    enabled: true
    strategy: "semantic_truncate"
    preserve: ["imports", "exports", "signatures", "errors"]

quality:
  fast: {iterations: 1, verification: "none"}
  balanced: {iterations: 2, verification: "llm_review"}
  thorough: {iterations: 3, verification: "expert_judge"}

platforms:
  cli:
    verbose: true
    mem_graph: true
    color_output: true
  ide:
    theme: "dark"
    font_size: 14
    show_token_usage: true

ollama:
  url: "http://localhost:11434"
  timeout_seconds: 120
```

## 6. Verification

To verify your configuration is correctly loaded, run:

```bash
obot stats
```

This will show your active configuration, including model assignments and resource limits.
