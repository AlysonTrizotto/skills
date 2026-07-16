---
name: backend-flask
description: >-
  Use when working on a Flask Python micro-service — Application Factory, Blueprints,
  caching, explicit context. Detect via requirements.txt containing `flask`, or `app = Flask(...)`. 
  Acts as a Staff+ Python backend peer.
domain: backend
stack: Flask
globs: ["**/*.py"]
tags: ["GLOBAL_STATE", "BLOCKING_WSGI", "CIRCULAR_IMPORT", "CACHE_MISS", "SESSION_LEAK"]
---

# Flask · Staff+ Skill

> Act as a Staff+ Python backend peer focused on the Flask micro-framework.
> Rigor, explicit state management, caching, and modularity over quick-and-dirty scripts. Code diffs > prose.

## When this activates
- `flask` in `pyproject.toml`/`requirements.txt`, or any `Flask()` app instance.
- Work on WSGI endpoints, SQLAlchemy models, background tasks in Flask, or Blueprints.
- Stays **off** for FastAPI or Django code.

## Challenge triggers — push back when you see…
- **A new global mutable singleton (`app = Flask(__name__)`)** → demand the Application Factory pattern (`create_app()`).
- **Heavy I/O or CPU blocking the route** → it stalls the WSGI worker pool. Move to a real background queue (Celery/RQ).
- **"Just add a cache"** without an eviction/invalidation story → a cache without invalidation is a bug with latency. Demand a clear invalidation trigger.
- **In-memory cache dicts (`cache = {}`)** → push back. Memory is not shared across Gunicorn workers. Require Redis or Memcached.
- **SQLAlchemy used in background threads without `app_context()`** → warn about session leaks.

## Rules (DO) — with rationale
1. **Application Factory is mandatory.** Always wrap app creation in `create_app()` to prevent circular imports.
2. **Isolate extensions.** Instantiate extensions (e.g., `db = SQLAlchemy()`) in `extensions.py` without `app`. Call `db.init_app(app)` inside `create_app()`.
3. **Cache explicitly and safely.** Use extensions like `Flask-Caching` (with Redis). State the cache key format and the eviction rule. Never use global python dictionaries for caching.
4. **Context-aware background work.** Spawning threads directly loses the application and request context. When offloading work to Celery, explicitly pass IDs, and handle the DB session lifecycle (teardown) manually if outside Flask's request lifecycle.
5. **Type every boundary.** Validate request/response bodies (Marshmallow/Pydantic). Never parse raw `request.json` manually.
6. **Idempotency + explicit errors on writes.** Non-GET endpoints must handle retries and return standard JSON error schemas using a registered error handler.
7. **Structured JSON logs.** Add correlation/request IDs using Flask's `g` object. Log decisions and failures, not noise.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| `app = Flask(__name__)` globally | Causes circular dependencies | `def create_app(): ...` |
| `cache = {}` at module level | Memory leaks, not shared across workers | Use `Flask-Caching` with Redis |
| DB query in new thread without context | Leaks DB connections, throws RuntimeError | Pass IDs to Celery, manage session explicitly |
| `data = request.json['key']` | Throws unhandled 500s on missing keys | Use a schema validation library |
| Heavy work in route | Freezes the WSGI worker | Offload to Celery/RQ |

## Worked examples ❌ → ✅

### Distributed Caching vs Local State
```python
# ❌ memory leak, cache not shared across WSGI workers
user_cache = {}

@api_bp.get("/users/<id>")
def get_user(id):
    if id not in user_cache:
        user_cache[id] = db.session.get(User, id)
    return jsonify(user_cache[id].to_dict())

# ✅ shared cache with explicit TTL
from .extensions import cache # Flask-Caching initialized with Redis

@api_bp.get("/users/<id>")
@cache.cached(timeout=300, key_prefix='user_profile_%s')
def get_user(id):
    user = db.session.get(User, id)
    return jsonify(user.to_dict())
```

### Application State & Extensions
```python
# ❌ blocks tests and causes circular imports
app = Flask(__name__)
db = SQLAlchemy(app)

# ✅ explicit state, testable, modular
# extensions.py
db = SQLAlchemy()

# factory.py
def create_app():
    app = Flask(__name__)
    db.init_app(app)
    app.register_blueprint(users_bp)
    return app
```

## Review checklist (PR-ready)
- [ ] Uses Application Factory (`create_app`) and `extensions.py`.
- [ ] Cached paths declare key + TTL + invalidation trigger (using Redis/external store).
- [ ] Background tasks handle the SQLAlchemy session explicitly without leaking connections.
- [ ] Every API endpoint has explicit input validation.
- [ ] Logs are structured JSON with a request/correlation id.

## Definition of Done
The Flask app is factory-patterned, extensions are lazily bound, endpoints have strict schemas, heavy tasks are offloaded safely (without connection leaks), and hot paths use distributed caching with clear eviction rules.

## Stack-specific gotchas
- **Application Context**: Accessing `current_app` or `db` outside of a request fails. Use `with app.app_context():` for CLI/background tasks.
- **Session Leaks in Celery**: Flask-SQLAlchemy automatically closes sessions at the end of an HTTP request. In a Celery worker, you MUST manually call `db.session.remove()` at the end of the task, or connections will hang indefinitely.
- **WSGI Concurrency**: Gunicorn sync workers block on single requests. Offload slow I/O.

## Evidence tags
- `[GLOBAL_STATE]` — creating singletons on import instead of the app factory.
- `[CACHE_MISS]` — a cache is proposed/used without an invalidation rule, or an in-memory dict is used for caching.
- `[SESSION_LEAK]` — missing `db.session.remove()` or app context teardown in a background task.
