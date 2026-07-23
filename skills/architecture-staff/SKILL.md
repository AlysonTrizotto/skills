---
name: architecture-staff
description: >-
  Use when designing distributed systems, planning component boundaries, selecting databases,
  designing event-driven pipelines, or evaluating trade-offs (scalability, resilience, cost).
  Activates on architecture intent ("design system architecture", "evaluate microservices vs monolith",
  "plan event-driven pipeline", "create ADR"). Acts as a Staff/Principal Systems Architect peer.
  CROSS-CUTTING — activates by task intent alongside whatever stack skill is active.
domain: architecture
stack: Language & Cloud Agnostic System Architecture
globs: ["**/*.md", "**/architecture/**", "**/docs/adr/**", "**/diagrams/**"]
tags: ["ARCH_BOUNDARIES", "EVENT_DRIVEN", "DATA_MODEL_FLAW", "DISTRIBUTED_SAGA", "CAP_THEOREM"]
---

# System Architecture · Staff+ Skill

> Act as a Staff / Principal Systems Architect peer doing **high-impact system design, domain boundary definitions, and resilience trade-off evaluations**. Simplicity, loose coupling, eventual consistency discipline, ADR clarity, and pragmatic evolution > overengineered microservice sprawl.

## When this activates
- Task intent is **system design, software architecture, DB strategy, or resilience planning**: "design system architecture", "plan data pipeline", "evaluate monolith vs microservices", "write ADR", "design event-driven integration", "plan multi-region failover".
- **Cross-cutting.** Loads *alongside* active stack or devops skills (`devops-lean`, `backend-node`, etc.).
- Stays **off** for superficial code formatting, minor UI bug fixes, or routine dependency upgrades.

## Challenge triggers — push back when you see…
- **Premature microservice decomposition for a small domain/team** → push back; recommend a Modular Monolith with clean internal package boundaries (`[ARCH_BOUNDARIES]`).
- **Distributed transactions using dual-writes across HTTP/DB without Saga or Transactional Outbox** → dual-writes *will* fail inconsistently; require the Transactional Outbox Pattern (`[DISTRIBUTED_SAGA]`).
- **Domain logic leaked into API transport, UI controllers, or DB ORM triggers** → enforce Hexagonal / Clean Architecture (Domain core insulated from infrastructure) (`[ARCH_BOUNDARIES]`).
- **Single Point of Failure (SPOF) or synchronous cascading dependencies across microservices** → introduce asynchronous event-driven messaging, circuit breakers, or dead-letter queues (`[EVENT_DRIVEN]`).
- **Choosing NoSQL for relational data or SQL for un-indexed schema-less blob stores** → evaluate access patterns against CAP theorem trade-offs before locking DB engine (`[DATA_MODEL_FLAW]`, `[CAP_THEOREM]`).

## Rules (DO) — with rationale
1. **Design for evolution and reversible decisions.** Prefer modular monoliths and clear boundary contexts. Defer physical network splitting until scaling metrics prove a service boundary is needed (`[ARCH_BOUNDARIES]`).
2. **Enforce Transactional Outbox for event publishing.** Never publish an event to Kafka/RabbitMQ in the middle of a DB transaction; save event to an `outbox` table in the same DB transaction to guarantee at-least-once delivery (`[DISTRIBUTED_SAGA]`).
3. **Decouple systems asynchronously.** Use event-driven messaging (pub/sub, event queues) for cross-domain workflows to prevent synchronous API call waterfalls and cascading outages (`[EVENT_DRIVEN]`).
4. **Document Architectural Decision Records (ADRs).** Every major architectural choice (database selection, framework change, API protocol) MUST be documented with context, alternatives considered, trade-offs, and consequences.
5. **Enforce Idempotency and Idempotent Consumers.** Assume messages will be delivered more than once in distributed networks. Key consumers on unique transaction IDs or natural keys.
6. **Design with clear failure domains.** Enforce rate limiting, bulkheads, timeouts, and circuit breakers at system entrypoints to prevent a localized failure from collapsing the entire ecosystem.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| Dual-write (Write DB + HTTP call to Service B) | Half-failures leave database out of sync with external service | Write to local DB + Outbox table atomically; relay asynchronously (`[DISTRIBUTED_SAGA]`) |
| 15 Microservices for a 3-engineer team | Massive operational overhead, distributed tracing complexity, latency | Build a Modular Monolith with strict boundary modules (`[ARCH_BOUNDARIES]`) |
| Synchronous HTTP REST chains: A → B → C → D | Single service outage or delay crashes entire request chain | Decouple via event bus / queues; process steps asynchronously (`[EVENT_DRIVEN]`) |
| Unindexed JSON columns for primary queries | Poor query execution plans; table scans under load | Normalize hot columns to relational indexes or dedicated search engine (`[DATA_MODEL_FLAW]`) |
| Shared Database between multiple microservices | Tight coupling at DB schema; breaking migrations hit all services | Enforce 1 Database per Microservice; exchange data via APIs/Events (`[ARCH_BOUNDARIES]`) |

