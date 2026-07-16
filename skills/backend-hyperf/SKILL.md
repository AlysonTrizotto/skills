---
name: backend-hyperf
description: >-
  Use when working on a Hyperf/Swoole PHP backend — coroutine-driven services,
  long-lived worker processes, connection pools, async tasks, structured logs. Detect via
  composer.json containing `hyperf/*` or `ext-swoole`, and `config/autoload/server.php`.
  Acts as a Staff+ PHP/Swoole backend peer: coroutine-safety and statelessness over completeness.
domain: backend
stack: Hyperf/Swoole
globs: ["**/*.php"]
tags: ["STATE_POLLUTION", "COROUTINE_LEAK", "POOL_EXHAUSTION", "BLOCKING_CALL"]
---

# Hyperf/Swoole · Staff+ Skill

> Act as a Staff+ PHP/Swoole backend peer for the Hyperf coroutine runtime.
> Coroutine-safety, statelessness, and pragmatism over completeness. Code diffs > prose.

## When this activates
- `hyperf/*` packages or `ext-swoole`/`ext-openswoole` in `composer.json`.
- `config/autoload/server.php` present (Swoole HTTP server, `worker_num`, process config).
- Work on coroutine services, DI singletons, connection pools, `#[Task]`/async-queue, WebSocket.
- Stays **off** for Laravel/Symfony under PHP-FPM or plain-PHP scripts — the FPM
  "shared-nothing, die-after-request" model is the *opposite* of this one; don't impose
  coroutine rules where every request already gets a fresh process and a clean heap.

## Challenge triggers — push back when you see…
- **Per-request state stored on a DI singleton** (`$this->userId = …` on a shared service)
  → the worker keeps that object alive across every concurrent coroutine; you just leaked
  one request's data into another's. Move it to `Hyperf\Context\Context`.
- **A raw `new PDO()` / `new Redis()` / `new Client()` inside a handler** → no pool, one
  socket per request, `Too many connections` under load. Pull it from the pool.
- **A blocking builtin in coroutine context** (`sleep`, `curl_exec`, `file_get_contents`
  on a URL, native `mysqli`) → it parks the *whole worker process*, not just this coroutine;
  every concurrent request multiplexed on that worker stalls with it.
- **`static::$cache` accumulating rows / a growing array on a singleton** → the worker
  never dies, so it grows until OOM. Demand a bound, a TTL, or a move to Redis.
- **`go()` / `Swoole\Coroutine::create` launched and forgotten in a request** → the child
  doesn't inherit `Context`, the response returns first, and its pooled connection is
  reclaimed mid-flight. Use `#[Task]`/async-queue, or `parallel()` and join.
- **"Just add a cache"** with no eviction/invalidation → in a long-lived worker that's a
  memory leak with a TTL you forgot to set.
- **Business logic in the controller** → thin controller (validate → delegate → serialize);
  logic lives in a stateless service.

## Rules (DO) — with rationale
1. **Services are stateless; per-request data lives in `Context`.** Every service you
   register is a singleton shared by all coroutines on the worker — the only safe
   per-request store is `Hyperf\Context\Context::set/get()`, which is coroutine-local and
   auto-cleared at coroutine end.
2. **All I/O goes through a pool.** DB, Redis, and HTTP use Hyperf's pools
   (`hyperf/db`, `hyperf/redis`, `Hyperf\Guzzle\CoroutineHandler`); a connection is borrowed
   for the coroutine and returned on `defer`. A raw connection per request exhausts fds and
   the DB's `max_connections`.
3. **Never block the worker.** Enable `SWOOLE_HOOK_ALL` and use coroutine clients; replace
   `sleep()` with `Coroutine\System::sleep()`. Swoole schedules coroutines cooperatively,
   not preemptively — one blocking call freezes every coroutine on that process.
4. **Bound every long-lived structure.** Worker processes persist for the server's lifetime;
   any `static` array, in-memory map, or registered event listener that only grows is a
   leak. Cap it, evict it, or push it to Redis.
