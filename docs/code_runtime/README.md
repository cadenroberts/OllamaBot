# code — Local DAG Scheduler for Multi-Agent Collaboration

`code` is a repository-local tool that compiles markdown plans into DAG jobs, coordinates multiple Cursor agents/panes via an HTTP API backed by SQLite WAL, and enforces pointer-based payloads, lease-based concurrency, and content-addressed artifact deduplication.

## Quick Start

```bash
# Make executable
chmod +x code scripts/code scripts/code.py

# Run a plan with 4 agent panes
./code run plan.md --agents 4

# Or step by step:
./code server                                          # start scheduler
./code expand docs/code_runtime/examples/smoke.md      # compile plan
./code worker --mode local --holder exec-1 --poll 1    # start local executor
./code stats                                           # check progress
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  SQLite WAL DB (.cursor/code/code.db)                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │  jobs     │  │ job_deps │  │  events  │              │
│  └──────────┘  └──────────┘  └──────────┘              │
└────────────────────┬────────────────────────────────────┘
                     │ HTTP API (localhost:7337)
    ┌────────────────┼────────────────────────┐
    ▼                ▼                        ▼
 Worker 1        Worker 2               Worker N
 (Cursor pane)   (Cursor pane)          (terminal)
```

## Pointer Payload Rule

All job payloads must start with a valid prefix. Payloads are **pointers**, not essays.

| Prefix   | Meaning                        | Local Execution |
|----------|--------------------------------|-----------------|
| `@cmd:`  | Shell command                  | Yes (allowlisted) |
| `@file:` | File reference (LLM task)      | Only with `#apply` or `#test` suffix |
| `@doc:`  | Non-executable metadata        | Auto-done |
| `@url:`  | URL reference (metadata)       | Auto-done |
| `@git:`  | Git reference (metadata)       | Auto-done |
| `@gh:`   | GitHub reference (metadata)    | Auto-done |

Examples:
```
@cmd:go test ./...
@file:docs/code_runtime/specs/readtools.diff#apply
@file:docs/code_runtime/specs/readtools.diff#sha1=abc123
@doc:LLM_TASK implement the read tools
@url:https://pkg.go.dev/os#ReadFile
@git:abc1234
@gh:owner/repo#42
```

## Plan DSL

Plans are markdown files with step definitions.

### Format

```markdown
# Plan: My Feature
policy: accrue_all_ideas=true, no_refactor=true

- [ ] id=learn.context lane=1 payload=@cmd:./code ctx-scan
- [ ] id=code.feature lane=2 deps=learn.context payload=@file:specs/feature.diff
- [ ] id=test.feature lane=3 deps=code.feature payload=@cmd:go test ./...
```

### Step Fields

| Field     | Required | Description |
|-----------|----------|-------------|
| `id=`     | Yes      | Unique step ID within plan |
| `lane=`   | Yes      | Integer lane (1=learn, 2=code, 3=verify) |
| `payload=`| Yes      | Pointer payload string |
| `deps=`   | No       | Comma-separated dependency step IDs |
| `dedupe=` | No       | Deduplication key (or `#sha1=` in payload) |

### Policy Headers

- `accrue_all_ideas=true` — compiler fails if `TODO_ORPHAN:` markers exist
- `no_refactor=true` — advisory; enforced by worker contract

### Global Job IDs

Steps become jobs with IDs: `{plan_slug}::{step_id}`

## Lanes

Jobs have an integer `lane` for worker specialization:

| Lane | Typical Use |
|------|-------------|
| 1    | Learn/context gathering |
| 2    | Code/patch creation |
| 3    | Apply/verify/test |

Workers can filter by lane: `./code worker --lane 2 --holder coder-1`

Lanes are just integers; semantics are not hardcoded.

## Deduplication

Each job may carry a `dedupe_key` (from `dedupe=` field or `#sha1=` in payload).

Before executing, the system checks `docs/code_runtime/artifacts/by-hash/<hash>.*`. If a matching artifact exists, the job is immediately marked done.

Compute hashes with: `./code hash path/to/file`

## Join Workflow

### 1. Start the scheduler

```bash
./code run my-plan.md --agents 4
```

### 2. Open agent panes and paste

Each pane runs one of the printed join commands:

```bash
./code worker --holder pane-1 --poll 2
./code worker --holder pane-2 --poll 2
./code worker --holder pane-3 --lane 3 --poll 2
./code worker --holder pane-4 --mode local --poll 1
```

### 3. Workers can join/leave at any time

- New workers pick up queued jobs automatically
- Terminated workers' leases expire and jobs requeue
- No coordination needed between workers

## Leases & Heartbeats

- Claimed jobs get a 30-second lease
- Workers must heartbeat every 15s for long jobs
- Stale leases (expired) requeue the job automatically
- Jobs that exceed `max_attempts` (default 3) are marked failed

## HTTP API

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /health     | Health check |
| GET    | /stats      | Job counts by status |
| GET    | /ready      | Claim ready jobs (`?holder=X&lane=N&batch=B`) |
| GET    | /jobs       | List jobs (`?status=X&limit=N`) |
| POST   | /enqueue    | Enqueue a job |
| POST   | /done       | Mark job done |
| POST   | /fail       | Mark job failed |
| POST   | /heartbeat  | Extend job lease |
| POST   | /expand     | Compile plan into jobs |

## Single-Writer Artifact Rule

Any job that produces code must output either:
- A single `.diff` patch file, **or**
- Full file content artifacts

Never both, unless the job payload explicitly declares dual output.

## CLI Reference

```
code server    [--db] [--host] [--port]          Start HTTP scheduler
code worker    [--holder] [--lane] [--mode] ...  Start worker loop
code enqueue   <payload> [--id] [--lane] [--deps] Enqueue a job
code done      <id> [--holder]                   Mark job done
code fail      <id> [--holder] [--error]         Mark job failed
code heartbeat <id> --holder <H>                 Heartbeat a job
code expand    <plan.md> [--db]                  Compile plan to jobs
code run       <plan.md> --agents N              Full workflow
code join      [--holder]                        Print Worker Contract
code exec                                        Print Executor Contract
code stats                                       Show stats
code jobs      [--status] [--limit]              List jobs
code hash      <path>                            Compute SHA1
```
