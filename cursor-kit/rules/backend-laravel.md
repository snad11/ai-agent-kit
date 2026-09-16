# Backend rule module — Laravel / PHP

**Append to `<project>/.claude/rules.md`** when the project uses Laravel.

---

### B-LV-01 — All controllers use Form Requests for validation
**Status:** ACTIVE
**Why:** Validation in the controller body is hard to test, easy to bypass, and clutters the controller.
**Detect:** controller methods that call `$request->validate([...])` inline instead of type-hinting a Form Request class.
**Fix:** create `app/Http/Requests/<Action>Request.php` with `rules()` and `authorize()` methods. Type-hint it in the controller: `public function store(StoreUserRequest $request)`.

### B-LV-02 — All multi-table writes inside DB transactions
**Status:** ACTIVE
**Detect:** sequential `Model::create()` / `->save()` calls without `DB::transaction()` wrapper.
**Fix:** wrap in `DB::transaction(function () { ... });`. For complex flows use `DB::beginTransaction()` / `DB::commit()` / `DB::rollBack()` with try-catch.

### B-LV-03 — No raw queries with user input
**Status:** ACTIVE
**Detect:** `DB::raw("... $userInput ...")`, `DB::select("... $var ...")`, `whereRaw('... ' . $userInput)`.
**Fix:** always parameterize: `DB::select('... WHERE id = ?', [$id])`, `whereRaw('column = ?', [$value])`. Or use the query builder methods.

### B-LV-04 — Eloquent N+1 query detection
**Status:** ACTIVE
**Why:** N+1 queries are the #1 Laravel performance killer. Loading 100 users with their posts = 101 queries instead of 2.
**Detect:** loops over Eloquent collections that access relationships without `with()` eager-loading. `User::all()` followed by `foreach { $user->posts }`.
**Fix:** use eager loading: `User::with('posts')->get()`. Enable `Model::preventLazyLoading()` in `AppServiceProvider::boot()` for development environment to fail loudly on lazy loads.

### B-LV-05 — Mass assignment protection
**Status:** ACTIVE
**Why:** Without `$fillable` or `$guarded`, a user can post `is_admin=true` to a user-update endpoint and become admin.
**Detect:** Eloquent models without `$fillable` or `$guarded = []` is a critical anti-pattern.
**Fix:** every model has an explicit `protected $fillable = ['name', 'email', ...]` listing only the user-updatable fields.

### B-LV-06 — Routes use middleware for auth
**Status:** ACTIVE
**Detect:** routes in `routes/api.php` / `routes/web.php` that handle authenticated actions but don't have `auth` / `auth:sanctum` / `auth:api` middleware applied.
**Fix:** wrap in `Route::middleware('auth:sanctum')->group(function () { ... });` or use route-level middleware.

### B-LV-07 — Authorization via Policies / Gates, not in-controller checks
**Status:** ACTIVE
**Detect:** controllers with inline `if ($user->id !== $post->user_id) abort(403);` checks.
**Fix:** create a Policy: `php artisan make:policy PostPolicy --model=Post`. Use `$this->authorize('update', $post);` in the controller.

### B-LV-08 — Queue jobs idempotent
**Status:** ACTIVE
**Why:** Queue workers can re-process a job after a crash. If the job isn't idempotent, you double-charge / double-send / double-create.
**Detect:** `dispatch(new Job(...))` jobs that mutate state without an idempotency key check or `unique()` job middleware.
**Fix:** use `ShouldBeUnique` interface OR check at the start of `handle()` whether the action has already been performed (e.g. lookup by external ID).

### B-LV-09 — Use Logger facade, not var_dump / dd / print_r
**Status:** ACTIVE
**Detect:** `dd(`, `dump(`, `var_dump(`, `print_r(` in committed code (allowed in `tests/`).
**Fix:** use `Log::info(...)` / `Log::error(...)` / `Log::debug(...)`.

### B-LV-10 — Don't expose `$exception->getMessage()` in production responses
**Status:** ACTIVE
**Why:** Stack traces and exception messages leak schema details. Reinforces S-13.
**Detect:** `return response()->json(['error' => $e->getMessage()])` in catch blocks.
**Fix:** in `app/Exceptions/Handler.php`, render exceptions per environment. In production, return generic messages. In dev/staging, return detail. Use Laravel's built-in `APP_DEBUG=false` for production.

### B-LV-11 — Migrations have working `down()` methods
**Status:** ACTIVE
**Detect:** migration files in `database/migrations/` with empty `down()` methods or only `up()` defined.
**Fix:** every migration has a working `down`. If a column drop is genuinely irreversible (e.g. data loss), document with `// IRREVERSIBLE: explanation` and require explicit acknowledgment in the PR.
