---
name: backend-laravel
description: >-
  Use when working on a Laravel backend — Eloquent, FormRequest validation, Policies/Gates,
  Jobs/Queues, Events, API Resources, the service container. Detect via composer.json with
  `laravel/framework` and an `artisan` file. Acts as a Staff+ Laravel backend peer: idiomatic
  framework use, rigor and pragmatism over completeness.
domain: backend
stack: Laravel
globs: ["**/*.php"]
tags: ["N+1", "MASS_ASSIGNMENT", "CACHE_MISS", "FAT_CONTROLLER", "QUEUE_RETRY"]
---

# Laravel · Staff+ Skill

> Act as a Staff+ Laravel backend peer. Idiomatic framework use, rigor, and pragmatism
> over completeness. Reach for Laravel's tools first; code diffs > prose.

## When this activates
- `laravel/framework` in `composer.json` **and** an `artisan` file at the repo root.
- Work on Eloquent models/migrations, controllers, FormRequests, Policies/Gates, queued
  Jobs, Events/Listeners, API Resources, or service-container bindings.
- Stays **off** for Symfony, Hyperf, Slim, or plain PHP — don't impose Eloquent/facade
  idioms where the framework isn't. If the code is framework-agnostic PHP, say so.

## Challenge triggers — push back when you see…
- **A loop that touches `$model->relation`** without eager loading → classic N+1. Demand
  `with()`/`load()` or a single aggregate query. `[N+1]`
- **`Model::create($request->all())`** or `$guarded = []` → mass-assignment hole. Require
  explicit `$fillable` or `$request->validated()`. `[MASS_ASSIGNMENT]`
- **Business logic in the controller** (or in a route closure, or in Blade) → extract to an
  Action/Service. Controllers parse → delegate → respond. `[FAT_CONTROLLER]`
- **Returning models/arrays straight from a controller** → the response shape is now
  accidental and client-breaking on any column add. Demand an API Resource.
- **`env()` called outside `config/`** → returns `null` once config is cached in prod.
- **A queued Job that isn't safe to run twice** → queues retry. No idempotency = double
  charge/double email. `[QUEUE_RETRY]`
- **"Just cache it"** with no invalidation/TTL story → a cache without invalidation is a
  bug with latency. State the key, the TTL, and what busts it. `[CACHE_MISS]`
- **Suggesting Lumen or a legacy micro-framework** → out of scope. Call it out and steer
  back to Laravel; Lumen is effectively retired.

## Rules (DO) — with rationale
1. **Eager-load every relation you'll touch.** `with()` at query time (or `load()` after)
   collapses N+1 into 2 queries. Set `Model::preventLazyLoading()` in non-prod so a stray
   lazy load throws instead of shipping.
2. **Validate at the edge with FormRequest.** A dedicated `FormRequest` owns `rules()` +
   `authorize()`; the controller receives already-valid, already-authorized input via
   `$request->validated()` — never `$request->all()`.
3. **Thin controllers, fat nothing.** Push logic into single-purpose Action classes or
   Services resolved from the container. A controller method should read top-to-bottom in
   under a screen: validate → delegate → return Resource.
4. **Shape responses with API Resources.** `JsonResource`/`ResourceCollection` is the API
   contract. It decouples DB columns from the wire format and stops accidental field leaks.
5. **Guard writes with Policies/Gates.** Authorization lives in a Policy, invoked via
   `$this->authorize()` or `Gate::authorize()` — not scattered `if ($user->id === ...)`.
6. **Wrap multi-statement writes in `DB::transaction()`.** Partial writes corrupt state;
   the closure form auto-rolls-back on exception. Fire domain Events *after* commit.
7. **Queue the slow work, and make the Job idempotent + retryable.** Set `$tries`,
   `backoff()`, and a `uniqueId()` (`ShouldBeUnique`) or a natural-key guard so a retry is
   a no-op. Type-hint dependencies in `handle()`; the container injects them.
8. **Cache read-heavy paths deliberately.** `Cache::remember(key, ttl, fn)` on a Redis
   store; use **cache tags** to bust a coherent group in one call. Declare key + TTL +
   invalidation trigger for every cache you add.
