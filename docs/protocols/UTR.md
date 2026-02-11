# Unified Tool Registry (UTR)

The Unified Tool Registry defines the canonical set of tools available to OllamaBot agents across all platforms (CLI and IDE).

## 1. Tool Tiers

Tools are categorized into tiers based on their impact and autonomy.

### 1.1 Tier 1: Executor Tools
Standard file and system operations.
- `file.write`: Create or overwrite a file.
- `file.edit`: Edit a file using search/replace.
- `file.delete`: Delete a file.
- `file.rename`: Rename a file.
- `file.move`: Move a file.
- `file.copy`: Copy a file.
- `dir.create`: Create a directory.
- `dir.delete`: Delete a directory.
- `system.run`: Execute a shell command.
- `system.lint`: Run project-specific linter.
- `system.format`: Run project-specific formatter.
- `system.test`: Run project-specific tests.

### 1.2 Tier 2: Autonomous Tools
Tools that enable agents to gather context and make decisions.
- `think`: Internal reasoning step.
- `complete`: Signal task completion.
- `ask_user`: Request human consultation.
- `file.read`: Read file contents.
- `file.search`: Search file contents (ripgrep-like).
- `file.list`: List directory contents.
- `file.edit_range`: Targeted edits on specific line ranges.
- `ai.delegate.{role}`: Delegate tasks to specialized models (coder, researcher, vision).
- `web.search`: Search the internet.
- `web.fetch`: Fetch content from a URL.
- `git.status`: Get repository status.
- `git.diff`: View changes.
- `git.commit`: Create a commit.

## 2. Platform Aliases

The registry maps platform-specific tool names to canonical Tool IDs.
- CLI Alias (e.g., `CreateFile`) → `file.write`
- CLI Alias (`Lint`) → `system.lint`
- CLI Alias (`Format`) → `system.format`
- CLI Alias (`Test`) → `system.test`
- IDE Alias (e.g., `write_file`) → `file.write`
