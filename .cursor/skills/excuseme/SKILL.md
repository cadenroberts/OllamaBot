---
name: "excuseme"
description: "Additive-only continuation. Incorporate new info without restarting; adjust only if necessary."
version: "1.0"
---

Trigger when the user uses "/excuseme".

Protocol (must follow):
1) Delegate to excuseme_continuator.
2) Continue from the exact prior continuation point.
3) Adjust ONLY if new info makes the current step invalid.
4) Output using /excuseme schema.
5) Do not ask questions.
