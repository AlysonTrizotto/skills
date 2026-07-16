---
name: backend-rails
description: >-
  Use when working on a Ruby on Rails backend — ActiveRecord models, controllers,
  service objects, Sidekiq jobs, fragment caching, structured logs. Detect via
  Gemfile containing `rails`, `config/application.rb`, or `bin/rails`. Acts as a
  Staff+ Rails peer: the Rails Way and convention-over-configuration over cleverness.
domain: backend
stack: Ruby on Rails
globs: ["**/*.rb"]
tags: ["N+1", "FAT_MODEL", "CACHE_MISS", "JOB_IDEMPOTENCY", "CALLBACK_HELL"]
---

# Ruby on Rails · Staff+ Skill

> Act as a Staff+ Rails peer. Convention-over-configuration, boring proven tech, and
> readability over cleverness. The Rails Way is the default; deviations must earn it.

## When this activates
- `rails` in the `Gemfile`, a `config/application.rb`, or a `bin/rails` binstub present.
- Work on ActiveRecord models, controllers, views, service objects, Sidekiq/ActiveJob
  workers, migrations, or `Rails.cache` paths.
- Stays **off** for Sinatra, Hanami, Roda, or plain Ruby scripts/gems — don't impose
  Rails idioms (generators, ActiveRecord, autoloading) where there is no Rails runtime.

## Challenge triggers — push back when you see…
- **A query inside a view or a `.each` loop** → that's an N+1 waiting to fire on every
  row. Demand `includes`/`preload`/`eager_load` and prove it with the `bullet` gem.
- **A controller action longer than ~10 lines with business logic** → the router is not
  the place for it. Extract to a model method, a scope, or a service object.
- **A model past ~300 lines drowning in callbacks and private helpers** → fat model. Pull
  cohesive behavior into a concern or a plain-Ruby service; models persist, they don't
  orchestrate.
- **An `after_save`/`after_create` callback that calls an external API, enqueues a job, or
  sends mail** → it runs inside the transaction and fires even on rollback. Move it to
  `after_commit`.
- **`Model.all.each` / `Model.where(...).each` over a large table** → loads every row into
  memory. Use `find_each`/`in_batches`.
- **A Sidekiq job that takes an ActiveRecord object as an argument** → args must serialize
  to JSON; pass the **id**, reload inside `perform`. And ask: is this job idempotent?
- **"Just add caching"** with no expiration/invalidation story → a cache without a key
  strategy is a stale-data bug with good latency.
- **`params[:whatever]` passed straight into `.new`/`.update`** → mass-assignment hole.
  Route it through strong params.
- **A raw `save` where a failure must not pass silently** → prefer `save!`/`update!` so a
  validation failure raises instead of returning `false` into the void.

## Rules (DO) — with rationale
1. **Skinny controllers, POROs for logic.** Actions parse → delegate → render. Non-trivial
   flows go to a service object (`app/services`, one public `#call`); shared query/behavior
   goes to a scope or a concern. Keep the MVC seams clean.
2. **Kill N+1 at the source.** Eager-load associations you will touch: `includes` (lets
   Rails pick), `preload` (separate queries), `eager_load` (single LEFT JOIN, needed when
   you filter on the association). Run `bullet` in dev/test to catch regressions.
3. **Batch every large iteration.** `find_each`/`in_batches` for row-by-row work;
   `update_all`/`delete_all` for set operations that skip callbacks intentionally.
4. **Select only what you use.** `pluck(:id)` when you need scalars, `select(:a, :b)` for
   partial rows — don't hydrate full objects to read one column.
5. **Index every foreign key and every column you filter/sort/join on.** An unindexed
   `where`/`order` on a growing table is a latency time bomb; verify with `EXPLAIN`.
6. **Wrap multi-write invariants in a transaction.** Use `ActiveRecord::Base.transaction`
   with bang methods so any failure rolls the whole unit back.
7. **External side effects belong in `after_commit`, not `after_save`.** Only fire mail,
   jobs, webhooks, and cache busting once the data is durably committed.
