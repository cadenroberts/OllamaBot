# Upgrading to OllamaBot v2.0

This guide provides step-by-step instructions for upgrading from OllamaBot v1.x to v2.0. Version 2.0 introduces significant architectural changes, including a unified configuration system, cross-platform session portability (USF), and an enhanced orchestration engine.

## 1. Quick Upgrade (Automated)

OllamaBot v2.0 is designed to handle most migrations automatically on its first launch.

1. **Pull the latest changes**:
   ```bash
   git pull origin main
   ```
2. **Run the setup script**:
   ```bash
   ./scripts/setup.sh
   ```
3. **Launch OllamaBot**:
   - **CLI**: Run `obot` in your terminal.
   - **IDE**: Open the OllamaBot application.
4. **Follow Prompts**: If any manual intervention is required, the system will prompt you.

## 2. Step-by-Step Manual Upgrade Checklist

If you prefer to upgrade manually or if the automated process fails, follow these steps:

### Phase A: Preparation
- [ ] **Backup**: Copy `~/.config/obot/` to a safe location.
- [ ] **Ollama**: Ensure Ollama is running (`ollama serve`).

### Phase B: Configuration
- [ ] **Initialize**: Run `obot config migrate` to create `~/.config/ollamabot/config.yaml`.
- [ ] **Review**: Open `~/.config/ollamabot/config.yaml` and verify your model roles (Orchestrator, Coder, Researcher, Vision).
- [ ] **Verify**: Run `obot stats` to ensure the new configuration is valid.

### Phase C: Session Migration
- [ ] **List**: Run `obot session list` to see your legacy sessions.
- [ ] **Convert**: For any active legacy session, run `obot session export <session_id>` to convert it to USF.
- [ ] **Test**: Resume a session in the IDE to ensure portability is working.

## 3. Configuration Migration

Version 2.0 moves from platform-specific JSON/UserDefaults configurations to a unified YAML-based system at `~/.config/ollamabot/config.yaml`.

- **Automatic**: On first run, OllamaBot will migrate your old settings and create a backup.
- **Manual**: You can trigger migration via the CLI:
  ```bash
  obot config migrate
  ```
- **Details**: See [CLI Configuration Migration](migration/CLI_CONFIG.md) and [IDE Configuration Migration](migration/IDE_CONFIG.md) for full mapping details.

## 3. Session Migration (USF)

Legacy sessions (stored in `meta.json`, `flow.code`) are replaced by the **Unified Session Format (USF)**, enabling you to switch between CLI and IDE seamlessly.

- **Automatic**: The IDE and CLI will automatically wrap or convert legacy sessions as you access them.
- **Portability**: Sessions are now stored in `~/.config/ollamabot/sessions/`. Each session directory contains a `session.usf` file.
- **Resuming**: You can start a session in the IDE and resume it in the CLI using `obot orchestrate --resume <session_id>`.
- **Details**: See [Session Migration Guide](migration/SESSIONS.md).

## 4. Key Breaking Changes

- **Config Path**: Legacy `~/.config/obot/` is now `~/.config/ollamabot/`. A symlink is usually created for backward compatibility.
- **Command Names**: Some CLI commands have been reorganized. Use `obot --help` to see the new structure.
- **Model Roles**: You must now assign models to specific roles (Orchestrator, Coder, Researcher, Vision) in your `config.yaml`.

## 5. Post-Upgrade Verification

After upgrading, verify your setup by running:

```bash
obot stats
```

This will confirm that your configuration is correctly loaded and that your models are accessible via Ollama.

## 6. Troubleshooting

- **Configuration Errors**: If `config.yaml` is corrupted, OllamaBot will fall back to defaults. Check the logs at `~/.config/ollamabot/logs/`.
- **Permission Issues**: Ensure OllamaBot has read/write access to `~/.config/ollamabot/`.
- **Ollama Connectivity**: Ensure Ollama is running (`ollama serve`) before launching OllamaBot.

---
*Document Version: 1.0*  
*Last Updated: 2026-02-10*
