# Session Migration Guide: Legacy → Unified Session Format (USF)

## Overview

OllamaBot v2.0 introduces the **Unified Session Format (USF)**. This format enables session portability between the CLI, the IDE, and remote workers. It replaces the previous platform-specific state persistence with a standardized JSON-based format (`session.usf`).

## Key Changes

| Feature | Legacy Sessions | USF Sessions (v2.0) |
|---------|-----------------|---------------------|
| **File Name** | `meta.json`, `flow.code`, etc. | `session.usf` |
| **Structure** | Multiple files per session | Single monolithic JSON + artifact directory |
| **Portability**| Platform-locked | Cross-platform (CLI ↔ IDE) |
| **Metadata** | Minimal | Rich (Task info, Workspace context, Stats) |

## Migration Process

The `SessionManager` and `UnifiedSessionService` handle the migration and conversion between internal states and the USF format.

### 1. Exporting to USF

If you have legacy sessions that you want to use in v2.0, they can be exported using the internal `ExportUSF` function. 

- **CLI**: Legacy sessions in `~/.obot/sessions/` are automatically detected and can be exported via:
  ```bash
  obot session export <session_id>
  ```
- **IDE**: The IDE will automatically wrap legacy session states into USF objects when saving.

### 2. The USF File Structure

A USF session is stored in a directory named after the `session_id`.

```text
~/.config/ollamabot/sessions/
└── 1739212345678/
    ├── session.usf       <-- The core USF JSON file
    ├── flow.code         <-- Legacy compatibility file
    ├── checkpoints/      <-- Session-specific checkpoints
    └── actions/          <-- Detailed action logs and diffs
```

### 3. Cross-Platform Resumption

Because USF is unified, you can:
1. Start a session in the **IDE**.
2. Close the IDE and open your **Terminal**.
3. Run `obot session list` to see the session.
4. Run `obot orchestrate --resume <session_id>` to continue exactly where you left off.

## Manual Migration / Import

To manually import a USF session from another machine:

1. Copy the entire session directory to `~/.config/ollamabot/sessions/`.
2. Ensure the `session.usf` file is present in the directory.
3. Restart OllamaBot (CLI or IDE). The session will appear in the history list.

## Troubleshooting

- **Missing Actions**: USF stores a summary of actions in the `history` array. If detailed diffs are missing, ensure the `actions/` directory was also copied during manual migration.
- **Path Mismatches**: USF stores the absolute path of the workspace. If resuming on a different machine, OllamaBot will attempt to relocate the workspace relative to the current directory if the absolute path is not found.
- **Version Mismatch**: USF v1.0 is the only supported version. Files with higher versions may fail to load in older OllamaBot releases.

---
**Document Status:** Final  
**Protocol Version:** 1.0 (USF)  
**Last Updated:** 2026-02-10
