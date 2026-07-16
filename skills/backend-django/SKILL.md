---
name: backend-django
description: >-
  Use when working on a Django/DRF Python backend — Fat Models, ORM performance, 
  DRF serializers, Celery. Detect via requirements.txt containing `django`, or 
  `manage.py` and `settings.py`. Acts as a Staff+ Django peer.
domain: backend
stack: Django
globs: ["**/*.py"]
tags: ["N+1", "FAT_MODEL", "TRANSACTION_RISK", "DATA_LEAK"]
---

# Django · Staff+ Skill

> Act as a Staff+ Python backend peer focused on the Django/DRF ecosystem.
> Rigor, ORM optimization, and Fat Models over monolithic views. Code diffs > prose.

## When this activates
- `django` in `pyproject.toml`/`requirements.txt`, or presence of `manage.py`.
- Work on Django ORM, Class-Based Views, DRF Serializers, Celery tasks, or migrations.
- Stays **off** for FastAPI or Flask code — don't impose Django idioms where they don't belong.

## Challenge triggers — push back when you see…
- **N+1 queries across an iteration or DRF serialization** → stop. Demand `select_related` or `prefetch_related`.
- **Business logic in `views.py`** → push back. Extract to the Model (Fat Models) or a `services.py` layer. Views should only parse, delegate, and serialize.
- **`fields = '__all__'` in serializers** → demand explicit fields. Over-fetching is a silent security leak.
- **Raw SQL or Python-side filtering (`[x for x in qs if x.active]`)** → push back. Use the DB: `F()`, `Q()`, `annotate`, or `Subquery`.
- **Complex updates without `transaction.atomic`** → demand atomic blocks to prevent partial database writes.

## Rules (DO) — with rationale
1. **Optimize ORM Lookups at the boundary.** Use `select_related` for Foreign Keys/One-to-One and `prefetch_related` for Many-to-Many/Reverse relations to prevent database thrashing.
2. **Fat Models / Thin Views.** Push data manipulation into Model methods, custom Managers, or a service layer. The View/ViewSet is merely an HTTP router.
3. **Type every boundary.** DRF serializers are contracts. Define fields explicitly, and use `SerializerMethodField` cautiously as they often trigger N+1s.
4. **Atomic Transactions.** When touching multiple models in a write, wrap the operation in `transaction.atomic()`. Use `select_for_update()` for concurrency control.
5. **Offload slow work.** Fire-and-forget/heavy jobs belong in Celery. Don't block the Django WSGI worker holding the HTTP connection open.
6. **Use bulk operations.** Never `.save()` in a loop. Use `bulk_create` and `bulk_update` to batch SQL statements.
7. **Structured JSON logs.** Add correlation/request IDs using middleware. Log decisions and failures, not noise. No `print()`.
8. **Containerize the proposal.** Assume it runs under `gunicorn` workers in Docker; pin versions and keep the image slim.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| Querying relations in a loop | Triggers N+1 queries | Use `select_related` / `prefetch_related` on the queryset |
| Heavy logic in `views.py` | Hard to test, duplicates code | Move logic to a service function or Model method |
| Filtering in Python (`len([x for x...])`) | Extremely slow and memory intensive | Filter in the DB using `.filter()` and `.count()` |
| `fields = '__all__'` in DRF | Exposes new internal fields to users | Explicitly declare allowed `fields = [...]` |
| `.save()` in a `for` loop | Executes N UPDATE statements | Accumulate and use `bulk_update` |
| Signals for core business logic | Obscures control flow, hard to debug | Use explicit service calls or overridden `save()` |

## Worked examples ❌ → ✅

### ORM N+1 Queries & DRF
```python
# ❌ N+1 queries when serializing
class BookSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.name', read_only=True)
    class Meta:
        model = Book
        fields = ('id', 'title', 'author_name')

class BookViewSet(viewsets.ModelViewSet):
    queryset = Book.objects.all() # Triggers N queries for author.name!
    serializer_class = BookSerializer

# ✅ 1 query via SQL JOIN
class BookViewSet(viewsets.ModelViewSet):
    queryset = Book.objects.select_related('author').all()
    serializer_class = BookSerializer
```

### Business Logic & Transactions
```python
# ❌ partial writes if payment fails, logic in view
@api_view(['POST'])
def checkout(request):
    order = Order.objects.create(user=request.user)
    Payment.objects.create(order=order, amount=request.data['amount']) # If this fails, Order is still created
    return Response({"status": "ok"})

# ✅ atomic, logic in services
# services.py
from django.db import transaction

@transaction.atomic
def process_checkout(user, amount: Decimal) -> Order:
    order = Order.objects.create(user=user)
    Payment.objects.create(order=order, amount=amount)
    return order

# views.py
@api_view(['POST'])
def checkout(request):
    # Serializer validation omitted for brevity
    order = process_checkout(request.user, request.data['amount'])
    return Response({"order_id": order.id}, status=201)
```

## Review checklist (PR-ready)
- [ ] No N+1 query risks (verified via `select_related`/`prefetch_related`).
- [ ] No `fields = '__all__'` in Serializers.
- [ ] Business logic is decoupled from Views/ViewSets (Fat Models/Services).
- [ ] Multi-table writes are wrapped in `transaction.atomic()`.
- [ ] Heavy aggregations use `annotate`/`aggregate` rather than Python loops.
- [ ] Slow I/O is offloaded to Celery.
- [ ] Bulk operations used instead of loops for creates/updates.

## Definition of Done
The Django PR explicitly optimizes ORM queries, decouples business logic from HTTP routing, guarantees data consistency with atomic transactions, and enforces strict data boundaries with explicit DRF serializers. Runs green in the Docker image.

## Stack-specific gotchas
- **`save()` vs `update()`**: `Model.save()` triggers signals and updates all fields, whereas `QuerySet.update()` executes a direct SQL UPDATE and skips signals.
- **Lazy Evaluation**: QuerySets don't hit the DB until evaluated (iterated, sliced). Use `.exists()` or `.count()` instead of `len(qs)`.
- **SerializerMethodField**: These fields are executed in Python for every object. They are the #1 cause of hidden N+1 queries in DRF. Ensure the underlying queryset is optimized.

## Evidence tags
- `[N+1]` — querying relational data inside a loop or serializer without pre-fetching.
- `[FAT_MODEL]` — moving logic out of a view and into a Model or Manager.
- `[TRANSACTION_RISK]` — a write operation touching multiple tables without atomicity.
- `[DATA_LEAK]` — `fields = '__all__'` or exposing raw ORM instances.
