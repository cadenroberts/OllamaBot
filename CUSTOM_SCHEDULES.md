# Design Proposal: Custom Schedule Definitions

## Question
Should users be allowed to define custom schedules and processes in OllamaBot?

## Recommendation: YES (Constrained Customization)

To maintain the reliability and cross-platform consistency of the Unified Orchestration Protocol (UOP), I recommend allowing users to define **Custom Schedules**, while keeping the **3-Process** structure fixed.

### 1. Custom Schedules (Supported)
Users should be able to define new schedules in `.obot/schedules/*.yaml`. This allows the orchestrator to adapt to specific domain-driven workflows without breaking the core state machine.

**Examples of Custom Schedules:**
- `SecurityAudit`: P1 (Scan), P2 (Patch), P3 (Verify).
- `UXReview`: P1 (Audit), P2 (Style), P3 (Polish).
- `Translation`: P1 (Extract), P2 (Translate), P3 (Proofread).

### 2. Fixed 3-Process Structure (Invariant)
The UOP relies on the `P1 <-> P2 <-> P3` state machine for navigation, UI rendering, and agent behavior (Analyst -> Builder -> Critic).
- **P1 (Discovery/Knowledge)**: Always the first step.
- **P2 (Execution/Action)**: Where changes happen.
- **P3 (Verification/Review)**: Final validation.

Allowing an arbitrary number of processes would complicate the UI (pipeline view), CLI (navigation commands), and agent logic (knowing its role).

### 3. Proposed Configuration Format
```yaml
# .obot/schedules/security_audit.yaml
name: Security Audit
icon: shield.fill
default_model: command-r  # Optimized for analysis
processes:
  P1:
    name: Vulnerability Scan
    prompt: "Scan the codebase for common security vulnerabilities (XSS, SQLi, etc.)."
  P2:
    name: Remediation
    prompt: "Apply fixes for the vulnerabilities found in P1."
  P3:
    name: Compliance Check
    prompt: "Verify that the fixes comply with security standards."
```

### 4. Benefits
- **Extensibility**: Adapts to any team's specific workflow.
- **Consistency**: The UI and CLI remain unchanged; they just render the new names/prompts.
- **Agent Clarity**: The agent always knows its role based on the process index (1=Analyst, 2=Builder, 3=Critic).

## Conclusion
We should implement a `CustomScheduleLoader` that reads these YAML definitions and injects them into the `Coordinator` and `OrchestrationService`. This provides the flexibility users need while preserving the architectural integrity of the UOP.
