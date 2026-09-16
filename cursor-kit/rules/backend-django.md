# Backend rule module — Django / Python

**Append to `<project>/.claude/rules.md`** when the project uses Django.

---

### B-DJ-01 — Use ModelForm / DRF Serializers, not raw input
**Status:** ACTIVE
**Detect:** views that read `request.POST` / `request.data` and pass directly to `Model.objects.create(**request.data)`.
**Fix:** use `ModelForm` (Django) or `Serializer` (DRF) with explicit fields. Validate before saving.

### B-DJ-02 — All multi-table writes inside `transaction.atomic()`
**Status:** ACTIVE
**Detect:** sequential `Model.save()` calls that should be atomic but aren't wrapped.
**Fix:** wrap in `with transaction.atomic(): ...` or use `@transaction.atomic` decorator on the view/method.

### B-DJ-03 — No raw queries with user input
**Status:** ACTIVE
**Detect:** `Model.objects.raw(f"SELECT ... WHERE name = '{name}'")` patterns.
**Fix:** parameterize: `Model.objects.raw('... WHERE name = %s', [name])`. Or use the ORM filters.

### B-DJ-04 — `select_related` / `prefetch_related` for N+1
**Status:** ACTIVE
**Detect:** loops over querysets that access related objects without prefetching.
**Fix:** `Model.objects.select_related('foreign_key')` for forward relations, `prefetch_related('reverse_set')` for reverse relations.

### B-DJ-05 — Permissions via `permission_classes`, not in-view checks
**Status:** ACTIVE
**Detect:** DRF views with inline `if request.user.id != obj.user_id: raise PermissionDenied`.
**Fix:** define a `BasePermission` class and add to `permission_classes = [IsOwnerOrReadOnly]`.

### B-DJ-06 — Celery tasks idempotent + locked
**Status:** ACTIVE
**Detect:** `@shared_task` functions that mutate state without an idempotency key or distributed lock.
**Fix:** check the action hasn't been done before, OR use Redis-based distributed lock (e.g. `redis_lock` library).

### B-DJ-07 — Don't expose exception messages in DEBUG=False
**Status:** ACTIVE
**Why:** Reinforces S-13. Django's `DEBUG=True` leaks everything; production should be `DEBUG=False`.
**Detect:** views that catch exceptions and return `JsonResponse({'error': str(e)})` in production paths.
**Fix:** use Django's built-in error handling. Custom 500 handler returns generic message. Log details server-side.

### B-DJ-08 — Migrations have working `migrations.RunPython` reverse functions
**Status:** ACTIVE
**Detect:** data migrations with `migrations.RunPython(forward, migrations.RunPython.noop)` where reverse should exist.
**Fix:** write a real reverse function unless the data migration is genuinely irreversible (document why).
