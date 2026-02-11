# OllamaBot Migration Guide (v1.0)

This guide provides instructions for migrating from legacy configurations and session formats to the Unified Orchestration Protocol (UOP) v1.0.

## 1. CLI Configuration Migration

The CLI has moved from JSON-based configuration to YAML-based unified configuration.

- **Old Path**: `~/.config/obot/config.json`
- **New Path**: `~/.config/ollamabot/config.yaml`

### Migration Steps:
1. Run `obot config migrate`.
2. The tool will automatically read your existing JSON configuration and convert it to the new YAML format.
3. A backup of your old config will be created at `~/.config/obot/config.json.bak`.
4. A symbolic link from the old path to the new path will be created for backward compatibility.

## 2. IDE Configuration Migration

The IDE now shares behavioral settings with the CLI via the unified YAML config.

### Migration Steps:
1. On the first launch of OllamaBot IDE v1.0, a migration prompt will appear.
2. Clicking "Migrate" will move your `UserDefaults` settings (Ollama URL, model selections, etc.) to `~/.config/ollamabot/config.yaml`.
3. UI-specific preferences (font size, theme) will be mirrored in the YAML config but will remain manageable via IDE settings.

## 3. Session Format Migration

Sessions are now stored in the Unified Session Format (USF).

### Migration Steps:
1. Legacy sessions stored in the old folder structure are automatically recognized.
2. When loading a legacy session, use `obot session export <session_id>` to convert it to a `.usf` file.
3. The `.usf` file can then be imported into the IDE or shared across machines.

---

*Last Updated: 2026-02-10*
