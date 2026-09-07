# Backend rule module — NestJS / TypeScript

**Append to `<project>/.claude/rules.md`** when the project uses NestJS.

---

### B-NEST-01 — All controllers use DTOs (class-validator)
**Status:** ACTIVE
**Detect:** controller methods accepting `@Body()` without a typed DTO class.
**Fix:** create a DTO class with `@IsString`, `@IsEmail`, `@IsUUID`, `@IsOptional`, etc. NestJS auto-validates when `ValidationPipe` is registered globally in `main.ts`.

### B-NEST-02 — All multi-table writes inside transactions
**Status:** ACTIVE
**Detect:** sequential `db.insert()` / `db.update()` calls that should be atomic but aren't wrapped in a transaction.
**Fix:** wrap in `db.transaction(async (tx) => { ... })` (Drizzle) or `manager.transaction(async (tx) => { ... })` (TypeORM) or `@Transaction()` decorator.

### B-NEST-03 — No raw SQL strings unless necessary
**Status:** ACTIVE
**Detect:** `sql\`SELECT ... ${userInput}\`` template literals without parameterization. `query(\`...${var}...\`)` patterns.
**Fix:** use the query builder with parameterized values. If raw SQL is needed, use `sql.placeholder()` (Drizzle) or `query('... WHERE id = $1', [id])` (TypeORM).

### B-NEST-04 — Cron jobs idempotent + locked (multi-instance safe)
**Status:** ACTIVE
**Why:** Concurrent execution risk on multi-instance deploys.
**Detect:** `@Cron(...)` handlers without distributed locking (Redis lock via `ioredis`, DB advisory lock, etc.).
**Fix:** acquire a lock at the start, release at the end. Skip the run if the lock is held. Libraries: `@nestjs/schedule` + `redlock` (Redis distributed lock).

### B-NEST-05 — `@RequirePermissions(...)` decorators must have matching guards
**Status:** ACTIVE
**Why:** A permissions decorator without the corresponding `@UseGuards(PermissionsGuard)` is INERT — the metadata is set but nothing reads it.
**Detect:** any controller method with `@RequirePermissions` / `@Roles` / `@Permissions` but no `@UseGuards(...)` (or class-level equivalent).
**Fix:** every permission/role decorator needs the matching guard, or remove the decorator. Add it to the class-level `@UseGuards()` if it applies to all methods.

### B-NEST-06 — All async operations have timeouts
**Status:** ACTIVE
**Why:** A hung HTTP call to a third-party API will block a worker thread indefinitely.
**Detect:** `axios.get(url)` / `fetch(url)` / `httpService.get(url)` without `timeout` / `AbortController`.
**Fix:** every external call has an explicit timeout (default 10s for normal calls, 30s for uploads). NestJS HttpService: `firstValueFrom(httpService.get(url, { timeout: 10000 }))`.

### B-NEST-07 — Use NestJS Logger, not console
**Status:** ACTIVE
**Detect:** `console.log` / `console.error` in services / controllers / providers.
**Fix:** inject `Logger` from `@nestjs/common`: `private readonly logger = new Logger(MyService.name);` then `this.logger.log(...)` / `this.logger.error(...)`.

### B-NEST-08 — Module providers explicit, no circular deps
**Status:** ACTIVE
**Detect:** module files with `forwardRef(() => OtherModule)` (a sign of circular dependency).
**Fix:** restructure to break the cycle — extract shared logic to a third module, or use events/queues for the cross-module call.
