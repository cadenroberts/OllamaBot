# OllamaBot IDE: In-App Help & Feature Guides

Welcome to the OllamaBot IDE. This guide explains the core features, orchestration workflows, and how to get the most out of your agentic coding experience.

## 1. Understanding Orchestration

OllamaBot uses a professional-grade orchestration framework based on 5 distinct schedules. Each schedule represents a specific phase of the software development lifecycle.

### The 5 Schedules:
1.  **Knowledge**: Researching the task, crawling documentation, and retrieving relevant context.
2.  **Plan**: Brainstorming approaches, clarifying ambiguities with the user, and finalizing a technical plan.
3.  **Implement**: Executing the plan, verifying changes via tests/lints, and receiving user feedback.
4.  **Scale**: Identifying performance concerns, benchmarking, and applying optimizations.
5.  **Production**: Analyzing code quality/security, systemizing patterns, and harmonizing the UI.

### Navigation Rules (The 1↔2↔3 Rule)
Within each schedule, there are 3 processes (P1, P2, P3). You can move forward or backward between adjacent processes (e.g., P1 to P2, P2 back to P1, P2 to P3). Advancing to the next schedule requires completing P3 of the current schedule.

## 2. Quality Presets

Control the depth and rigor of the agent's work using quality presets:

- **Fast**: Single-pass execution without formal verification. Optimized for speed (~30s).
- **Balanced**: A multi-stage pipeline (Plan → Execute → Review) with LLM-based verification (~180s).
- **Thorough**: Comprehensive evaluation including Expert Judge analysis and multiple revision loops (~600s).

## 3. Session Management & Portability

Your work is automatically saved in the Unified Session Format (USF).

- **Checkpoints**: Use the Checkpoint panel to save the state of your code and orchestration at any time.
- **Portability**: You can export a session from the IDE and resume it in the CLI, or vice versa, without losing context or progress.
- **Restore**: Use the `restore.sh` script in your session folder to roll back to any previous state via the terminal.

## 4. The Expert Judge System

In Balanced and Thorough modes, your work is reviewed by specialized expert models:
- **Coder**: Evaluates code quality, patterns, and adherence to requirements.
- **Researcher**: Checks for information accuracy and context structure.
- **Vision**: Analyzes UI consistency and visual polish (requires a vision-capable model).

The results are synthesized into a **TLDR Summary** available at the end of each session.

## 5. Tips for Success
- **Be Specific**: The clearer your initial prompt, the better the Plan phase will be.
- **Review Plans**: Always check the Plan (P3) before the agent starts implementing.
- **Use Notes**: You can send notes to the Orchestrator or the Coder agent to provide extra guidance mid-session.

---

*Need more help? Visit our [GitHub Discussions](https://github.com/croberts/ollamabot/discussions).*
