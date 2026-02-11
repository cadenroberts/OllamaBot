# IDE Configuration Migration Guide

This document provides technical details for the migration from `UserDefaults`-based configuration to the unified `config.yaml` system in the OllamaBot IDE.

## Overview

Historically, the IDE stored all settings (including AI model configurations, Ollama URL, and UI preferences) in the standard macOS `UserDefaults` system. To achieve behavioral equivalence with the CLI, we have moved all core logic settings to a shared YAML file at `~/.config/ollamabot/config.yaml`.

## The Migration Process

When the IDE detects a version 1.0+ launch without an existing `config.yaml`, it initiates an automatic migration from `UserDefaults`.

### 1. Detection
The `SharedConfigService` checks for the presence of `~/.config/ollamabot/config.yaml` during initialization. If missing, it uses default values. The migration can be explicitly triggered by the user or during first-run setup.

### 2. Data Mapping
The following mappings are applied from `UserDefaults` (managed by `ConfigurationManager`) to the `UnifiedConfig` structure in `SharedConfigService.swift`:

| UserDefaults Key | UnifiedConfig Path | Notes |
|------------------|---------------------|-------|
| `contextWindow` | `context.max_tokens` | |
| `defaultModel` | `ollama.url` | Mapped to default Ollama URL if "auto" |
| `maxLoops` | `quality.thorough.iterations` | Set to 4 if `maxLoops > 150` |
| `theme` | `platforms.ide.theme` | |
| `editorFontSize` | `platforms.ide.font_size` | Converted to `Int` |
| `showRoutingExplanation` | `platforms.ide.show_token_usage` | |

### 3. Serialization
The mapped data is encoded using `YAMLEncoder` and written to `~/.config/ollamabot/config.yaml`.

### 4. Verification & Sync
After writing, the `SharedConfigService` reloads the configuration and performs a **reverse sync** back to `UserDefaults` for legacy components:
- `appearance.theme`
- `editor.fontSize`
- `ai.ollamaURL`

## Symbolic Links and Backward Compatibility

To maintain compatibility with legacy plugins or external scripts that expect `~/.config/obot/config.json`, the migration process creates a legacy directory at `~/.config/obot/` and places a symbolic link or a mirrored JSON file there.

## Manual Trigger

If you need to re-run the migration, you can use the following command in the IDE's internal terminal:

```bash
/internal/migrate-config --force
```

## Troubleshooting

- **Permissions**: Ensure the IDE has "Full Disk Access" or at least permissions to write to `~/.config/`.
- **Locking**: If the file is locked by the CLI, the IDE will wait for up to 5 seconds before reporting a timeout.
- **Corrupted YAML**: If the `config.yaml` is manually edited and becomes invalid, the IDE will fall back to safe defaults and notify the user.

---

*Document Version: 1.0*  
*Last Updated: 2026-02-10*
