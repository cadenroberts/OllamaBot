---
name: "interrupt"
description: "Forcible override. Restructure plan around new command; preserve valid work; resume appropriately."
version: "1.0"
---

Trigger when the user uses "/interrupt".

Protocol (must follow):
1) Delegate to interrupt_replanner.
2) Identify preserved vs invalidated work.
3) Produce revised plan.
4) Resume at correct point (continue or restart).
5) Output using /interrupt schema.
6) Do not ask questions.
