# Contributing to OllamaBot

Thank you for your interest in contributing to OllamaBot! This project aims to push the boundaries of local AI autonomy.

## Project Structure

OllamaBot is composed of two main components:

1.  **Swift macOS IDE (`Sources/`)**: The native macOS application built with SwiftUI. It handles the UI, file editing, and coordinates the local agents.
2.  **Go CLI (`cmd/obot/`, `internal/`)**: A standalone Go application (`obot`) that provides professional-grade orchestration, code fixing, and session management.

## Getting Started

### Prerequisites

- **macOS 14.0+**
- **Apple Silicon Mac** (M1/M2/M3)
- **Xcode 15.0+**
- **Go 1.21+**
- **Ollama** installed and running

### Setup for Development

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/cadenroberts/OllamaBot.git
    cd OllamaBot
    ```

2.  **Run the setup script**:
    ```bash
    ./scripts/setup.sh
    ```

3.  **Swift Development**:
    Open `Package.swift` in Xcode to work on the IDE.

4.  **Go Development**:
    Use the `Makefile` to build and test the CLI:
    ```bash
    make build
    make test
    ```

## Development Workflow

### Unified Orchestration Protocol (UOP)

The core logic of OllamaBot is built on the **Unified Orchestration Protocol (UOP)**. This ensures that both the CLI and IDE follow the same 5-schedule, 3-process orchestration flow:

- **Schedules**: Knowledge, Plan, Implement, Scale, Production.
- **Processes**: P1, P2, P3 in each schedule.

When contributing to orchestration logic, ensure consistency between `internal/orchestrate/` (Go) and `Sources/Services/OrchestrationService.swift` (Swift).

### Unified Session Format (USF)

Sessions are stored in the **Unified Session Format (USF)** at `~/.config/ollamabot/sessions/`. This allows sessions to be started in the CLI and resumed in the IDE, or vice versa.

### Coding Standards

- **Additive-Only**: Prefer adding new functionality or adapters over refactoring existing core logic.
- **No Refactor Policy**: Avoid large-scale refactors unless explicitly required for architectural alignment between platforms.
- **Documentation**: Update relevant documentation in `docs/` when changing protocols or configuration schemas.
- **Testing**:
    - For Go: Run `go test ./...`.
    - For Swift: Add unit tests in `Tests/`.

## Pull Request Process

1.  Create a feature branch from `main`.
2.  Ensure your code builds and tests pass.
3.  Include a brief description of the changes and why they are needed.
4.  Submit a Pull Request for review.

## Community & Support

If you have questions or want to discuss ideas, please open an Issue on GitHub.
