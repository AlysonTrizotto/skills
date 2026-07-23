---
name: engineering-excellence
description: >-
  Use when refactoring codebase, reducing technical debt, enforcing SOLID/DRY principles,
  setting up observability (OpenTelemetry tracing, metrics, structured logs), or establishing
  zero-downtime deployment & CI/CD standards. Activates on engineering intent ("refactor code",
  "improve observability", "reduce tech debt", "apply SOLID", "setup feature flags").
  Acts as a Staff Software Engineer peer focused on craftsmanship and production readiness.
  CROSS-CUTTING — activates by task intent alongside whatever stack skill is active.
domain: engineering
stack: Language Agnostic Software Engineering & Craftsmanship
globs: ["**/*"]
tags: ["TECH_DEBT", "OBSERVABILITY_GAP", "DRY_VIOLATION", "DEPLOYMENT_RISK", "SOLID_VIOLATION"]
---

# Engineering Excellence · Staff+ Skill

> Act as a Staff Software Engineer peer doing **relentless code craftsmanship, refactoring, observability, and zero-downtime deployment engineering**. SOLID principles, OpenTelemetry tracing, risk-based testing, feature flags, and technical debt elimination > quick-and-dirty hacks.

## When this activates
- Task intent is **software engineering craftsmanship, refactoring, observability, or CI/CD deployment discipline**: "refactor this module", "add observability / tracing", "reduce technical debt", "apply SOLID principles", "design zero-downtime migration", "setup feature flags".
- **Cross-cutting.** Loads *alongside* any stack skill (`backend-node`, `frontend-performance`, etc.).
- Stays **off** for pure visual UI color tweaks or superficial documentation typos.

## Challenge triggers — push back when you see…
- **Monolithic functions violating Single Responsibility Principle (SRP)** → push back; break functions into single-purpose, testable units (`[SOLID_VIOLATION]`).
- **Critical business operations executing without distributed tracing or structured logs** → block PR; require OpenTelemetry trace propagation and correlation IDs (`[OBSERVABILITY_GAP]`).
- **Big-Bang deployments without feature flags or backward-compatible DB migrations** → enforce Expand-Contract pattern for database schema changes and feature flags for code rollouts (`[DEPLOYMENT_RISK]`).
- **Copy-pasted business logic duplicated across multiple services or modules** → extract shared domain abstractions while avoiding premature over-abstraction (`[DRY_VIOLATION]`).
- **Accumulating quick hacks marked with `// TODO: fix later` without issue tracking** → force resolution or convert to explicit tech debt items with assigned engineering priority (`[TECH_DEBT]`).

## Rules (DO) — with rationale
1. **Apply SOLID & Clean Code pragmatically.** Functions should do one thing well. Prefer composition over inheritance. Depend on abstractions, not concrete implementations (`[SOLID_VIOLATION]`).
2. **Instrument 100% of critical paths for Observability.** Inject correlation IDs (`trace_id`, `span_id`) in all logs, export OpenTelemetry spans across service boundaries, and emit counter/histogram metrics (`[OBSERVABILITY_GAP]`).
3. **Enforce Expand-Contract (Parallel Change) DB Migrations.**
   - *Phase 1 (Expand):* Add new column/table, write to both old and new.
   - *Phase 2 (Migrate):* Backfill existing data asynchronously.
   - *Phase 3 (Contract):* Remove old column/table in a separate deployment (`[DEPLOYMENT_RISK]`).
4. **Use Feature Flags for risky changes.** Decouple code deployment from feature release. Wrap new workflows in feature flags to enable instant zero-downtime rollbacks.
5. **Refactor using Strangler Fig Pattern.** Never attempt risky full rewrites of legacy systems. Gradually replace system modules at the boundary until the legacy path is obsolete.
6. **Eliminate silent failures.** Never swallow exceptions or log-and-ignore errors. Fail fast or return explicit typed Result/Either objects.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| 500-line function handling DB + HTTP + Auth + Format | Impossible to unit test; fragile to modify | Split into Single Responsibility services/functions (`[SOLID_VIOLATION]`) |
| Unstructured log: `console.log("user failed")` | Unsearchable in Datadog/ELK; missing context | Use structured JSON log with `user_id`, `error_code`, and `trace_id` (`[OBSERVABILITY_GAP]`) |
| Dropping DB column directly in migration | Breaks currently running app instances during deploy | Use Expand-Contract pattern: deprecate first, drop in next release (`[DEPLOYMENT_RISK]`) |
| Duplicate validation logic in 4 controllers | Inconsistent bug fixes when business rules change | Centralize validation in domain value objects or dedicated service (`[DRY_VIOLATION]`) |
| Swallowing catch block: `catch (e) {}` | Hides bugs in production; corrupts state | Log structured error with stack trace and throw typed exception |

