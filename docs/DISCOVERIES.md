# OllamaBot Discoveries

This document tracks discoveries and improvements made during the implementation of OllamaBot.

## Technical Discoveries

- **Agent Plugin System**: Implemented a lifecycle-hook based plugin system allowing non-invasive extension of agent behavior (OnBeforeAction, OnAfterAction, OnBeforeExecute, OnAfterExecute).
- **Language Statistics**: Integrated per-language file counts and line statistics into the repository index for better project visibility.
- **Atomic Patch Engine**: Built a robust patch application system with backup, validation, conflict detection, and rollback support.
- **Unified Telemetry**: Centralized metrics collection for memory, tokens, disk, and duration across both CLI and IDE platforms.
- **Interactive TUI**: Developed a rich conversational interface with session-based history and slash-command support.
- **Project Health Scanning**: Implemented a "health scanner" to detect TODOs, security risks, and code complexity issues.
- **Real Workspace Hashing**: Switched from file metadata hashing to full content-based SHA256 hashing for reliable workspace integrity verification.
- **Expert Judge Chat API**: Migrated the "LLM-as-judge" system from completion to Chat API to leverage system prompts for more structured expert reviews.
