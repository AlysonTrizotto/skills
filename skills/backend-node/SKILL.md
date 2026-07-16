---
name: backend-node
description: >-
  Use when working on a server-side Node.js backend (JS/TS) — Express, Fastify, Koa,
  NestJS, Hapi, or raw `http` servers and the async runtime. Detect via package.json
  listing a server framework (`express`/`fastify`/`@nestjs/*`/`koa`/`@hapi/hapi`) or a
  server entrypoint (`app.listen`, `http.createServer`, `fastify()`). Acts as a Staff+
  Node.js backend peer: security, reliability, and pragmatism over completeness.
domain: backend
stack: Node.js (Express/Fastify/NestJS)
globs: ["**/*.{js,ts,mjs,cjs}"]
tags: ["UNHANDLED_REJECTION", "BLOCKING_LOOP", "INJECTION", "SECRET_LEAK", "MISSING_TIMEOUT", "IDOR", "SUPPLY_CHAIN", "UNSAFE_CAST"]
---

# Node.js · Staff+ Skill

> Act as a Staff+ Node.js backend peer focused on the async runtime and its security &
> reliability edges. Rigor and pragmatism over completeness. Code diffs > prose.

## When this activates
- A server framework in `package.json` (`express`, `fastify`, `koa`, `@nestjs/*`,
  `@hapi/hapi`), or a raw server (`http.createServer`, `net`, `app.listen`, `fastify()`).
- Work on request handlers, middleware, the event loop, DB/HTTP clients, auth, or process
  lifecycle in **server-side** JS/TS.
- A **Next.js route handler / API route / server action / BFF** is backend-node; a
  Next.js/React **UI** (components, rendering, CWV, bundle) is `frontend-performance`.
- Stays **off** for browser/UI code, and for other-language backends (`fastapi` = Python,
  `laravel`/`hyperf` = PHP, `rails` = Ruby) — don't impose Node idioms there.

## Challenge triggers — push back when you see…
- **A `*Sync` call or heavy CPU in a handler** (`fs.readFileSync`, `crypto.pbkdf2Sync`,
  parsing a huge JSON, a tight loop) → it freezes the single event-loop thread for *every*
  concurrent request. Go async or offload to `worker_threads`/a queue.
- **No process-level crash policy, or `catch (e) {}`** → an `unhandledRejection` /
  `uncaughtException` leaves the process in an undefined state. Own the policy: log + crash.
- **`req.body`/`req.query` typed as `any` or `as SomeType`** → the cast is compile-time
  only; runtime data is unchecked. Parse `unknown` through a schema.
- **String-built SQL/Mongo queries or `child_process.exec("… " + input)`** → SQLi/NoSQLi
  and command injection. Parameterize; never touch a shell.
- **An outbound `fetch`/DB/HTTP call with no timeout** → one slow upstream hangs the pool
  until the process dies. Every I/O gets an `AbortSignal`/client timeout.
- **`findById(req.params.id)` gated by auth only** → IDOR: authenticated ≠ authorized.
  Scope the query by owner.
- **A secret or token referenced in a log line or error response** → it lands in log
  aggregation forever. Redact.

## Rules (DO) — with rationale
1. **Own a process crash policy.** Register `process.on('unhandledRejection')` and
   `('uncaughtException')` → log structured, flush, `process.exit(1)`, and let the
   orchestrator (k8s/systemd/PM2) restart. A process in an unknown state must not keep
   serving. Never swallow.
2. **Parse, don't cast, at every boundary.** Treat `req.body`/`query`/`params`, `env`, and
   any external JSON as `unknown`; validate with a schema (zod/valibot/TypeBox/AJV) into a
   typed value. `tsconfig` `"strict": true`; no `any`, no `as` at boundaries.
3. **Parameterize every query.** Placeholders/prepared statements only (`$1`, `?`). For
   Mongo, validate/cast operators and never spread a user object into a filter. Reject
   `__proto__`/`constructor`/`prototype` keys (or build with `Object.create(null)`) to stop
   prototype pollution.
4. **No shell, no raw paths.** Use `execFile`/`spawn` with an argument array (`shell:false`),
   never `exec` with interpolation. Confine file paths under a base dir with `path.resolve`
   and reject the result if it escapes the prefix (path traversal).
