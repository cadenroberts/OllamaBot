# Changelog

All notable changes to the OllamaBot project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-10

### Added
- **Unified Orchestration Protocol (UOP)**: Complete 5-schedule (Knowledge, Plan, Implement, Scale, Production) and 15-process state machine.
- **Multi-Model Coordination**: Support for specialized roles (Orchestrator, Coder, Researcher, Vision) using Ollama.
- **Unified Session Format (USF)**: Portable session management with state restoration and history.
- **Unified Tool Registry (UTR)**: Canonical set of 20+ tools including file ops, git, web search, and delegation.
- **CLI (obot)**: Standalone Go CLI with orchestration, code fixing, and session management.
- **IDE (macOS)**: Native Swift IDE with Infinite Mode, multi-model chat, and visual orchestration timeline.
- **Quality Presets**: Fast, Balanced, and Thorough presets for orchestration depth control.
- **Human Consultation**: Integrated handler for mandatory and optional human-in-the-loop consultation.
- **Resource Monitoring**: Real-time tracking of memory, disk, and token usage.
- **Cost Tracking**: Estimated savings calculator vs. commercial AI APIs.
- **OBotRules & Mentions**: Support for `.obotrules` injection and `@mention` context resolution.
- **Git Integration**: Native support for GitHub and GitLab repository management.
- **Repository Indexing**: Fast symbol and file indexing for codebase-wide search.
- **Error Suspension**: Structured error analysis and recovery suggestions using LLM-as-Judge.

### Fixed
- Improved session state restoration reliability.
- Optimized multi-model switching latency.
- Refined ANSI terminal rendering in the CLI.
- Enhanced token counting accuracy via tiktoken.

### Changed
- Migrated configuration from JSON to unified YAML format (`config.yaml`).
- Consolidated multiple Go packages for better architecture alignment.
- Standardized tool calling patterns across CLI and IDE.

## [0.5.0] - 2025-12-15
### Added
- Initial implementation of the orchestration loop.
- Basic Ollama client with streaming support.
- Tier 1 file operations.
- Simple session persistence.

## [0.1.0] - 2025-10-01
### Added
- Project initialization.
- Base CLI structure.
- Experimental Swift UI components.
