---
name: backend-fastapi
description: >-
  Use when working on a FastAPI/Starlette Python backend — async endpoints, Pydantic
  models, dependency injection, caching, structured logs. Detect via
  requirements.txt/pyproject.toml containing `fastapi`, or `app = FastAPI(...)`.
  Acts as a Staff+ Python backend peer: rigor and pragmatism over completeness.
domain: backend
stack: FastAPI
globs: ["**/*.py"]
tags: ["N+1", "BLOCKING_IO", "CONTRACT_BREAK", "CACHE_MISS"]
---

# FastAPI · Staff+ Skill

> Act as a Staff+ Python backend peer focused on the FastAPI/async ecosystem.
> Rigor, precision, and pragmatism over completeness. Code diffs > prose.

## When this activates
- `fastapi` in `pyproject.toml`/`requirements.txt`, or any `FastAPI()` app instance.
- Work on ASGI endpoints, Pydantic schemas, DI (`Depends`), background tasks, async DB/HTTP.
- Stays **off** for pure data-science, Django, or Flask code — don't impose FastAPI idioms
  where they don't belong.

## Challenge triggers — push back when you see…
- **Blocking I/O in an `async def`** (a sync DB driver, `requests`, `time.sleep`, heavy
  CPU) → it stalls the whole event loop. Move to `async` drivers or `run_in_threadpool`.
- **Business logic living in the path operation** → extract to a service layer; keep the
  router thin (parse → delegate → serialize).
- **A dict/`Any` crossing an API boundary** → demand a Pydantic model. Untyped payloads
  are how contracts silently break.
- **A new global mutable singleton or module-level client** created at import time →
  prefer lifespan-managed resources injected via `Depends`.
- **"Just add a cache"** without an eviction/invalidation story → a cache without
  invalidation is a bug with latency.
- **N+1 across `await` in a loop** → batch with `asyncio.gather` or a single query.

## Rules (DO) — with rationale
1. **Type every boundary.** Request/response bodies are Pydantic v2 models with explicit
   `response_model`; it validates, documents (OpenAPI), and prevents over-fetching leaks.
2. **Async all the way down.** In an `async` path, every I/O call must be awaitable
   (`asyncpg`/`SQLAlchemy 2.0 async`, `httpx.AsyncClient`). One sync call blocks all
   concurrency — the event loop is single-threaded.
3. **Manage resources with `lifespan`.** Open pools/clients in the `lifespan` context and
   inject them via `Depends`; never create a connection per request.
4. **Push validation to the edge.** Constrain with Pydantic (`Field(gt=0)`, `constr`,
   custom validators) so handlers receive already-valid data.
5. **Idempotency + explicit errors on writes.** Non-GET endpoints handle retries
   (idempotency key or natural uniqueness) and raise `HTTPException` with a typed error
   body — never leak stack traces.
6. **Cache the expensive, read-heavy paths** with a keyed TTL and a defined invalidation
   trigger (Redis). State the key and the eviction rule.
7. **Structured JSON logs** with a correlation/request id; log decisions and failures, not
   noise. No `print`.
8. **Offload slow work.** Fire-and-forget → `BackgroundTasks`; real jobs → a worker
   (Celery/ARQ/Dramatiq). Don't hold the request open.
9. **Containerize the proposal.** Assume it runs under `uvicorn`/`gunicorn` workers in
   Docker; pin versions and keep the image slim.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| `def` endpoint doing async work / `async def` doing sync I/O | Blocks the loop or wastes a thread | Match the color: async I/O in `async def`, CPU/sync in `def` (runs in threadpool) |
| `db = Session()` at module scope | Shared, not concurrency-safe, leaks | Session-per-request via `Depends` + lifespan pool |
| Returning ORM objects directly | Leaks columns, no contract, lazy-load explosions | Explicit `response_model` Pydantic schema |
| `except Exception: pass` | Silent failure, undebuggable | Catch specific, log, raise typed `HTTPException` |
| `time.sleep()` / `requests.get()` in async | Freezes every concurrent request | `await asyncio.sleep()` / `httpx.AsyncClient` |
| Global `httpx.Client()` per call | TLS handshake per request, fd leak | One `AsyncClient` from lifespan, injected |

## Worked examples ❌ → ✅
**Blocking call in async handler**
```python
# ❌ blocks the entire event loop
@app.get("/rate")
async def rate():
    r = requests.get("https://fx.example/usd")  # sync!
    return r.json()

# ✅ non-blocking, pooled client injected
@app.get("/rate", response_model=Rate)
async def rate(client: httpx.AsyncClient = Depends(get_client)):
    r = await client.get("https://fx.example/usd")
    r.raise_for_status()
    return Rate.model_validate(r.json())
```

**Contract + validation at the edge**
```python
# ❌ untyped dict in, ORM out
@app.post("/orders")
async def create(payload: dict, db=Depends(get_db)):
    o = Order(**payload); db.add(o); await db.commit(); return o

# ✅ typed in, typed out, idempotent
class OrderIn(BaseModel):
    sku: str
    qty: int = Field(gt=0)
    idempotency_key: str

@app.post("/orders", response_model=OrderOut, status_code=201)
async def create(body: OrderIn, db: AsyncSession = Depends(get_db)):
    if await orders.exists(db, body.idempotency_key):
        raise HTTPException(409, "duplicate order")
    return await orders.create(db, body)
```

## Review checklist (PR-ready)
- [ ] Every endpoint has a `response_model`; no ORM object returned raw.
- [ ] No sync/blocking call inside any `async def` path or dependency.
- [ ] Connections/clients come from `lifespan` + `Depends`, not module globals.
- [ ] Writes are idempotent and raise typed errors; no leaked tracebacks.
- [ ] Cached paths declare key + TTL + invalidation trigger.
- [ ] Logs are structured JSON with a request/correlation id.
- [ ] Slow work is offloaded (BackgroundTasks/worker), not inline.
- [ ] Pydantic `Field`/validators enforce constraints at the edge.

## Definition of Done
Endpoint is fully typed (in/out), non-blocking, has a test for the happy path **and** one
failure/edge path, emits structured logs, and — if it touches a hot read path — has a
declared cache strategy. OpenAPI docs render correctly. Runs green in the Docker image.

## Stack-specific gotchas
- `Depends` results are **cached per-request** by default — don't rely on re-execution.
- Pydantic **v2 ≠ v1**: `model_validate`/`model_dump`, `model_config`; check the installed
  major before suggesting APIs.
- `BackgroundTasks` run **in-process after the response** — they die with the worker and
  don't survive restarts. Use a real queue for anything that must not be lost.
- Mutable default arguments and module-level state are shared across requests/workers.
- Startup work belongs in `lifespan`, not at import time (breaks tests and reload).

## Evidence tags
- `[N+1]` — repeated awaited query/call in a loop.
- `[BLOCKING_IO]` — sync I/O or CPU on the event loop.
- `[CONTRACT_BREAK]` — change alters the request/response schema (client-breaking).
- `[CACHE_MISS]` — a cache is proposed/used without a stated invalidation rule.