8. **Sidekiq jobs: small, idempotent, retry-safe.** Pass IDs (JSON-serializable) not
   objects, reload inside `perform`, guard against double-processing (Sidekiq is
   **at-least-once**), keep the unit of work tiny, and route by queue with a latency SLO.
9. **Cache the hot read paths deliberately.** Fragment + russian-doll caching in views keyed
   on `[record, updated_at]` (touch parents), `Rails.cache.fetch(key, expires_in:)` for
   computed data, and `counter_cache` for association counts. State the key and what busts it.
10. **Structured logs.** Use `lograge` (or a JSON formatter) with a request id and tagged
    context; one line per request, no `puts`/`p` in production paths.
11. **Contracts + error handling for APIs.** Explicit serializer (`ActiveModel::Serializer`,
    `jbuilder`, or a plain presenter), typed error responses via `rescue_from`, and
    idempotency on non-GET writes (idempotency key or natural uniqueness).
12. **Boring, proven, containerized.** Prefer the stdlib/Rails-native path over a clever gem.
    Assume it ships in Docker under Puma with multiple workers; design for horizontal scale
    (stateless requests, shared cache/DB, HA-friendly).

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| `@posts.each { \|p\| p.author.name }` in a view | N+1: one query per row | `Post.includes(:author)` in the controller |
| Business logic in the controller action | Untestable, fat controller, no reuse | Service object / model method; keep the action thin |
| 500-line model with 12 callbacks | Fat model, callback hell, hidden side effects | Concern for shared behavior + service for orchestration |
| `after_save { PaymentApi.charge! }` | Runs in-txn, fires on rollback, retries wrong | `after_commit on: :create` |
| `User.all.each { … }` on a big table | Loads whole table into memory | `User.find_each { … }` |
| `MyJob.perform_async(user)` | Object won't serialize / goes stale | `MyJob.perform_async(user.id)`, reload in `perform` |
| `params.to_h` into `Model.new` | Mass-assignment vulnerability | `params.require(:user).permit(:a, :b)` |
| `record.save` when failure matters | Silent `false`, no rollback signal | `record.save!` / handle the boolean explicitly |
| `Rails.cache.fetch(key) { … }` with no `expires_in`/bust | Stale forever, unbounded keys | Key on `updated_at` or set TTL + touch |

## Worked examples ❌ → ✅
**N+1 hidden in a view + fat controller**
```ruby
# ❌ controller loads bare records; the view fans out queries
def index
  @orders = Order.where(status: :open).order(created_at: :desc)
end
# app/views/orders/index — one query PER order, twice over
# <%= order.customer.name %> <%= order.line_items.sum(&:total) %>

# ✅ eager-load what the view touches; push the sum to the DB via counter/select
def index
  @orders = Order.open
                 .includes(:customer)
                 .select('orders.*, SUM(line_items.total) AS total_cents')
                 .left_joins(:line_items)
                 .group('orders.id')
                 .recent
end
# Order model
scope :open,   -> { where(status: :open) }
scope :recent, -> { order(created_at: :desc) }
```

**Fat model callback → service object + after_commit**
```ruby
# ❌ side effect inside the transaction, fires on rollback, untestable
class Order < ApplicationRecord
  after_save :charge_and_notify   # runs mid-transaction!
  def charge_and_notify
    PaymentGateway.charge!(total_cents)   # external call, not rollback-safe
    OrderMailer.confirmation(self).deliver_now
  end
end

# ✅ persistence stays in the model; orchestration in a service; effects post-commit
class Order < ApplicationRecord
  after_commit :enqueue_fulfillment, on: :create
  private def enqueue_fulfillment = FulfillOrderJob.perform_async(id)
end

class PlaceOrder
  def initialize(cart:) = @cart = cart
  def call
    ApplicationRecord.transaction do
      order = Order.create!(@cart.attributes)   # bang: rolls back on failure
      @cart.line_items.each { |li| order.line_items.create!(li.attributes) }
      order
    end
  end
end
```

