# Backend rule module — FastAPI / Python

**Append to `<project>/.claude/rules.md`** when the project uses FastAPI (detected via a `fastapi` dependency in `pyproject.toml` / `requirements*.txt`, without a Django `manage.py`).

---

### B-FA-01 — Validate all input with Pydantic models, never raw dicts
**Status:** ACTIVE
**Why:** Unvalidated request bodies are the entry point for injection, mass-assignment, and type-confusion bugs.
**Detect:** path/handler functions that accept `dict`, `Request` raw body, or `**kwargs` and pass them straight to a DB call or business logic without a Pydantic model.
**Fix:** declare a Pydantic `BaseModel` (or SQLModel) request schema with explicit typed fields; let FastAPI validate before your code runs. Use a separate response model to avoid leaking fields.

### B-FA-02 — No blocking I/O inside `async def` routes
**Status:** ACTIVE
**Why:** A blocking call (sync DB driver, `requests`, `time.sleep`, heavy CPU) inside an async route stalls the entire event loop — the classic FastAPI performance killer.
**Detect:** `async def` handlers calling `requests.*`, sync ORM queries, `time.sleep`, `open()` on large files, or subprocess `.run()` without offloading.
**Fix:** use async clients (`httpx.AsyncClient`, async DB driver) OR offload blocking work with `await run_in_threadpool(...)` / `asyncio.to_thread(...)`. For long jobs use the task queue, not the request path.

### B-FA-03 — AuthN/AuthZ via dependencies, not inline checks
**Status:** ACTIVE
**Why:** Scattered `if token...` checks are inconsistently applied and easy to forget on a new endpoint.
**Detect:** handlers that parse the `Authorization` header or read the current user inline instead of via `Depends(...)`.
**Fix:** define `get_current_user` / `require_role(...)` dependencies and attach them with `Depends`. Protect whole routers with `dependencies=[Depends(require_role("admin"))]`.

### B-FA-04 — Multi-step DB writes are transactional
**Status:** ACTIVE
**Why:** A partial write on failure leaves inconsistent state (the classic "created the order but not the line items").
**Detect:** two or more `session.add`/`.execute` mutations in one handler without a surrounding transaction/`begin()`.
**Fix:** wrap related writes in a single transaction (`async with session.begin():`), commit once, and let it roll back on exception.

### B-FA-05 — No secrets or config literals in code
**Status:** ACTIVE
**Why:** Hard-coded keys leak in git history and can't rotate per-environment.
**Detect:** string literals that look like keys/URLs/passwords in source; `os.getenv` scattered ad-hoc.
**Fix:** use Pydantic `BaseSettings` (pydantic-settings) to load config from env once; reference the settings object. Never commit `.env`.

### B-FA-06 — Errors return user-safe messages; details logged server-side
**Status:** ACTIVE
**Why:** Reinforces baseline S-13. Returning `str(e)` or a stack trace leaks internals (DB names, paths, versions).
**Detect:** `except ... : raise HTTPException(detail=str(e))` or handlers returning raw exception text; `debug=True` in production settings.
**Fix:** raise `HTTPException` with a generic message + stable error code; log the real exception with context server-side. Keep `debug=False` outside local/staging.

### B-FA-07 — Declare response_model and status codes explicitly
**Status:** ACTIVE
**Why:** Without `response_model`, handlers can leak internal fields (password hashes, internal flags) and the OpenAPI contract drifts.
**Detect:** route decorators without `response_model=` that return ORM objects or dicts directly.
**Fix:** set `response_model=<PublicSchema>` and an explicit `status_code=`; the public schema whitelists returnable fields.

### B-FA-08 — Background/long work goes to the task queue, not `BackgroundTasks` for heavy jobs
**Status:** ACTIVE
**Why:** `BackgroundTasks` runs in-process and dies with the worker; scans and long jobs need a real queue (arq/Celery) with retries and idempotency.
**Detect:** `BackgroundTasks.add_task` used for long-running/critical work (scans, external calls that must not be lost).
**Fix:** enqueue to arq/Celery with an idempotency key; keep `BackgroundTasks` only for trivial fire-and-forget (e.g. a metric ping).

### B-FA-09 — Pin CORS, hosts, and docs exposure
**Status:** ACTIVE
**Why:** `allow_origins=["*"]` with credentials, or public `/docs` on an internal service, are easy production mistakes.
**Detect:** `CORSMiddleware(allow_origins=["*"], allow_credentials=True)`; `TrustedHostMiddleware` absent; `/docs` `/redoc` exposed on non-public services.
**Fix:** set explicit allowed origins/hosts from config; disable or auth-gate docs where appropriate.

### B-FA-10 — Type-annotate and keep mypy clean
**Status:** ACTIVE
**Why:** FastAPI leans on type hints; untyped handlers lose validation and let whole bug classes through.
**Detect:** handlers/dependencies without parameter/return annotations; `# type: ignore` without justification.
**Fix:** annotate all handlers, dependencies, and models; keep `mypy` (or `pyright`) green in CI.