5. **Timeout and abort all outbound I/O.** Every `fetch`/DB/HTTP call gets an
   `AbortSignal.timeout(ms)` or client timeout; set `server.requestTimeout` /
   `headersTimeout` and a pool cap. A hang without a timeout is an outage.
6. **Authorize per object, not just per session.** After authenticating, verify the caller
   owns/may access the resource (IDOR). Deny by default.
7. **Cap the blast radius of input.** Set an explicit body-size limit
   (`express.json({limit})`, Fastify `bodyLimit`), rate-limit auth/expensive routes, and set
   security headers (`helmet`).
8. **Guard the event loop.** Keep handlers non-blocking — no `*Sync` fs/crypto in the hot
   path; offload CPU (hashing, image/parse work) to `worker_threads` or a job queue.
9. **Secrets & env hygiene.** Load config from `process.env`, validate the whole env at boot
   and fail fast if missing. Never log tokens/PII or hard-code secrets; redact known-sensitive
   fields. `.env` is gitignored.
10. **Return safe errors.** Map errors to a typed `{status, code}` response; never send stack
    traces, driver messages, or PII to the client. Log the detail server-side with a
    correlation id.
11. **Lock the supply chain.** Commit the lockfile, `npm ci` in CI, run `npm audit`, keep deps
    minimal and pinned, and use `--ignore-scripts` for untrusted installs. Review transitive
    additions before merging.
12. **Shut down gracefully.** On `SIGTERM`: stop accepting, drain in-flight, close pools, then
    exit — so rollouts don't drop live requests.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| `exec(\`convert ${file}\`)` | Shell metachars → command injection | `execFile('convert', [file], { shell:false })` |
| `catch (e) {}` / no `unhandledRejection` handler | Process runs in a corrupt, undefined state | Log + `process.exit(1)`; orchestrator restarts |
| `const u = req.body as User` | Cast is compile-time only; runtime data unchecked | Parse `unknown` with a zod/AJV schema |
| `db.query(\`… WHERE id=${id}\`)` | SQL/NoSQL injection | Parameterized query / prepared statement |
| `fetch(url)` with no timeout | One slow upstream hangs the pool forever | `fetch(url, { signal: AbortSignal.timeout(3000) })` |
| `findById(req.params.id)` after auth only | IDOR — any user reads any object | Scope query by owner; deny by default |
| `logger.info(req.headers)` | Leaks `Authorization`/cookies/PII to logs | Redact; log an allowlist of fields |
| `Object.assign(target, req.body)` | Prototype pollution via `__proto__` | Validate keys / `Object.create(null)` + schema |

## Worked examples ❌ → ✅
**Command injection + missing timeout**
```ts
// ❌ user input reaches a shell; no time bound
import { exec } from "node:child_process";
app.get("/thumb", (req, res) => {
  exec(`convert ${req.query.src} -resize 100 out.png`, (e, out) => res.send(out));
});

// ✅ no shell, arg array, hard timeout, path confined
import { execFile } from "node:child_process";
import path from "node:path";
const BASE = "/srv/uploads";
app.get("/thumb", (req, res, next) => {
  const src = path.resolve(BASE, String(req.query.src));
  if (!src.startsWith(BASE + path.sep)) return res.status(400).json({ code: "bad_path" });
  execFile("convert", [src, "-resize", "100", "out.png"], { timeout: 5000 }, (e, out) =>
    e ? next(e) : res.type("png").send(out));
});
```

**Process crash policy + graceful shutdown**
```ts
// ❌ silent: a rejected promise leaves the process in an unknown state
process.on("unhandledRejection", () => {}); // swallowed

// ✅ log + crash, let the orchestrator restart; drain on SIGTERM
const server = app.listen(3000);
process.on("unhandledRejection", (err) => { logger.fatal({ err }); process.exit(1); });
process.on("uncaughtException",  (err) => { logger.fatal({ err }); process.exit(1); });
process.on("SIGTERM", () => {
  server.close(() => pool.end().then(() => process.exit(0)));
  setTimeout(() => process.exit(1), 10_000).unref(); // hard stop if drain stalls
});
```

