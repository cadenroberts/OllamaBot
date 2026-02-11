# Telemetry and Analytics

`ollamabot` implements a privacy-first, opt-in telemetry system to understand usage patterns and improve the orchestration engine.

## 1. Principles

- **Opt-in Only**: Telemetry is disabled by default. Users must explicitly enable it via `shared_config.yaml` or UI settings.
- **Anonymized**: No personal data, code snippets, or prompt content is transmitted.
- **Aggregated**: Data is collected in aggregate to identify bottlenecks and common failure modes.

## 2. Event Types

### Core Orchestration Events
- `session_start`: Triggered when an orchestration task begins. (Mode, ScheduleID)
- `process_transition`: Triggered on every P1↔P2↔P3 or S(n)→S(n+1) navigation. (From, To, Duration)
- `session_complete`: Triggered when orchestration finishes. (FlowCode, TotalDuration, Success)

### Resource Events
- `memory_pressure`: Triggered when warning/critical thresholds are hit. (Level, UsageGB)
- `token_milestone`: Triggered every 10k tokens used. (TotalTokens)
- `limit_exceeded`: Triggered when a resource limit is reached. (Resource, Limit)

### Agent Events
- `tool_invocation`: Triggered when the agent calls a tool. (ToolName, Success, Duration)
- `expert_analysis`: Triggered when a judge expert completes a review. (ExpertType, Score)

## 3. Configuration

Users can control telemetry in `shared_config.yaml`:

```yaml
telemetry:
  enabled: false          # Set to true to opt-in
  endpoint: "https://telemetry.ollamabot.io/v1/ingest"
  collection_interval: 60 # Seconds
  include_resource_stats: true
  include_error_logs: false
```

## 4. Local Storage

Telemetry events are buffered locally in `~/.ollamabot/telemetry/buffer.jsonl` before being periodically uploaded. If the upload fails, the local buffer is preserved and retried later.
