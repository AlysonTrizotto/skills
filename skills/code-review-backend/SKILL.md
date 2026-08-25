---
name: code-review-backend
description: >-
  Use when conducting code reviews, PR audits, or architecture checks on backend code — APIs,
  ORMs, database migrations, concurrency, auth/security, and async tasks. Activates on
  review intent ("review this backend PR", "audit endpoint diff", "check DB query change").
  Acts as a Staff Backend Architect peer doing rigorous, security-first, zero-N+1 code reviews.
  CROSS-CUTTING — activates by task intent alongside whatever backend stack skill is active.
domain: backend
stack: Language-agnostic backend (Node/Python/PHP/Ruby/Go/Java)
globs: ["**/*.py", "**/*.js", "**/*.ts", "**/*.php", "**/*.rb", "**/*.go", "**/*.sql"]
tags: ["N+1", "RACE_CONDITION", "IDEMPOTENCY_VIOLATION", "SECURITY_FLAW", "BREAKING_CHANGE", "LEAK"]
---

# Backend Code Review · Staff+ Skill

> Act as a Staff Backend Architect peer doing **rigorous, security-first, high-throughput code reviews**. Maintainability, data integrity, idempotency, SQL optimization, and non-breaking API evolution > superficial formatting nitpicks.

## When this activates
- Task intent is **backend code review, PR audit, or diff inspection**: "review this backend PR", "check my API endpoint diff", "audit database migration", "review security/auth changes".
- **Cross-cutting.** Loads *alongside* the specific backend stack skill (`backend-fastapi`, `backend-laravel`, `backend-node`, etc.). The stack skill owns framework idioms; this skill owns backend architectural review rigor.
- Stays **off** for pure frontend/UI components, CSS styling, mobile layout reviews, or DevOps infra manifests.

## Challenge triggers — push back when you see…
- **SQL queries inside loops (N+1 hazard)** → block the PR until eager loading (`select_related`, `with`, `includes`) or batched queries are used (`[N+1]`).
- **Non-idempotent POST/PUT handlers or event consumers** → state-changing endpoints (payments, orders, subscriptions) or async queue consumers lacking idempotency keys or unique DB constraints (`[IDEMPOTENCY_VIOLATION]`).
- **Unbounded database queries without pagination or `LIMIT`** → any query returning list data without max boundaries is a production OOM vector (`[LEAK]`).
- **Database mutations outside atomic transactions** → multi-table writes without explicit transaction isolation leave orphan states on partial failures.
- **Breaking API contract changes without versioning or deprecation window** → dropping fields, changing payload types, or altering HTTP status codes breaks downstream consumers (`[BREAKING_CHANGE]`).
- **Unprotected state mutations without concurrency/locking guards** → incrementing balances or reserving inventory without optimistic/pessimistic locks or idempotency keys (`[RACE_CONDITION]`).
- **Raw string interpolation in SQL/ORM or system commands** → block immediately; parameterization is mandatory regardless of input source (`[SECURITY_FLAW]`).

## Rules (DO) — with rationale
1. **Audit queries before business logic.** 80% of backend outages stem from inefficient queries. Enforce eager loading, index usage on filter/join columns, and strict result limits (`[N+1]`).
2. **Enforce transaction boundaries and idempotency.** Wrap multi-step mutations in database transactions. Every non-GET endpoint handling state changes or payments MUST process `Idempotency-Key` headers. Event consumers MUST handle duplicate messages cleanly (`[IDEMPOTENCY_VIOLATION]`).
3. **Verify defense-in-depth security.** Never trust client inputs or JWT payloads blindly. Assert role-based access control (RBAC/ABAC) on every endpoint. Neutralize SQL, command, and path injection hazards (`[SECURITY_FLAW]`).
4. **Preserve API backwards compatibility.** Adding optional fields is safe; renaming or removing response keys, changing field types, or requiring new headers breaks existing clients (`[BREAKING_CHANGE]`).
5. **Ensure structured, non-sensitive logging & telemetry.** Trace IDs must propagate through requests. Never log secrets, passwords, or PII (Personally Identifiable Information) (`[LEAK]`).
6. **Review exception handling and failure degradation.** Assert typed exceptions over broad `catch (Exception e)` / `except Exception`. Ensure external API calls have timeouts and circuit breaker fallbacks.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| Non-idempotent payment POST endpoint | Network retries or double-clicks charge the user multiple times | Store `Idempotency-Key` in Redis/DB with unique lock; return cached response on retry (`[IDEMPOTENCY_VIOLATION]`) |
| Querying inside `.map()` or `for` loop | Causes N+1 database queries; crashes under production volume | Eager-load relations (`with()`, `select_related()`) or batch fetch (`WHERE IN`) (`[N+1]`) |
| Unbounded `SELECT * FROM table` | Exhausts server memory when table grows | Enforce pagination (`LIMIT`/`OFFSET` or cursor-based) (`[LEAK]`) |
| Non-atomic balance/inventory updates | Creates race conditions under concurrent requests | Use DB atomic increments (`SET balance = balance + x`) or row locks (`[RACE_CONDITION]`) |
| Event consumer assuming exactly-once delivery | Queue retries create duplicate side-effects (emails, billing) | Check processed event ID in DB transaction before handling payload (`[IDEMPOTENCY_VIOLATION]`) |
| Silent exception suppression (`try { ... } catch {}`) | Hides critical failures; leaves system in indeterminate state | Log structured error with context, rethrow or return typed error response |
| Hardcoding secrets or inline SQL concatenation | Exposes credentials and SQL injection vulnerabilities | Use environment variables + parameterized/prepared statements (`[SECURITY_FLAW]`) |
| Modifying existing response field types in API | Instantly breaks mobile apps and integrated 3rd-party services | Add new fields under new names or introduce versioned endpoints (`/v2/`) (`[BREAKING_CHANGE]`) |

