# Unified Context Protocol (UCP)

The Unified Context Protocol governs how workspace information, history, and state are summarized and presented to LLM models.

## 1. Context Categories

Context is divided into specific buckets with assigned token budgets.

- **System Context (15%)**: Core instructions and rules.
- **File Context (35%)**: Content of relevant files and directory structures.
- **History Context (12%)**: Previous actions and model responses.
- **Memory Context (12%)**: Persistent notes and session-level decisions.
- **Error Context (6%)**: Previous failures and remediation attempts.

## 2. Summarization Strategies

To stay within token limits, the protocol employs several strategies:
- **Semantic Compression**: Removing boilerplate while preserving imports/exports.
- **LRU Caching**: Keeping frequently accessed files in full, while truncating others.
- **Diff-based History**: Showing changes rather than full file versions.

## 3. Metadata

Every context package includes:
- `plan_id`: Unique identifier for the current orchestration plan.
- `flow_code`: compact representation of the orchestration history (e.g., `S1P123S2P12`).
- `intent`: Classified user intent (Coding, Research, etc.).
