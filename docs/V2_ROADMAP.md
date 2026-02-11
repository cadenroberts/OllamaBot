# OllamaBot v2.0 Roadmap (Post-March)

This document outlines the strategic initiatives deferred to v2.0, focusing on performance, scalability, and deep integration.

## 1. CLUSTER 10: CLI-as-Server / JSON-RPC

Currently, the orchestrator uses Go closure-injected callbacks, which are highly efficient but not easily serializable for remote access. v2.0 will refactor this architecture.

- **Refactor Callbacks**: Move from closures to serializable request/response interfaces.
- **State Serialization**: Implement automated state snapshots after every orchestration step.
- **JSON-RPC Server**:
    - `session.start/step/state`
    - `context.build`
    - `models.list`
- **IDE RPC Client**: Allow the IDE to control the CLI backend directly via JSON-RPC.
- **Estimated Effort**: 6 weeks, 2 developers, ~2,500 LOC.

## 2. CLUSTER 9: Rust Core + FFI

To achieve maximum performance and memory safety for context management and high-frequency orchestration loops.

- **Core Components in Rust**:
    - `core-ollama`: (~800 LOC)
    - `core-models`: (~600 LOC)
    - `core-context`: (~900 LOC)
    - `core-orchestration`: (~700 LOC)
    - `core-tools`: (~500 LOC)
    - `core-session`: (~400 LOC)
- **FFI Bindings**: (~1,500 LOC) for Go and Swift integration.
- **Rationale**: While the current Go implementation is sufficient for v1.0, the move to Rust will eliminate GC pauses during large context processing and provide a safer foundation for multi-threaded tool execution.
- **Estimated Effort**: 12 weeks, 2 developers.

## 3. Distributed Execution

Extending the single-machine orchestrator to a federated system across multiple nodes.

- **Distributed State Store**: Redis/etcd for shared session state.
- **Worker Pools**: Distributing specialized expert tasks (Coder, Researcher, Vision) to hardware-optimized nodes.
- **mTLS Security**: Encrypted inter-node communication.

---

*Last Updated: 2026-02-10*
