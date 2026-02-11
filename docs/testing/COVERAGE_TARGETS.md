# Test Coverage Targets

To ensure the reliability and stability of OllamaBot, we have set the following minimum test coverage targets for both the CLI and IDE components.

## CLI Coverage Targets

| Component      | Target Coverage |
|----------------|-----------------|
| Agent Execution| 90%             |
| Tools          | 85%             |
| Context        | 80%             |
| Orchestration  | 80%             |
| Fixer          | 85%             |
| Sessions       | 75%             |

## IDE Coverage Targets

| Component      | Target Coverage |
|----------------|-----------------|
| Agent Execution| 90%             |
| Tools          | 85%             |
| Context        | 80%             |
| Orchestration  | 80%             |
| Sessions       | 75%             |
| UI             | 60%             |

## Measurement

Coverage should be measured using standard tooling for each platform:
- **CLI (Go)**: `go test -coverprofile=coverage.out ./...`
- **IDE (Swift)**: Xcode code coverage reports.
