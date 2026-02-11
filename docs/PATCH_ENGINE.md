# OllamaBot Patch Engine

The Patch Engine ensures that all file modifications are applied safely, atomically, and with robust rollback capabilities.

## CLI Flags

The following flags are available for commands that modify files (e.g., `obot fix`, `obot apply`):

### `--dry-run`
- **Description**: Shows what would be changed without actually modifying any files.
- **Behavior**: Generates a diff preview and lists the files that would be updated, created, or deleted.
- **Usage**: Use this to verify the agent's plan before execution.

### `--no-backup`
- **Description**: Skips the creation of pre-apply backups.
- **Behavior**: By default, OllamaBot creates a timestamped backup of every file it modifies. This flag disables that behavior.
- **Usage**: Recommended for power users working in large repositories where disk space is a concern and Git is used for recovery.

### `--force`
- **Description**: Applies patches even if validation warnings are present.
- **Behavior**: Bypasses checksum verification or conflict detection warnings.
- **Usage**: Use with extreme caution when you know the modifications are safe despite warnings.

## Atomic Transactions

All patches in a single orchestration step are treated as a single transaction. 
- If **all** patches succeed, the transaction is committed.
- If **any** patch fails, the entire transaction is rolled back using the pre-apply backups.

---

*Last Updated: 2026-02-10*