5. **Offload blocking/CPU work to task workers or a queue.** `#[Task]` / `hyperf/async-queue`
   run in separate (synchronous) processes, so a legacy blocking SDK or an image resize can't
   stall the coroutine scheduler. Don't run it inline in the request coroutine.
6. **Idempotency + typed errors on writes.** Non-GET endpoints tolerate retries (idempotency
   key / unique constraint) and return a typed body via a registered `ExceptionHandler` —
   never leak a trace, and never let an uncaught throwable drop the response silently.
7. **Cache read-heavy paths with a declared key + TTL + invalidation trigger** (`hyperf/cache`
   over Redis). State the eviction rule; an unbounded local cache in a persistent worker is
   the number-one leak in this stack.
8. **Structured JSON logs with a request id carried in `Context`.** Use the Hyperf logger
   (monolog); set a correlation id in middleware and thread it through coroutines. No
   `echo`/`var_dump` — worker stdout is a server stream, not a response.
9. **Containerize the proposal for HA.** Assume a Swoole server in Docker with a fixed
   `worker_num`; pin the `ext-swoole` version, run multiple replicas behind a balancer, and
   health-check the process (`/health` + liveness probe).

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| `$this->user = $u` on a singleton service | Shared across every concurrent coroutine → data leaks between users | `Context::set('user', $u)` (coroutine-local) |
| `$r = new Redis(); $r->connect(…)` in a method | New socket per request, no reuse, connection/fd exhaustion | Inject the pooled `Hyperf\Redis\Redis` |
| `sleep(1)` / `curl_exec()` / `file_get_contents($url)` | Blocks the whole worker process, all coroutines on it | `Coroutine\System::sleep(1)` / coroutine Guzzle with hooks on |
| `static $c = []; $c[$id] = $row;` unbounded | Persistent worker → grows to OOM | `hyperf/cache` with TTL, or a bounded LRU |
| `go(fn () => $repo->save($x))` in a request | No `Context`, response returns first, pooled conn reclaimed mid-write | `#[Task]` / async-queue, or `parallel()` + wait |
| `throw` with no registered `ExceptionHandler` | Leaks trace / 500 with internals; coroutine dies quietly | Register `ExceptionHandler`, return a typed error |
| `env('X')` at runtime in a handler | `.env` is read once at boot; not reloaded in a live process | Read via `config('x')` bound at boot |

## Worked examples ❌ → ✅
**State pollution across concurrent requests**
```php
// ❌ singleton service — $userId is shared by every coroutine on the worker
class OrderService
{
    private int $userId;                                  // worker-wide state!
    public function setUser(int $id): void { $this->userId = $id; }
    public function place(Order $o): void { $o->user_id = $this->userId; /* wrong user under load */ }
}

// ✅ service stays stateless; per-request data in coroutine-local Context
use Hyperf\Context\Context;

class OrderService
{
    public function place(Order $o): void
    {
        $o->user_id = Context::get('user.id');            // isolated per coroutine/request
        $o->save();
    }
}
```

**Raw connection + blocking call → pool + coroutine client**
```php
// ❌ un-pooled PDO + blocking HTTP freezes the entire worker
public function rate(): array
{
    $pdo  = new PDO($dsn, $u, $p);                        // no pool → conn exhaustion
    $body = file_get_contents('https://fx.example/usd');  // blocks every coroutine
    return json_decode($body, true);
}

// ✅ pooled DB + coroutine Guzzle (SWOOLE_HOOK_ALL on) — non-blocking
use Hyperf\DbConnection\Db;
use Hyperf\Guzzle\ClientFactory;

public function __construct(private ClientFactory $clients) {}

public function rate(): array
{
    $client = $this->clients->create();                  // Swoole coroutine handler
    $body   = (string) $client->get('https://fx.example/usd')->getBody(); // yields, no block
    Db::table('fx_log')->insert(['raw' => $body]);        // conn borrowed from pool, freed on defer
    return json_decode($body, true);
}
```

