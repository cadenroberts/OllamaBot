# Distributed Execution Considerations

This document outlines the architectural considerations for extending `ollamabot` from a single-machine orchestrator to a distributed execution system.

## 1. State Consistency & Synchronization

Moving to multiple machines requires a distributed state store (e.g., Redis, etcd) instead of local `UserDefaults` or file-based persistence.

- **Global Locks**: Prevention of multiple workers claiming the same job or advancing the same orchestration session simultaneously.
- **Event Bus**: Using NATS or RabbitMQ to propagate state changes (Schedule/Process transitions) to all connected UI clients.
- **Clock Synchronization**: Ensuring consistent timestamps across nodes for accurate duration tracking and log ordering.

## 2. Payload Distribution & Locality

Payloads (currently `@file:`, `@cmd:`, etc.) assume local file system access.

- **Distributed File System**: Using S3, MinIO, or EFS to ensure that `@file:path/to/spec` points to the same content regardless of which worker node executes the job.
- **Worker Affinity**: Routing jobs to specific workers based on data locality (e.g., if a worker already has a warm Git clone of the target repo).
- **Containerization**: Wrapping job execution in Docker/Podman to ensure consistent runtime environments across heterogeneous nodes.

## 3. Resource Monitoring (Distributed)

The current `internal/resource/monitor.go` tracks local process metrics.

- **Aggregated Metrics**: Collecting CPU/RAM/Disk/Token usage from all worker nodes into a central dashboard (Prometheus/Grafana).
- **Distributed Token Budgets**: Managing global token limits across multiple LLM API keys or local Ollama instances.
- **Node Health**: Monitoring worker heartbeat and auto-recovering jobs from failed nodes.

## 4. LLM-as-Judge (Federated)

Expert models (Coder, Researcher, Vision) can be distributed to specialized hardware.

- **Model Placement**: Running Vision models on nodes with high VRAM, while light RAG models can run on CPU-optimized nodes.
- **Synthesis Node**: Dedicated node for aggregating expert reports and generating the final TLDR to minimize latency.

## 5. Security & Isolation

- **mTLS**: Ensuring all inter-node communication (Worker ↔ Orchestrator ↔ State Store) is encrypted and authenticated.
- **Sandbox execution**: Using Firecracker or gVisor for worker execution to prevent cross-node contamination or unauthorized host access.