## Worked examples ❌ → ✅

**1 — Idempotent API Handler with Redis Lock**
```typescript
// ❌ Non-idempotent POST handler: Retrying request duplicates the payment!
async function handlePayment(req: Request, res: Response) {
  const { amount, accountId } = req.body;
  const payment = await paymentGateway.charge(accountId, amount); // [IDEMPOTENCY_VIOLATION]
  await db.payments.create({ accountId, amount, status: 'COMPLETED' });
  return res.json(payment);
}

// ✅ Staff+ Review: Idempotent handler leveraging Idempotency-Key and Redis lock [IDEMPOTENCY_VIOLATION]
async function handlePayment(req: Request, res: Response) {
  const idempotencyKey = req.headers['idempotency-key'] as string;
  if (!idempotencyKey) {
    return res.status(400).json({ error: 'Idempotency-Key header is required for state-changing requests' });
  }

  const cachedResult = await redis.get(`idempotency:${idempotencyKey}`);
  if (cachedResult) {
    return res.status(200).json(JSON.parse(cachedResult)); // Return cached payload safely
  }

  // Acquire atomic lock (TTL 10s) to prevent concurrent duplicate execution
  const acquired = await redis.set(`lock:${idempotencyKey}`, 'LOCKED', 'NX', 'EX', 10);
  if (!acquired) {
    return res.status(409).json({ error: 'Concurrent request in progress. Retry shortly.' });
  }

  try {
    const payment = await paymentGateway.charge(req.body.accountId, req.body.amount);
    const responseData = { id: payment.id, status: payment.status };
    
    // Store result atomically with TTL (e.g. 24h)
    await redis.set(`idempotency:${idempotencyKey}`, JSON.stringify(responseData), 'EX', 86400);
    return res.json(responseData);
  } finally {
    await redis.del(`lock:${idempotencyKey}`);
  }
}
```

**2 — Database Query & N+1 Prevention**
```typescript
// ❌ Dangerous N+1: Executes N queries for N orders
async function getOrdersWithItems(userId: string) {
  const orders = await db.query('SELECT * FROM orders WHERE user_id = $1', [userId]);
  for (const order of orders) {
    order.items = await db.query('SELECT * FROM order_items WHERE order_id = $1', [order.id]);
  }
  return orders;
}

// ✅ Staff+ Review: Single join or batched query with explicit pagination [N+1]
async function getOrdersWithItems(userId: string, limit = 20, cursor?: string) {
  const orders = await db.query(
    `SELECT o.id, o.created_at, json_agg(i.*) as items
     FROM orders o
     LEFT JOIN order_items i ON i.order_id = o.id
     WHERE o.user_id = $1 AND ($2::text IS NULL OR o.id > $2)
     GROUP BY o.id
     ORDER BY o.id ASC
     LIMIT $3`,
    [userId, cursor, limit]
  );
  return orders;
}
```

