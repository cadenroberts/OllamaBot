# OllamaBot v2.0.0 Release Notes

**Date:** February 10, 2026  
**Version:** 2.0.0 "Foundations"

We are proud to announce the release of **OllamaBot v2.0.0**, a major milestone that transforms OllamaBot from a standalone AI coding assistant into a unified, autonomous orchestration framework for local AI development.

## 🌟 Highlights

### 🧠 Unified Orchestration Protocol (UOP)
The core of v2.0.0 is the **Unified Orchestration Protocol**, a structured framework that guides AI agents through a professional software development lifecycle across 5 schedules:
1.  **Knowledge**: Research, crawling, and information retrieval.
2.  **Plan**: Brainstorming, clarification, and concrete planning.
3.  **Implement**: Implementation, automated verification, and human feedback.
4.  **Scale**: Refactoring, benchmarking, and optimization.
5.  **Production**: Security analysis, systemization, and harmonization.

### 💾 Unified Session Format (USF v1.0)
Handoff between the CLI and the IDE is now seamless. Sessions are saved in a portable JSON format that includes full action history, checkpoints, and orchestration state. Start a task in your terminal and finish it in the native macOS IDE.

### ⚙️ Shared Configuration
Both the Go-based `obot` CLI and the Swift-based macOS IDE now share a single YAML configuration at `~/.config/ollamabot/config.yaml`. This ensures consistent model role assignments, quality presets, and resource limits across all platforms.

### 🎭 Multi-Model Orchestra
OllamaBot now coordinates up to four specialized models simultaneously:
-   **Orchestrator** (e.g., Qwen3): The central brain for planning and delegation.
-   **Coder** (e.g., Qwen2.5-Coder): Specialized in generation and debugging.
-   **Researcher** (e.g., Command-R): Optimized for RAG and documentation.
-   **Vision** (e.g., Qwen3-VL): Capable of analyzing screenshots and UI layouts.

## 🛠️ New CLI Capabilities

The `obot` CLI has been significantly enhanced:
-   **Structured External Tools**: New `lint`, `format`, and `test` commands provide project-aware integration with your favorite developer tools.
-   **Quality Presets**: Use `--quality [fast|balanced|thorough]` to control the depth of AI reasoning.
-   **Enhanced Diagnostics**: Use `obot stats` to view real-time memory usage, token tracking, and accumulated cost savings.

## 📱 Native IDE Improvements

-   **Visual Timeline**: A new orchestration panel provides a real-time view of the agent's progress through the UOP schedules.
-   **Human-in-the-Loop**: Interactive consultation modals allow you to provide feedback or clarify requirements during autonomous runs.
-   **Performance Dashboards**: Real-time visualization of RAM usage and token consumption.

## 🚀 Getting Started

To upgrade to v2.0.0, simply pull the latest changes and run the setup script:

```bash
./scripts/setup.sh
```

Existing configurations will be automatically migrated to the new YAML format.

---
Built with ❤️ for the local AI community.  
*Your AI should work FOR you, not wait ON you.*
