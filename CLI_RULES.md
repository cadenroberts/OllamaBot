# obot CLI Rules

This document defines the CLI contract so you never have to call Go files directly.

## Command Shape

```
obot [file] [-start +end] [instruction]
```

- `file` is required for code fixes.
- `-start` and `+end` define an inclusive line range.
- `instruction` is optional free‑text guidance (wrap in quotes).

Examples:

```
obot main.go
obot main.go -10 +25
obot main.go -10 +25 "add error handling"
```

## Behavioral Rules

- **Default**: in‑place edit. `obot` writes changes to the target file.
- **Line ranges**: only the specified lines are replaced.
- **Instruction**: any remaining args are treated as the instruction.
- **No file**: shows help and exits non‑zero.
- **Interactive**: `-i` enters a multi‑turn mode.
- **Local‑first**: inference happens via local Ollama.

## Quality Pipeline

`--quality` controls agentic behavior:

- `fast`: single‑pass fix (no plan or review)
- `balanced`: plan + fix + review
- `thorough`: plan + fix + review + revise if reviewer flags issues

`obot` also runs a lightweight internal quality review and warns on suspicious output.

## Output Modes

- `--dry-run`: do not write changes to disk.
- `--diff`: show unified diff before applying changes.
- `--print`: print the fixed code to stdout.
- `--diff-context N`: context lines for `--diff` (default 3).

## Model Controls

- `--model <tag>`: override the model (e.g., `qwen2.5-coder:14b`).
- `--temperature <float>`: override sampling temperature.
- `--max-tokens <int>`: override generation length.
- `--context-window <int>`: override context size.

## UX Controls

- `--verbose`: enable detailed output (default on).
- `--mem-graph`: show live memory usage (default on).
- `OBOT_MEM_GRAPH=0`: disable memory graph.
- `--no-summary`: disable actions summary.

## Exit Codes

- `0`: success
- `>0`: error (invalid args, IO failure, model error, etc.)
