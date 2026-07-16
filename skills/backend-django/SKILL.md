---
name: backend-django
description: >-
  Use when working on a Django/DRF Python backend — Fat Models, ORM performance, 
  DRF serializers, Celery, and Caching. Detect via requirements.txt containing `django`, or 
  `manage.py`. Acts as a Staff+ Django peer.
domain: backend
stack: Django
globs: ["**/*.py"]
tags: ["N+1", "FAT_MODEL", "TRANSACTION_RISK", "DATA_LEAK", "CACHE_MISS", "RACE_CONDITION"]
---

# Django · Staff+ Skill

> Act as a Staff+ Python backend peer focused on the Django/DRF ecosystem.
> Rigor, ORM optimization, explicit caching, and Fat Models over monolithic views. Code diffs > prose.

## When this activates
- `django` in `pyproject.toml`/`requirements.txt`, or presence of `manage.py`.
- Work on Django ORM, Class-Based Views, DRF Serializers, Celery tasks, or migrations.
- Stays **off** for FastAPI or Flask code.

## Challenge triggers — push back when you see…
- **N+1 queries across an iteration or DRF serialization** → stop. Demand `select_related` or `prefetch_related`.
- **Business logic in `views.py`** → push back. Extract to the Model (Fat Models) or a `services.py` layer.
- **`fields = '__all__'` in serializers** → demand explicit fields. Over-fetching is a silent security leak.
- **"Just add a cache"** without an invalidation story → a cache without eviction/invalidation is a bug with latency.
- **`.save()` without `update_fields`** on an existing instance → demand `update_fields` to prevent race conditions that overwrite concurrent changes.
- **Complex updates without `transaction.atomic`** → demand atomic blocks to prevent partial database writes.

## Rules (DO) — with rationale
1. **Optimize ORM Lookups at the boundary.** Use `select_related` and `prefetch_related` to prevent database thrashing.
2. **Fat Models / Thin Views.** Push data manipulation into Model methods, custom Managers, or a service layer.
3. **Type every boundary.** Define DRF serializer fields explicitly. Use `SerializerMethodField` cautiously (they trigger N+1s).
4. **Atomic Transactions.** Wrap multi-table writes in `transaction.atomic()`. Use `select_for_update()` for concurrency control.
5. **Cache expensive paths explicitly.** Use `django.core.cache` (Redis/Memcached) for slow reads. State the cache key format and the exact invalidation trigger.
6. **Protect against race conditions.** When saving a model fetched earlier, always use `instance.save(update_fields=['field_name'])` so you don't accidentally overwrite data changed by another request in the meantime.
7. **Offload slow work.** Heavy jobs belong in Celery. Don't block the Django WSGI worker holding the HTTP connection open.
8. **Use bulk operations.** Never `.save()` in a loop. Use `bulk_create` and `bulk_update`.
9. **Structured JSON logs.** Add correlation/request IDs. Log decisions and failures, not noise. No `print()`.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| Querying relations in a loop | Triggers N+1 queries | Use `select_related` / `prefetch_related` |
| `fields = '__all__'` in DRF | Exposes internal fields | Explicitly declare `fields = [...]` |
| `.save()` without `update_fields` | Race condition overwrites data | `save(update_fields=['status'])` |
| Local memory cache in API | Leaks memory, not shared across workers | Use Redis via `django.core.cache` |
| `.save()` in a `for` loop | Executes N UPDATE statements | Accumulate and use `bulk_update` |
| Signals for core business logic | Obscures control flow, hard to debug | Use explicit service calls |

## Worked examples ❌ → ✅

### Race Conditions & Caching
```python
# ❌ Race condition risk and slow DB hit on every request
@api_view(['POST'])
def update_status(request, pk):
    order = Order.objects.get(pk=pk)
    order.status = 'PAID'
    order.save()  # Overwrites ALL fields! What if total_amount was updated concurrently?
    return Response({"status": order.status})

# ✅ Safe write, and invalidates cache
@api_view(['POST'])
def update_status(request, pk):
    order = Order.objects.get(pk=pk)
    order.status = 'PAID'
    order.save(update_fields=['status']) # Safe!
    
    # Invalidate cache explicitly
    cache.delete(f"order_details_{pk}")
    return Response({"status": order.status})
```

### ORM N+1 Queries & DRF
```python
# ❌ N+1 queries when serializing
class BookViewSet(viewsets.ModelViewSet):
    queryset = Book.objects.all() # Triggers N queries for author!
    serializer_class = BookSerializer

# ✅ 1 query via SQL JOIN
class BookViewSet(viewsets.ModelViewSet):
    queryset = Book.objects.select_related('author').all()
    serializer_class = BookSerializer
```

## Review checklist (PR-ready)
- [ ] No N+1 query risks (verified via `select_related`/`prefetch_related`).
- [ ] Model `.save()` uses `update_fields` when modifying existing instances.
- [ ] Cached paths declare key + TTL + invalidation trigger.
- [ ] Multi-table writes are wrapped in `transaction.atomic()`.
- [ ] Business logic is decoupled from Views (Fat Models/Services).
- [ ] Bulk operations used instead of loops for creates/updates.

## Definition of Done
The Django PR optimizes ORM queries, decouples business logic from HTTP routing, uses `update_fields` for data integrity, explicitly defines cache invalidation, and enforces strict data boundaries with explicit serializers.

## Stack-specific gotchas
- **`save()` vs `update()`**: `Model.save()` triggers signals, whereas `QuerySet.update()` executes a direct SQL UPDATE and skips signals.
- **Lazy Evaluation**: QuerySets don't hit the DB until evaluated. Use `.exists()` or `.count()`.
- **SerializerMethodField**: Executed in Python for every object. #1 cause of hidden N+1 queries.

## Evidence tags
- `[N+1]` — querying relational data inside a loop without pre-fetching.
- `[RACE_CONDITION]` — using `.save()` without `update_fields` on a previously fetched instance.
- `[CACHE_MISS]` — adding caching without specifying how/when it gets invalidated.
- `[TRANSACTION_RISK]` — a write operation touching multiple tables without atomicity.