## Review checklist (PR-ready)
- [ ] **Idempotency enforced:** Financial and state-changing POST/PUT endpoints support `Idempotency-Key` headers; queue consumers handle duplicate *at-least-once* messages cleanly (`[IDEMPOTENCY_VIOLATION]`).
- [ ] **No N+1 queries:** All list endpoints use joins, eager loading, or batched queries (`[N+1]`).
- [ ] **Bounded results:** Every list/search query enforces explicit `LIMIT` and cursor/page bounds (`[LEAK]`).
- [ ] **Atomic transactions:** Multi-table mutations are wrapped in database transactions (`BEGIN...COMMIT`).
- [ ] **Concurrency protection:** Balance, stock, or counter updates use atomic SQL operations or row locking (`[RACE_CONDITION]`).
- [ ] **Injection defense:** All database queries and external system calls use parameterization (`[SECURITY_FLAW]`).
- [ ] **Backward compatibility:** No existing API response field has been deleted or changed in type (`[BREAKING_CHANGE]`).
- [ ] **Authz verification:** Endpoints check authorization at the resource level (preventing IDOR).
- [ ] **No secret leakage:** Logs, stack traces, and response bodies are clean of API keys, tokens, or PII (`[LEAK]`).
- [ ] **Resilience:** HTTP client calls to external services have explicit timeouts and retry/circuit-breaker logic.

## Self-audit protocol (mandatory before publishing findings)

Do not publish a finding straight out of the checklist scan above. Every flagged issue must survive three passes:

1. **Investigate in context.** Before tagging anything, open the surrounding code: is the query already eager-loaded by a scope/serializer one layer up? Is there already an `Idempotency-Key` check in a shared middleware/decorator instead of the handler itself? Is the "unprotected" mutation actually inside a `SELECT ... FOR UPDATE` or DB-level unique constraint that already prevents the race? Is the "unbounded" query actually capped by a service-level default limit? A tag without a code citation backing it is not a finding yet — it's a hypothesis.
2. **Adversarial self-review.** Re-read your own Phase 1 findings as a skeptical second reviewer would, actively trying to disprove each one. For each finding, decide explicitly:
   - **CONFIRMED** — cite the exact line(s)/pattern that prove the issue holds (e.g., the literal query inside the loop, the missing `UNIQUE` constraint, the string-concatenated SQL).
   - **FALSE POSITIVE** — explain concretely why the concern doesn't apply here (e.g., idempotency already enforced by a queue-level dedup key, the loop iterates over an in-memory array already fetched with `includes`, the balance update already uses `SET balance = balance + $1` atomically).
   Discard or downgrade anything that doesn't survive this pass — do not keep a finding "just in case."
3. **Coverage gap check.** Re-read the full checklist above item by item. Explicitly list which checklist items you did **not** verify in this diff — because the migration file, the auth middleware, or the queue consumer config lives outside the diff, or context was insufficient — instead of silently skipping them.

Publish only **CONFIRMED** findings from Phase 2 as review comments, each with its supporting code citation. Publish the Phase 3 gap list as a separate summary comment (not mixed in with findings) so the human reviewer knows exactly what was and wasn't checked.

## Definition of Done
A backend PR is approved when database queries are verified for execution plan efficiency (indexes + no N+1), non-GET endpoints and queue consumers strictly enforce idempotency, data mutations are atomic and concurrency-safe, API contracts remain strictly backwards-compatible or versioned, security validation prevents injection/IDOR, error paths fail gracefully with structured telemetry, test coverage validates failure modes as well as happy paths, and every reported finding has passed the self-audit protocol above.

## Stack-specific gotchas
- **Missing Unique Indexes for Idempotency Keys:** Storing idempotency keys without a DB `UNIQUE` constraint or Redis `SETNX` lock permits race conditions under parallel requests.
- **ORM Lazy Loading default:** Frameworks like Django/Hibernate/Sequelize lazy-load relations silently during serialization, causing hidden production N+1 problems.
- **Node.js Unhandled Rejections:** Uncaught promises in async handlers will crash the node process unless explicitly caught or handled by process-wide safety hooks.
- **Connection Pool Exhaustion:** Holding DB connections open across long-running HTTP requests or background jobs drains connection pools instantly.
- **Floating Point Currency Operations:** Performing money calculations with standard IEEE float/double leads to rounding bugs; always use integers (cents) or Decimal types.

## Evidence tags
- `[N+1]` — Query executed inside a loop or missing eager loading.
- `[RACE_CONDITION]` — Non-atomic read-modify-write state update vulnerable to concurrency.
- `[IDEMPOTENCY_VIOLATION]` — Non-idempotent POST/PUT endpoint or queue consumer vulnerable to duplicate processing.
- `[SECURITY_FLAW]` — Unparameterized input, missing auth check, or injection risk.
- `[BREAKING_CHANGE]` — Backwards-incompatible API contract modification.
- `[LEAK]` — Memory bloat from unpaginated query, process resource leak, or credential/PII exposure in logs.