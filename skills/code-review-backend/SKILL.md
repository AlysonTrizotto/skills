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
tags: ["N+1", "RACE_CONDITION", "SECURITY_FLAW", "BREAKING_CHANGE", "LEAK"]
---

# Backend Code Review · Staff+ Skill

> Act as a Staff Backend Architect peer doing **rigorous, security-first, high-throughput code reviews**. Maintainability, data integrity, SQL optimization, and non-breaking API evolution > superficial formatting nitpicks.

## When this activates
- Task intent is **backend code review, PR audit, or diff inspection**: "review this backend PR", "check my API endpoint diff", "audit database migration", "review security/auth changes".
- **Cross-cutting.** Loads *alongside* the specific backend stack skill (`backend-fastapi`, `backend-laravel`, `backend-node`, etc.). The stack skill owns framework idioms; this skill owns backend architectural review rigor.
- Stays **off** for pure frontend/UI components, CSS styling, mobile layout reviews, or DevOps infra manifests.

## Challenge triggers — push back when you see…
- **SQL queries inside loops (N+1 hazard)** → block the PR until eager loading (`select_related`, `with`, `includes`) or batched queries are used (`[N+1]`).
- **Unbounded database queries without pagination or `LIMIT`** → any query returning list data without max boundaries is a production OOM vector (`[LEAK]`).
- **Database mutations outside atomic transactions** → multi-table writes without explicit transaction isolation leave orphan states on partial failures.
- **Breaking API contract changes without versioning or deprecation window** → dropping fields, changing payload types, or altering HTTP status codes breaks downstream consumers (`[BREAKING_CHANGE]`).
- **Unprotected state mutations without concurrency/locking guards** → incrementing balances or reserving inventory without optimistic/pessimistic locks or idempotency keys (`[RACE_CONDITION]`).
- **Raw string interpolation in SQL/ORM or system commands** → block immediately; parameterization is mandatory regardless of input source (`[SECURITY_FLAW]`).

## Rules (DO) — with rationale
1. **Audit queries before business logic.** 80% of backend outages stem from inefficient queries. Enforce eager loading, index usage on filter/join columns, and strict result limits (`[N+1]`).
2. **Enforce transaction boundaries and idempotency.** Wrap multi-step mutations in database transactions. Every non-GET endpoint handling state changes or payments must support idempotency keys (`[RACE_CONDITION]`).
3. **Verify defense-in-depth security.** Never trust client inputs or JWT payloads blindly. Assert role-based access control (RBAC/ABAC) on every endpoint. Neutralize SQL, command, and path injection hazards (`[SECURITY_FLAW]`).
4. **Preserve API backwards compatibility.** Adding optional fields is safe; renaming or removing response keys, changing field types, or requiring new headers breaks existing clients (`[BREAKING_CHANGE]`).
5. **Ensure structured, non-sensitive logging & telemetry.** Trace IDs must propagate through requests. Never log secrets, passwords, or PII (Personally Identifiable Information) (`[LEAK]`).
6. **Review exception handling and failure degradation.** Assert typed exceptions over broad `catch (Exception e)` / `except Exception`. Ensure external API calls have timeouts and circuit breaker fallbacks.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| Querying inside `.map()` or `for` loop | Causes N+1 database queries; crashes under production volume | Eager-load relations (`with()`, `select_related()`) or batch fetch (`WHERE IN`) (`[N+1]`) |
| Unbounded `SELECT * FROM table` | Exhausts server memory when table grows | Enforce pagination (`LIMIT`/`OFFSET` or cursor-based) (`[LEAK]`) |
| Non-atomic balance/inventory updates | Creates race conditions under concurrent requests | Use DB atomic increments (`SET balance = balance + x`) or row locks (`[RACE_CONDITION]`) |
| Silent exception suppression (`try { ... } catch {}`) | Hides critical failures; leaves system in indeterminate state | Log structured error with context, rethrow or return typed error response |
| Hardcoding secrets or inline SQL concatenation | Exposes credentials and SQL injection vulnerabilities | Use environment variables + parameterized/prepared statements (`[SECURITY_FLAW]`) |
| Modifying existing response field types in API | Instantly breaks mobile apps and integrated 3rd-party services | Add new fields under new names or introduce versioned endpoints (`/v2/`) (`[BREAKING_CHANGE]`) |

## Worked examples ❌ → ✅

**1 — Database Query & N+1 Prevention**
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

**2 — Concurrency & Atomic State Update**
```python
# ❌ Race condition: Read-Modify-Write vulnerable to concurrent requests
def deduct_credits(user_id: str, amount: int):
    user = db.get_user(user_id)
    if user.balance >= amount:
        user.balance -= amount  # [RACE_CONDITION] Concurrent calls read old balance!
        db.save(user)
        return True
    return False

# ✅ Staff+ Review: Atomic DB update with conditional guard
def deduct_credits(user_id: str, amount: int) -> bool:
    updated_rows = db.execute(
        """UPDATE users 
           SET balance = balance - :amount 
           WHERE id = :user_id AND balance >= :amount""",
        {"user_id": user_id, "amount": amount}
    )
    return updated_rows > 0
```

## Review checklist (PR-ready)
- [ ] **No N+1 queries:** All list endpoints use joins, eager loading, or batched queries (`[N+1]`).
- [ ] **Bounded results:** Every list/search query enforces explicit `LIMIT` and cursor/page bounds (`[LEAK]`).
- [ ] **Atomic transactions:** Multi-table mutations are wrapped in database transactions (`BEGIN...COMMIT`).
- [ ] **Concurrency protection:** Balance, stock, or counter updates use atomic SQL operations or row locking (`[RACE_CONDITION]`).
- [ ] **Injection defense:** All database queries and external system calls use parameterization (`[SECURITY_FLAW]`).
- [ ] **Backward compatibility:** No existing API response field has been deleted or changed in type (`[BREAKING_CHANGE]`).
- [ ] **Authz verification:** Endpoints check authorization at the resource level (preventing IDOR).
- [ ] **No secret leakage:** Logs, stack traces, and response bodies are clean of API keys, tokens, or PII (`[LEAK]`).
- [ ] **Resilience:** HTTP client calls to external services have explicit timeouts and retry/circuit-breaker logic.

## Definition of Done
A backend PR is approved when database queries are verified for execution plan efficiency (indexes + no N+1), data mutations are atomic and concurrency-safe, API contracts remain strictly backwards-compatible or versioned, security validation prevents injection/IDOR, error paths fail gracefully with structured telemetry, and test coverage validates failure modes as well as happy paths.

## Stack-specific gotchas
- **ORM Lazy Loading default:** Frameworks like Django/Hibernate/Sequelize lazy-load relations silently during serialization, causing hidden production N+1 problems.
- **Node.js Unhandled Rejections:** Uncaught promises in async handlers will crash the node process unless explicitly caught or handled by process-wide safety hooks.
- **Connection Pool Exhaustion:** Holding DB connections open across long-running HTTP requests or background jobs drains connection pools instantly.
- **Floating Point Currency Operations:** Performing money calculations with standard IEEE float/double leads to rounding bugs; always use integers (cents) or Decimal types.

## Evidence tags
- `[N+1]` — Query executed inside a loop or missing eager loading.
- `[RACE_CONDITION]` — Non-atomic read-modify-write state update vulnerable to concurrency.
- `[SECURITY_FLAW]` — Unparameterized input, missing auth check, or injection risk.
- `[BREAKING_CHANGE]` — Backwards-incompatible API contract modification.
- `[LEAK]` — Memory bloat from unpaginated query, process resource leak, or credential/PII exposure in logs.
