# Known Issues — OllamaBot v2.0

## Resource Management

### 1. High RAM Consumption
- **Issue**: Running multiple 32B parameter models simultaneously can exceed available RAM on 16GB and 24GB Macs.
- **Symptom**: System slowdown, "Ollama connection lost" errors, or app crashes.
- **Workaround**: Use the **Balanced** or **Minimal** RAM tiers in settings, which map to smaller model variants (e.g., 7B or 14B).

### 2. Slow Model Switching
- **Issue**: Ollama takes ~20-40 seconds to load a 32B model into VRAM when switching roles (e.g., Researcher to Coder).
- **Symptom**: The agent appears "stuck" while the status bar shows "Loading Model".
- **Workaround**: Enable "Pre-warm Models" in settings to keep the orchestrator in memory.

## Connectivity

### 3. Ollama Serve Requirement
- **Issue**: OllamaBot requires the Ollama background service to be running.
- **Symptom**: "Connection Refused" or "Ollama Disconnected" alerts.
- **Workaround**: Ensure Ollama is running (`ollama serve`) and that the URL in settings matches your Ollama installation (default: `http://localhost:11434`).

## Orchestration

### 4. Agent Loop Limits
- **Issue**: Complex tasks may hit the "Max Steps" limit before completion.
- **Symptom**: The agent stops with a "Max steps reached" warning.
- **Workaround**: Increase the limit in **Settings > Agent**, or break the task into smaller sub-tasks.

### 5. Non-Deterministic Planning
- **Issue**: Since planning is LLM-based, the generated implementation plan may vary between runs for the same prompt.
- **Symptom**: Different file edit sequences for identical tasks.
- **Workaround**: Use the **Thorough** quality preset for more consistent, multi-turn reasoning.

## CLI & Configuration

### 6. YAML Hot-Reload Delay
- **Issue**: There is a 0.5s throttle on configuration hot-reloading to prevent multiple reads during rapid file saves.
- **Symptom**: CLI changes to `config.yaml` may take a moment to reflect in the IDE.
- **Workaround**: Wait ~1 second after saving the YAML file before expecting the IDE to update.

### 7. Terminal Rendering
- **Issue**: The integrated terminal (SwiftTerm) may have rendering artifacts with certain complex TUI applications or custom ZSH themes.
- **Symptom**: Misaligned text or missing ANSI colors.
- **Workaround**: Use the system terminal for highly interactive TUI work.

---
**Last Updated**: 2026-02-10  
**Report Issues**: [GitHub Issues](https://github.com/croberts/ollamabot/issues)