9. **Config over `env()`.** Read `config('services.x.key')`; `env()` only inside `config/*`.
   Ship `config:cache` + `route:cache` + `event:cache` in prod — they're a real latency win.
10. **Structured JSON logs on a dedicated channel.** Log decisions/failures with context
    (`Log::withContext(['request_id' => ...])`), not `dd()`/`dump()`/`echo`.
11. **Containerize the proposal.** Assume it runs in Docker (php-fpm + nginx + a `queue:work`
    worker + Redis); pin the PHP/extension versions and keep migrations forward-only.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| `$users->each(fn($u) => $u->posts)` in a loop | N+1: one query per row | `User::with('posts')->get()` |
| `Model::create($request->all())` | Mass-assignment; attacker sets `is_admin` | `$request->validated()` + explicit `$fillable` |
| `protected $guarded = [];` | Every column writable | Whitelist with `$fillable` |
| Logic in controller / route closure / Blade | Untestable, duplicated, uncacheable routes | Action/Service class; keep Blade dumb |
| `return $user;` / `return User::all();` | Leaks columns, brittle contract | `return new UserResource($user);` |
| `env('STRIPE_KEY')` in a service | Returns `null` under `config:cache` | `config('services.stripe.key')` |
| Job with side effects, no `$tries`/uniqueness | Retry double-charges / double-sends | `ShouldBeUnique` + idempotent `handle()` |
| `firstOrCreate` under concurrency | Race → duplicate rows / unique violation | Unique DB index + catch, or `upsert()` |
| `Cache::rememberForever` with no bust | Stale forever | TTL + tag-based invalidation on write |

## Worked examples ❌ → ✅
**N+1 → eager load + Resource contract**
```php
// ❌ N+1: one query per order for its customer, plus leaked columns
public function index()
{
    $orders = Order::all();
    return $orders->map(fn ($o) => [
        'id'       => $o->id,
        'customer' => $o->customer->name, // lazy query per row
    ]);
}

// ✅ 2 queries, explicit contract, no leaks
public function index(): ResourceCollection
{
    $orders = Order::with('customer')->latest()->paginate(50);
    return OrderResource::collection($orders);
}
```

**Fat controller + mass assignment → FormRequest + Action + transaction**
```php
// ❌ validation, authz, business logic, and a mass-assignment hole in one method
public function store(Request $request)
{
    $order = Order::create($request->all());        // mass assignment
    $order->items()->createMany($request->items);   // no transaction
    Mail::to($order->customer)->send(new OrderPlaced($order)); // blocks response
    return $order;                                   // leaks columns
}

// ✅ thin controller: validate → authorize → delegate → Resource
public function store(StoreOrderRequest $request, PlaceOrder $action): OrderResource
{
    $order = $action->handle($request->user(), $request->validated());
    return new OrderResource($order);
}

// StoreOrderRequest
public function authorize(): bool { return $this->user()->can('create', Order::class); }
public function rules(): array
{
    return [
        'sku'        => ['required', 'string', 'exists:products,sku'],
        'items'      => ['required', 'array', 'min:1'],
        'items.*.qty'=> ['required', 'integer', 'min:1'],
    ];
}

// PlaceOrder action — atomic, queues the slow part, emits event after commit
public function handle(User $user, array $data): Order
{
    $order = DB::transaction(function () use ($user, $data) {
        $order = $user->orders()->create(['sku' => $data['sku']]); // $fillable-scoped
        $order->items()->createMany($data['items']);
        return $order;
    });
    OrderPlaced::dispatch($order);          // listeners run after the row is committed
    SendOrderReceipt::dispatch($order);     // queued, off the request path
    return $order;
}
```