**Detached coroutine → durable async / bounded concurrency**
```php
// ❌ fire-and-forget: no Context, response returns before it runs,
//    its pooled DB connection is reclaimed out from under the write
public function checkout(Cart $cart): array
{
    go(fn () => $this->invoices->generate($cart));        // lost errors, race on connection
    return ['ok' => true];
}

// ✅ push to async-queue (separate process); or parallel() when you must join now
use function Hyperf\Coroutine\parallel;

public function checkout(Cart $cart): array
{
    $this->queue->push(new GenerateInvoice($cart->id));   // survives, retries, isolated
    [$quote, $reserved] = parallel([                      // concurrent, Context copied
        fn () => $this->pricing->quote($cart),
        fn () => $this->stock->reserve($cart),
    ]);
    return ['ok' => true, 'quote' => $quote];
}
```

## Review checklist (PR-ready)
- [ ] No per-request state on any DI singleton; per-request data uses `Context`.
- [ ] Every DB/Redis/HTTP call comes from a Hyperf pool — no `new PDO/Redis/Client` in a handler.
- [ ] No blocking builtin (`sleep`, `curl_exec`, sync `file_get_contents`, native `mysqli`) in coroutine context; hooks enabled.
- [ ] Static/global/listener state is bounded or evicted; nothing grows unboundedly in the worker.
- [ ] Detached coroutines (`go()`/`Coroutine::create`) don't outlive the request or hold a pooled connection; use tasks/queue/`parallel()`.
- [ ] Writes are idempotent and errors go through an `ExceptionHandler` with a typed body.
- [ ] Cached paths declare key + TTL + invalidation trigger.
- [ ] Structured JSON logs carry a request id from `Context`; no `echo`/`var_dump`.
- [ ] Config read via `config()`, not `env()` at runtime.

## Definition of Done
Change is coroutine-safe (no shared mutable state, no blocking call), all I/O is pooled, and
it has a test for the happy path **and** one concurrency/failure path (e.g. two simultaneous
requests don't cross state, a returned connection isn't reused mid-write). Long-lived memory
is bounded, writes are idempotent with typed errors, logs are structured with a request id,
and it runs green as a Swoole server in the Docker image behind a health check with N replicas.

## Stack-specific gotchas
- **Swoole ≠ FPM lifecycle.** The worker persists across requests — module/`static` state,
  singletons, and container bindings survive; nothing is torn down between requests, so a
  leak here is permanent until restart.
- **`Context` is per-coroutine and auto-cleared** at coroutine end — but a child spawned with
  raw `Swoole\Coroutine::create` does **not** inherit it; Hyperf's `co()`/`parallel()` copy
  it. Know which one you're calling.
- **`defer()` runs at coroutine exit** — it's how pooled connections are returned; a long or
  detached coroutine holds its connection until then and starves the pool.
- **`Coroutine\Channel`** is the safe primitive for cross-coroutine data and for capping
  concurrency (use it as a semaphore). Never share a plain array between coroutines.
- **Some extensions aren't coroutine-safe** (blocking C SDKs, `curl` without
  `SWOOLE_HOOK_CURL`, drivers not covered by the runtime hook). Verify before a request path;
  route the uncooperative ones to a task worker.
- **`.env` is read once at boot.** Changing env after start does nothing until a restart;
  read `config()` values, and reloading code needs `SIGTERM`/reload, not FPM-style per-request pickup.
- **An uncaught exception kills the coroutine, not the worker**, and can silently drop the
  response — always register an `ExceptionHandler` and guard every detached coroutine.

## Evidence tags
- `[STATE_POLLUTION]` — per-request state on a shared singleton / container binding.
- `[COROUTINE_LEAK]` — unbounded static/global/listener state, or a detached coroutine outliving its request.
- `[POOL_EXHAUSTION]` — raw connection per request, or a connection held past the response (defer/pool starvation).
- `[BLOCKING_CALL]` — a synchronous builtin/extension blocking the worker's event loop.
