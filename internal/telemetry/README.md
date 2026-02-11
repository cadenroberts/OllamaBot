# Telemetry and Privacy

OllamaBot is designed with a "Local First" philosophy. All telemetry and usage statistics are stored strictly on your local machine.

## Storage Location

All telemetry data is stored in JSON format at:
`~/.config/ollamabot/telemetry/stats.json`

(Note: On some systems, this may be `~/.config/obot/telemetry/stats.json`, which is a symbolic link to the `ollamabot` directory.)

## Data Collected

We track the following metrics to help you visualize your local AI performance and cost savings:

- **Session Metadata**: Timestamp, platform (CLI/IDE), and success/failure status.
- **Resource Usage**: Peak memory (GB), disk space written/deleted (MB).
- **Token Metrics**: Total input and output tokens processed.
- **Cost Savings**: Estimated savings compared to commercial APIs (GPT-4, Claude, Gemini).
- **Duration**: Total time spent on orchestration tasks.

## Privacy Policy

1. **No External Reporting**: OllamaBot does **not** send telemetry data to any external server, API, or third-party service.
2. **Local Control**: You can view your statistics using the `obot stats` command and reset all data at any time using `obot stats --reset`.
3. **Open Data**: The `stats.json` file is human-readable and can be inspected or deleted manually at any time.

No data ever leaves your machine unless you explicitly export it.