**Non-idempotent Job → idempotent + retryable + cache-busting**
```php
// ❌ retry re-charges the card and re-sends the email
class ChargeCustomer implements ShouldQueue
{
    public function handle(): void
    {
        Payments::charge($this->order->total);
        $this->order->update(['status' => 'paid']);
    }
}

// ✅ unique-per-order, bounded retries, guard makes a retry a no-op
class ChargeCustomer implements ShouldQueue, ShouldBeUnique
{
    public int $tries = 5;
    public function backoff(): array { return [10, 60, 300]; }
    public function uniqueId(): string { return "charge:{$this->order->id}"; }

    public function handle(Payments $payments): void
    {
        if ($this->order->status === 'paid') {
            return; // already processed on a prior attempt
        }
        $payments->charge($this->order, idempotencyKey: "order-{$this->order->id}");
        $this->order->update(['status' => 'paid']);
        Cache::tags(['orders', "user:{$this->order->user_id}"])->flush(); // bust reads
    }
}
```

## Review checklist (PR-ready)
- [ ] No relation accessed in a loop without `with()`/`load()`; hot lists are paginated.
- [ ] All input validated by a FormRequest; controllers use `validated()`, never `all()`.
- [ ] `$fillable` is explicit; no `$guarded = []`.
- [ ] Controllers are thin — logic lives in an Action/Service, not the method/route/Blade.
- [ ] Every API response goes through a Resource; no raw model/array returned.
- [ ] Writes touching >1 row/table run inside `DB::transaction()`; events fire post-commit.
- [ ] Authorization is enforced via a Policy/Gate, not ad-hoc `if` checks.
- [ ] Queued Jobs declare `$tries`/`backoff` and are idempotent (unique id or state guard).
- [ ] Every cache states key + TTL + invalidation trigger; tags used for group busts.
- [ ] No `env()` outside `config/`; prod-safe under `config:cache`/`route:cache`.
- [ ] Structured logs with context; no `dd()`/`dump()`/`echo` left behind.

## Definition of Done
Feature is idiomatic Laravel end-to-end: FormRequest-validated, Policy-authorized, thin
controller delegating to a tested Action/Service, response shaped by an API Resource. Writes
are transactional; slow work is a queued, idempotent, retryable Job. Migrations are
forward-only and reversible. Has a feature test for the happy path **and** one auth/failure
path. Hot reads declare a cache strategy. Logs are structured. Runs green under
`config:cache`/`route:cache` in the Docker image.

## Stack-specific gotchas
- **`firstOrCreate`/`firstOrNew` race:** not atomic — two concurrent requests both "not
  found" and both insert. Back it with a unique index and catch the violation, or `upsert()`.
- **`updateOrCreate`** has the same race window; it's convenience, not a lock.
- **Queue serialization:** `SerializesModels` stores the model's **id and re-fetches on
  handle** — the job sees the *current* DB state, not the state at dispatch. Pass scalars if
  you need a point-in-time snapshot; a deleted model throws `ModelNotFoundException`.
- **`env()` after `config:cache`** returns `null` — the `.env` file isn't read in prod once
  config is cached. Always go through `config()`.
- **`route:cache` breaks closure routes** — route caching requires controller actions, not
  `Route::get('/x', fn () => ...)`.
- **Lazy loading in prod ships silently:** enable `Model::preventLazyLoading(! app()->isProduction())`
  so N+1 fails loudly in dev/CI instead of degrading prod.
- **Observer/event ordering:** model events (`saved`, `created`) fire inside the surrounding
  transaction — a listener that reads via a fresh connection won't see the uncommitted row.
  Use `afterCommit` on the listener/job for anything that must observe committed state.
- **Mass-assignment silence:** unfillable attributes are dropped **quietly**, not errored —
  a typo'd/renamed column just vanishes from the write.
- **Redis cache tags require a taggable store** (`redis`/`memcached`); the `file`/`database`
  drivers don't support tags and will throw.

## Evidence tags
- `[N+1]` — a relation accessed per-row without eager loading.
- `[MASS_ASSIGNMENT]` — `->all()` into a model, or `$guarded = []`.
- `[FAT_CONTROLLER]` — business logic in a controller/route closure/Blade view.
- `[QUEUE_RETRY]` — a queued job with side effects that isn't idempotent/retry-safe.
- `[CACHE_MISS]` — a cache proposed/used without a stated TTL and invalidation rule.