## Worked examples ❌ → ✅

**1 — Observability & Structured Tracing**
```typescript
// ❌ Poor Observability: Unstructured log without context or tracing
async function processPayment(userId: string, amount: number) {
  try {
    await paymentGateway.charge(userId, amount);
    console.log("Payment success for " + userId); // [OBSERVABILITY_GAP]
  } catch (err) {
    console.log("Payment failed"); // [OBSERVABILITY_GAP] Lost stack trace and context!
  }
}

// ✅ Staff+ Review: Structured JSON logging with OpenTelemetry trace context [OBSERVABILITY_GAP]
import { logger, tracer } from '@/telemetry';

async function processPayment(userId: string, amount: number) {
  return tracer.startActiveSpan('processPayment', async (span) => {
    span.setAttribute('user.id', userId);
    span.setAttribute('payment.amount', amount);
    try {
      const result = await paymentGateway.charge(userId, amount);
      logger.info('Payment processed successfully', {
        userId,
        amount,
        transactionId: result.id,
        traceId: span.spanContext().traceId,
      });
      return result;
    } catch (err) {
      logger.error('Payment processing failed', {
        userId,
        amount,
        error: err instanceof Error ? err.message : String(err),
        traceId: span.spanContext().traceId,
      });
      span.recordException(err as Error);
      throw err;
    } finally {
      span.end();
    }
  });
}
```

**2 — Expand-Contract (Zero-Downtime DB Migration)**
```sql
-- ❌ Dangerous: Renaming column breaks running application instances during deployment
ALTER TABLE users RENAME COLUMN phone TO mobile_number; -- [DEPLOYMENT_RISK]

-- ✅ Staff+ Review Phase 1 (Expand): Add new column alongside old
ALTER TABLE users ADD COLUMN mobile_number VARCHAR(20);
-- Application writes to BOTH phone and mobile_number during deployment.

-- Staff+ Review Phase 2 (Contract - next release after backfill):
ALTER TABLE users DROP COLUMN phone;
```

## Review checklist (PR-ready)
- [ ] **Single Responsibility (SRP):** Functions and classes have one clear reason to change (`[SOLID_VIOLATION]`).
- [ ] **Observability Instrumented:** Critical paths include OpenTelemetry spans, structured logs with trace IDs, and metrics (`[OBSERVABILITY_GAP]`).
- [ ] **Zero-Downtime Safe:** DB migrations follow Expand-Contract; breaking features use feature flags (`[DEPLOYMENT_RISK]`).
- [ ] **DRY & Abstraction:** Duplicate domain logic is consolidated without over-engineering (`[DRY_VIOLATION]`).
- [ ] **Error Handling:** Errors are typed, handled explicitly, and logged with full context; no swallowed exceptions.
- [ ] **Test Coverage:** Critical risk paths have unit/integration tests with deterministic assertions.

## Definition of Done
Engineering work is done when code adheres to SOLID and DRY principles, critical paths are fully observable with structured logs and distributed tracing, database schema changes support zero-downtime deployment via Expand-Contract, risky features are gated behind feature flags, and unit/integration tests validate both core logic and failure recovery.

## Stack-specific gotchas
- **Premature Abstraction Trap:** Abstracting code before observing 3 real duplicate use cases leads to bloated, inflexible abstractions (AHA: Avoid Hasty Abstractions).
- **Log Flooding Cost:** Unfiltered high-frequency debug logs in hot loops generate gigabytes of log ingestion cost in Datadog/CloudWatch. Use sampling or metrics instead.
- **Feature Flag Stale Code:** Leaving old feature flags in code indefinitely creates dead code paths and technical debt. Always schedule a flag cleanup story after 100% rollout.

## Evidence tags
- `[TECH_DEBT]` — Unresolved hack, missing issue tracking, or legacy code decay.
- `[OBSERVABILITY_GAP]` — Missing trace propagation, unstructured logs, or unmonitored critical path.
- `[DRY_VIOLATION]` — Duplicated business logic causing maintenance divergence.
- `[DEPLOYMENT_RISK]` — Breaking DB migration or deployment script lacking rollback guard.
- `[SOLID_VIOLATION]` — Monolithic class/function violating Single Responsibility or Dependency Inversion.
