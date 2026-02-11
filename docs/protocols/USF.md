# Unified Session Format (USF)

The Unified Session Format defines the structure for persistent orchestration sessions, enabling cross-platform portability.

## 1. Directory Structure

Sessions are stored in `~/.config/ollamabot/sessions/{session_id}/`.

```
├── meta.json          # Session-level metadata and stats
├── flow.txt           # Raw flow code (e.g., S1P123S2P12)
├── states/            # Snapshots of state at each process
│   ├── 0001-S1P1.json
│   └── 0002-S1P2.json
├── notes/             # Orchestrator and Agent notes
│   ├── orchestrator.md
│   └── agent.md
├── actions/           # Full record of agent actions
│   └── actions.json
└── restore.sh         # Bash script for state restoration
```

## 2. Serialization

- **Metadata**: JSON object containing ID, timestamps, intent, and resource stats.
- **States**: JSON objects linking previous/next IDs and workspace hashes.
- **Notes**: Markdown files with embedded JSON for structured review status.