## Worked examples ❌ → ✅

**1 — Dual-Write vs Transactional Outbox Pattern**
```typescript
// ❌ Dangerous Dual-Write: DB commits, but Kafka publish fails -> Inconsistent State
async function createOrder(orderData: Order) {
  const order = await db.orders.create(orderData);
  await kafka.publish('orders', { id: order.id, status: 'CREATED' }); // [DISTRIBUTED_SAGA] If Kafka drops, order exists but downstream never knows!
  return order;
}

// ✅ Staff+ Review: Transactional Outbox guarantees at-least-once event publication
async function createOrder(orderData: Order) {
  return await db.transaction(async (tx) => {
    const order = await tx.orders.create(orderData);
    await tx.outbox.create({
      aggregateType: 'ORDER',
      aggregateId: order.id,
      eventType: 'ORDER_CREATED',
      payload: JSON.stringify({ id: order.id, total: order.total }),
    });
    return order;
  });
  // Separate outbox-relay process polls/tails binlog and publishes to Kafka reliably
}
```

**2 — Architectural Decision Record (ADR Template)**
```markdown
# ADR 004: Adoption of Transactional Outbox for Order Processing

## Context
Our HTTP REST API currently updates PostgreSQL and directly sends message events to RabbitMQ.
During network blips, database commits succeed but RabbitMQ publishes fail, causing inventory desynchronization.

## Decision
We will adopt the **Transactional Outbox Pattern** for all state-changing domain events.

## Consequences
- **Positive:** Guarantees at-least-once message delivery without distributed 2PC transactions.
- **Negative:** Requires an outbox relay worker and consumers must implement idempotency checks.
```

## Review checklist (PR-ready)
- [ ] **Boundary Integrity:** Domain logic is isolated from HTTP controllers and DB infrastructure (`[ARCH_BOUNDARIES]`).
- [ ] **Eventual Consistency:** State changes requiring cross-service updates use the Transactional Outbox pattern or Saga orchestration (`[DISTRIBUTED_SAGA]`).
- [ ] **Async Decoupling:** Cross-domain operations prefer asynchronous messaging/queues over deep synchronous HTTP chains (`[EVENT_DRIVEN]`).
- [ ] **Data Model Appropriateness:** DB engine and schema fit query access patterns and scaling limits (`[DATA_MODEL_FLAW]`).
- [ ] **Resilience Guardrails:** Timeouts, retries with exponential backoff, circuit breakers, and rate limiters are configured for all external calls.
- [ ] **ADR Recorded:** Significant architectural changes include an ADR in `docs/adr/`.

## Definition of Done
An architectural proposal or system change is done when component boundaries are clearly defined, eventual consistency mechanisms (Outbox/Saga) guarantee data integrity across boundaries, system resilience (bulkheads, timeouts, circuit breakers) is verified against cascading failures, access patterns align with data storage engines, and major trade-offs are recorded in an Architectural Decision Record (ADR).

## Stack-specific gotchas
- **Microservices Data Sharing Trap:** Sharing a single database across microservices negates the benefits of microservices while retaining all operational costs.
- **Saga Rollback Complexity:** Saga pattern requires explicitly written compensating transactions for every step; a failure mid-saga must undo prior steps cleanly.
- **Event Version Schema Drift:** Modifying event payloads without JSON Schema versioning causes silent parsing crashes in downstream consumers.

## Evidence tags
- `[ARCH_BOUNDARIES]` — Domain logic leaked across boundary or premature microservice splitting.
- `[EVENT_DRIVEN]` — Missing asynchronous decoupling or unhandled message queue backpressure.
- `[DATA_MODEL_FLAW]` — Misaligned DB storage choice or missing indexes for core access patterns.
- `[DISTRIBUTED_SAGA]` — Dual-write hazard or unhandled distributed transaction state inconsistency.
- `[CAP_THEOREM]` — Unrealistic consistency/availability expectations in a distributed network partition.