**Idempotent, ID-only Sidekiq job**
```ruby
# ❌ passes an object, no idempotency — Sidekiq is at-least-once, so this can double-charge
class FulfillOrderJob
  include Sidekiq::Job
  def perform(order)                 # object won't round-trip through Redis/JSON
    PaymentGateway.charge!(order.total_cents)
  end
end

# ✅ ID arg, reload, guard, small unit of work, dedicated queue
class FulfillOrderJob
  include Sidekiq::Job
  sidekiq_options queue: :payments, retry: 5

  def perform(order_id)
    order = Order.find(order_id)
    return if order.fulfilled?       # idempotency guard — safe to re-run
    order.with_lock do
      return if order.fulfilled?
      PaymentGateway.charge!(order.total_cents, idempotency_key: "order-#{order.id}")
      order.update!(status: :fulfilled)
    end
  end
end
```

## Review checklist (PR-ready)
- [ ] No query inside a view or a `.each`; associations eager-loaded, `bullet` clean.
- [ ] Controller actions are thin; non-trivial logic lives in a model/scope/service.
- [ ] No fat model — cohesive behavior extracted to a concern or PORO, not piled on.
- [ ] External side effects run in `after_commit`, never `after_save`/`after_create`.
- [ ] Large iterations use `find_each`/`in_batches`; scalar reads use `pluck`/`select`.
- [ ] Foreign keys and filtered/sorted columns are indexed (migration included).
- [ ] Multi-write invariants wrapped in a transaction with bang methods.
- [ ] Sidekiq jobs take IDs, are idempotent + retry-safe, and declare a queue.
- [ ] Cached paths state their key and invalidation/TTL (russian-doll keys on `updated_at`).
- [ ] Writes are guarded (`save!`/`update!` or explicit boolean handling); strong params used.
- [ ] Logs are structured (lograge/JSON) with a request id.

## Definition of Done
Change follows MVC seams (thin controller, logic in model/service), fires zero N+1
(verified with `bullet`), has model/request tests for the happy path **and** a
failure/edge path, and — if it touches a hot read path — declares a cache key + bust
rule. Migrations add the needed indexes and run reversibly. Any background work is an
idempotent, ID-argument Sidekiq job. Emits structured logs. Runs green in the Docker image
under Puma.

## Stack-specific gotchas
- **Callback ordering & side effects:** callbacks fire in declaration order and `after_save`
  runs **inside** the transaction — a raise (or a parallel rollback) undoes committed-looking
  work. Reserve external effects for `after_commit`.
- **`save` vs `save!`:** `save`/`update` return `false` on validation failure and swallow it;
  `save!`/`update!` raise `RecordInvalid`. In transactions and services, use the bang forms so
  failures actually roll back.
- **N+1 hidden in views/serializers:** a `<%= x.assoc.attr %>` deep in a partial or a jbuilder
  template is invisible in the controller. Eager-load at the query, keep `bullet` on in test.
- **Zeitwerk autoloading:** file paths must match constant names (`app/services/place_order.rb`
  → `PlaceOrder`). Don't `require` app code manually, and don't reopen classes across mismatched
  paths — you'll get `NameError`/`LoadError` at boot.
- **Mass assignment:** ActiveRecord has no built-in whitelist — strong params
  (`require`/`permit`) are the only guard. Never feed raw `params` to `new`/`update`.
- **Sidekiq at-least-once delivery:** jobs can and will run more than once (retries, crashes,
  duplicate enqueues). Idempotency is mandatory, not optional — guard on state or a dedup key.
- **`counter_cache` drift:** it speeds up counts but can desync if rows are changed via
  `update_all`/raw SQL that skips callbacks; use `reset_counters` to repair.
- **Queue latency:** Sidekiq concurrency is finite; one slow queue starves the rest. Split by
  SLO (`critical`/`default`/`low`) and watch per-queue latency, not just throughput.

## Evidence tags
- `[N+1]` — a query executed per-row in a loop, view, or serializer.
- `[FAT_MODEL]` — business/orchestration logic accreting on a model or in a controller action.
- `[CACHE_MISS]` — a cache proposed/used without a stated key or invalidation rule.
- `[JOB_IDEMPOTENCY]` — a background job that isn't safe under at-least-once re-execution
  (object args, no guard, non-retry-safe side effects).
- `[CALLBACK_HELL]` — external side effects or ordering-dependent logic buried in AR callbacks.