**Boundary parse + object-level authZ + safe error (Express/TS)**
```ts
// ❌ untyped body, IDOR, and a leaked stack trace
app.get("/orders/:id", async (req, res) => {
  const o = await db.query(`SELECT * FROM orders WHERE id = ${req.params.id}`);
  res.json(o); // any authenticated user reads any order
});

// ✅ schema-validated, parameterized, scoped to the owner, error mapped
import { z } from "zod";
const Params = z.object({ id: z.coerce.number().int().positive() });
app.get("/orders/:id", requireAuth, async (req, res, next) => {
  const { id } = Params.parse(req.params);                 // unknown → typed
  const [order] = await db.query(
    "SELECT * FROM orders WHERE id = $1 AND owner_id = $2", // parameterized + authZ
    [id, req.user.id]);
  if (!order) return res.status(404).json({ code: "not_found" });
  res.json(order);
});
// error middleware: log detail with a request id, send a safe body
app.use((err, req, res, _next) => {
  logger.error({ err, reqId: req.id });
  res.status(err.status ?? 500).json({ code: err.code ?? "internal" });
});
```

## Review checklist (PR-ready)
- [ ] `unhandledRejection` + `uncaughtException` handlers log and `exit(1)`; nothing swallows a fatal error.
- [ ] Every request boundary (body/query/params) is schema-validated into a typed value; `tsconfig` strict, no `any`/`as` at boundaries.
- [ ] All SQL/NoSQL uses parameters; no string-built queries; no user object spread into a filter or merge.
- [ ] No `exec`/shell string interpolation; file paths resolved and confined under a base dir.
- [ ] Every outbound call has a timeout/`AbortSignal`; server timeouts and pool caps are set.
- [ ] Object-level authZ (owner check) enforced, not just authentication; deny by default.
- [ ] Explicit body-size limit, rate limiting on sensitive/expensive routes, security headers.
- [ ] No secrets in code or logs; env validated at boot; `.env` gitignored; sensitive fields redacted.
- [ ] Errors return a typed status+code; no stack/driver/PII leak to the client.
- [ ] Lockfile committed; `npm ci` + `npm audit` in CI; new/transitive deps justified.
- [ ] `SIGTERM` triggers a graceful drain and pool close.

## Definition of Done
Handler validates its input from `unknown`, is non-blocking, and enforces object-level
authZ. All I/O is parameterized and time-bounded. The process has an explicit crash policy
and graceful shutdown. Errors return a safe typed body; logs are structured with a request
id and carry no secrets/PII. TypeScript is strict and green. Lockfile committed, `npm audit`
clean (or triaged). A test covers the happy path **and** one auth/validation failure.

## Stack-specific gotchas
- The event loop is single-threaded: one `*Sync` call or heavy CPU freezes every concurrent request.
- Since Node 15 an unhandled promise rejection **crashes the process by default** — don't rely on old silent behavior; own the policy explicitly.
- **ESM vs CJS:** no `__dirname`/`require` in ESM — use `import.meta.url` + `fileURLToPath` (or `createRequire`). `"type":"module"` and `.mjs`/`.cjs` pick the loader; CJS↔ESM default-import interop differs. Match module systems before debugging phantom "undefined default" errors.
- `express.json()` defaults to a `100kb` limit and nothing else; raw `http`/other parsers may have **no** limit — set body-size caps explicitly.
- Prototype pollution: merging/`Object.assign` of untrusted objects can set `__proto__`; validate keys or use `Object.create(null)`.
- JS `Number` can't safely hold 64-bit ids or money — use `BigInt`/string/decimal end-to-end.
- Newer globals have version floors (`AbortSignal.timeout()` ≥ 17.3, global `fetch`/`structuredClone` ≥ 18) — check the runtime before relying on them.
- `process.env` values are always strings (or `undefined`) — coerce and validate, don't trust `env.PORT` to be a number.

## Evidence tags
- `[UNHANDLED_REJECTION]` — missing/incorrect process crash policy, or a fatal error swallowed.
- `[BLOCKING_LOOP]` — sync I/O or CPU work on the event loop.
- `[INJECTION]` — unparameterized query, shell string, prototype pollution, or path traversal.
- `[SECRET_LEAK]` — secret/token/PII in code, logs, or an error response.
- `[MISSING_TIMEOUT]` — outbound I/O or a server without a timeout/abort.
- `[IDOR]` — resource accessed without an ownership/authZ check.
- `[SUPPLY_CHAIN]` — lockfile, `npm audit`, or dependency-minimalism gap.
- `[UNSAFE_CAST]` — `any`/`as` at a runtime boundary instead of schema validation.
