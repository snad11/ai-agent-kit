# Project rules — universal baseline

**This is the portable subset of rules that apply to any project**, regardless of stack. The bootstrap process copies this file into `<project>/.claude/rules.md` and then APPENDS stack-specific rules from `rules/*.md` based on what's detected in the project.

After bootstrap, you (and the dev team) can edit this file freely to add project-specific rules. The skills (`/x-rules`, `/x-check`, `/x-implement`) read whatever is in `<project>/.claude/rules.md` — they don't care which rules came from the baseline vs the stack modules vs your additions.

**Kit version:** agent-kit v1.1 (mirrored to claude-kit v1.2) · **Last updated:** 2026-08-18

Version numbers for the kit, the skills, and `PROMPT_GENERATOR.md` are pinned in one place: `/Users/mac/Projects/.ai/README.md`. Do not read a version from anywhere else.

---

## Categories

1. [Auth & Authorization rules](#1-auth--authorization-rules)
2. [Security rules](#2-security-rules)
3. [Data & Privacy rules](#3-data--privacy-rules)
4. [Code quality rules](#4-code-quality-rules)
5. [Workflow rules](#5-workflow-rules)

---

## 1. Auth & Authorization rules

### A-01 — Admin/privileged endpoints check role server-side
**Status:** ACTIVE
**Why:** Skipping the check is the most common privilege-escalation vector. Universal across all stacks.
**Detect:** controllers / route handlers in admin/privileged paths that don't explicitly verify the caller's role from a trusted source (session, JWT claim, server-fetched profile).
**Fix:** every privileged endpoint must call `requireRole('admin')` or equivalent before processing the request. Cookie/header-based role claims must be verified server-side, never trusted from the client.

### A-02 — No client-spoofable role checks
**Status:** ACTIVE
**Why:** Trusting `localStorage.role` or `cookie.user_role` for authorization is bypassed in 5 seconds with the dev console.
**Detect:** middleware/guards that read role from a cookie, localStorage, header, or form value set by the client.
**Fix:** verify role server-side from the session/JWT. If middleware needs to know the role, it should call the backend or decode a signed JWT — never trust client-set state.

### A-03 — Auth tokens in HttpOnly cookies (web) or secure storage (mobile)
**Status:** ACTIVE
**Why:** Tokens in `localStorage` are XSS-readable. Tokens in plaintext mobile storage (Hive without encryption, plain SharedPreferences, NSUserDefaults) are device-compromise-readable.
**Detect:**
  - Web: `localStorage.setItem('token'`, `localStorage.setItem('jwt'`, `localStorage.setItem('access_token'`, etc.
  - iOS: `UserDefaults.standard.set(token...)`
  - Android: `SharedPreferences ... .putString("token"...)`
  - Flutter: `Hive.box.put('token'...)`, `SharedPreferences.setString('token'...)`
**Fix:** server-set HttpOnly + Secure + SameSite cookies for web. Platform secure storage for mobile (`flutter_secure_storage`, iOS Keychain via `keychain_swift`, Android EncryptedSharedPreferences).

### A-04 — `Math.random()` (or equivalent) forbidden in security-sensitive code
**Status:** ACTIVE
**Why:** Crypto-weak. PRNGs are predictable and can be reverse-engineered to predict OTPs, password reset tokens, session IDs, etc.
**Detect:**
  - JS/TS: `Math.random()` in files matching `auth|otp|password|token|crypto|verify|reset|session`
  - Python: `random.random()` / `random.choice()` / `random.randint()` in same context
  - PHP: `rand()`, `mt_rand()`, `uniqid()` without `more_entropy=true` in same context
  - Go: `math/rand` in same context
  - Dart: `Random()` (without `.secure()`) in same context
  - Rust: `rand::random()` in same context (use `rand::rngs::OsRng`)
**Fix:**
  - JS/TS: `crypto.randomBytes()` (Node) or `crypto.getRandomValues()` (browser)
  - Python: `secrets.token_hex()`, `secrets.token_urlsafe()`, `secrets.choice()`
  - PHP: `random_bytes()`, `random_int()`
  - Go: `crypto/rand`
  - Dart: `Random.secure()`
  - Rust: `rand::rngs::OsRng`

### A-05 — Refresh token rotation
**Status:** ACTIVE
**Why:** Long-lived sessions need rotation to limit blast radius if a token is leaked.
**Detect:** refresh-token endpoint that returns the same token, doesn't invalidate the old token, or doesn't track refresh-token version per user.
**Fix:** every successful refresh issues a NEW refresh token and invalidates the old one. Track a `refresh_token_version` on the user record and bump it on refresh — old tokens become invalid.

### A-06 — Failed-login lockout (configurable threshold)
**Status:** ACTIVE
**Why:** Brute force prevention. Standard control across ISO 27001, PCI-DSS, NIST 800-63.
**Detect:** login endpoints that don't track failed attempts per user/IP.
**Fix:** per-user (and ideally per-IP) failed-attempt counter. Reset on successful login. Lock for N minutes after M fails (default M=5, N=30, configurable).

### A-07 — Token refresh is mutex-protected (concurrent requests)
**Status:** ACTIVE
**Why:** Without a mutex, N concurrent 401s fire N parallel refresh requests, creating race conditions and spurious logouts.
**Detect:** refresh-token interceptors / HTTP clients without locking.
**Fix:** mutex/lock around the refresh call. Concurrent 401s wait on the same in-flight refresh, not fire N parallel refreshes. Examples: `synchronized` package (Dart), `async-mutex` (JS), `sync.Once` (Go), `threading.Lock` (Python).

---

## 2. Security rules

### S-01 — No hardcoded API keys / secrets in source
**Status:** ACTIVE
**Why:** Standard hygiene. Keys in source code leak via git history, log forwarding, repo cloning, etc.
**Detect:** strings matching:
  - `AIza[0-9A-Za-z-_]{35}` (Google API keys)
  - `sk_(test|live)_[0-9a-zA-Z]{20,}` (Stripe secret keys)
  - `pk_(test|live)_[0-9a-zA-Z]{20,}` (Stripe publishable keys)
  - `ghp_[0-9a-zA-Z]{36}` (GitHub personal access tokens)
  - `glpat-[0-9a-zA-Z_-]{20,}` (GitLab personal access tokens)
  - Generic env-like assignments: `(api_key|secret_key|access_key|private_key)\s*[=:]\s*["'][a-zA-Z0-9_-]{20,}["']`
  - AWS access keys: `AKIA[0-9A-Z]{16}`
  - Slack tokens: `xox[baprs]-[0-9a-zA-Z]{10,}`
**Fix:** move to env var, read via `process.env.X` (Node) / `dart-define` (Flutter) / `os.Getenv` (Go) / `os.environ` (Python) / `getenv` (PHP). Rotate the leaked key in the provider's console immediately.

### S-02 — No `.env` files committed
**Status:** ACTIVE
**Why:** Standard hygiene. `.env.example` / `example.env` is fine; actual `.env` is not.
**Detect:** `.env`, `.env.local`, `.env.production`, `.env.staging` files in any commit (any name pattern that doesn't include `example`, `template`, `sample`).
**Fix:** add to `.gitignore`. Use `.env.example` for the schema (no real values).

### S-03 — Verbose query loggers off in production
**Status:** ACTIVE
**Why:** Query loggers that print full SQL with parameter values leak schema details + PII into log files.
**Detect:**
  - Drizzle: `drizzle({ logger: true })` without env-gate
  - Prisma: `new PrismaClient({ log: ['query'] })` without env-gate
  - SQLAlchemy: `engine = create_engine(..., echo=True)` without env-gate
  - Eloquent (Laravel): `DB::enableQueryLog()` without env-gate in production routes
  - Mongoose: `mongoose.set('debug', true)` without env-gate
**Fix:** wrap with env check, e.g. `drizzle({ logger: process.env.NODE_ENV !== 'production' })`.

### S-05 — Input validation at every API boundary
**Status:** ACTIVE
**Why:** Without validation, you trust user input. OWASP A03 (Injection).
**Detect:** route handlers / controllers / lambdas that accept request bodies without a typed schema (DTO, Zod schema, Pydantic model, JSON-schema, etc.) and pass the raw input to a query/operation.
**Fix:** every endpoint has a typed input schema. Validation runs BEFORE the handler. Examples: Zod (TS), class-validator (NestJS), Pydantic (Python), Joi (JS), validator (Go), Laravel form requests, Marshmallow (Python).

### S-06 — No unsanitized HTML rendering
**Status:** ACTIVE
**Why:** XSS prevention.
**Detect:**
  - React: `dangerouslySetInnerHTML={{ __html: <variable> }}` where `<variable>` is not statically known
  - Vue: `v-html="<variable>"`
  - Angular: `[innerHTML]="<variable>"` without `DomSanitizer`
  - Vanilla: `element.innerHTML = <variable>` from user input
  - Flutter: `Html.fromString` / `flutter_html` without allowed-tags list
**Fix:** use a sanitizer (DOMPurify for web, `flutter_html` with allowed-tags list, ngSanitize / DomSanitizer for Angular).

### S-07 — `href` / `src` URL allowlist (block `javascript:` and `data:` URLs)
**Status:** ACTIVE
**Why:** XSS via `javascript:` URLs is a classic vector. `data:` URLs can deliver HTML/JS.
**Detect:** any `href={var}` / `src={var}` (React/JSX), `href="{{ var }}"` (Vue/Angular templates), or `setAttribute('href', var)` where `var` comes from user input without protocol validation.
**Fix:** validate protocol is `http`, `https`, `mailto`, or `tel`. Reject `javascript:`, `data:`, `vbscript:`, `file:`. Helper function: `isSafeUrl(url)` should be called everywhere.

### S-08 — API proxies require auth + origin + rate-limit
**Status:** ACTIVE (frontend frameworks with built-in API routes)
**Why:** Open API proxies become open relays — anyone in the world can use your frontend domain to call your backend without going through your auth.
**Detect:** Next.js API routes (`pages/api/`, `app/api/`), Nuxt server routes, SvelteKit endpoints, Remix loaders that forward requests to a backend without origin/auth/rate-limit checks.
**Fix:** verify origin (allowlist of domains), require auth header to forward, apply rate limit per IP/user. Or skip the proxy and call backend directly with CORS configured.

### S-10 — Asset/upload ownership enforced server-side
**Status:** ACTIVE
**Why:** Without ownership tracking, any authenticated user can claim any uploaded file as theirs (KYC docs, profile photos, private attachments).
**Detect:** asset/upload endpoints that don't set `createdBy` / `userId` from `req.user.id` server-side, or queries with `OR createdBy IS NULL` (or equivalent ownership-bypass clauses).
**Fix:** `createdBy` / `userId` set from the authenticated session, never from the client. Ownership query uses `WHERE createdBy = ?` with no `OR NULL` escape.

### S-11 — Seed/dev/admin endpoints require auth + env-gate
**Status:** ACTIVE
**Why:** Seed endpoints (used to populate test data) are catastrophic if exposed in production — anyone can spawn fake users / KYC docs / privileged accounts.
**Detect:** any endpoint with `seed`, `dev`, `debug`, `test`, `playground` in the path that lacks auth.
**Fix:** wrap in admin-auth + env-gate (`if (env.NODE_ENV !== 'production')` — only allow in dev/staging, never production).

### S-12 — Common-password blacklist on signup + password change
**Status:** ACTIVE
**Why:** Without a blacklist, users pick "Password123!" which passes complexity checks. NIST 800-63B recommends blacklists explicitly.
**Detect:** password validation that only checks complexity (length, character classes), not against a known-bad list.
**Fix:** check against the SecLists Top 10k common passwords (or `have-i-been-pwned` API for k-anonymity) on every password set. Reject matches.

### S-13 — User-friendly error messages in production (no raw error leakage)
**Status:** ACTIVE
**Why:** Raw error messages, stack traces, SQL errors, and third-party API errors leak schema details, vendor names, internal paths, and version info. ISO 27001 information disclosure / OWASP A09.
**Detect:**
  - Backend: API responses returning `err.message`, `err.stack`, `String(err)`, `JSON.stringify(err)`, or the raw `err` object. `res.json({ error: err... })` patterns. `throw new HttpException(err.message, ...)`.
  - Mobile: `showSnackBar(e.toString())`, `Text('${e}')`, raw error object exposure in UI
  - Frontend: `toast.error(err.message)`, `<div>{error.message}</div>` rendering API error responses without filtering
**Fix:** wrap error paths with env-gated branches. In `development`/`testing` (and `staging` if explicitly opted in): expose `{ error: 'human msg', detail: err.message, stack: err.stack }`. In `production`: expose `{ error: 'Something went wrong on our end. Please try again or contact support.' }`. ALWAYS log the full error server-side via the structured logger with enough context to debug from logs alone. Sanitize known error categories (DB → "Could not save", third-party → "Service temporarily unavailable", auth → "Invalid credentials", etc.).

---

## 3. Data & Privacy rules

### D-01 — PII encrypted at rest (sensitive fields)
**Status:** ACTIVE
**Why:** Standard compliance requirement (GDPR, ISO 27001, SOC 2).
**Detect:** PII fields (full name, phone, email, DOB, gender, address, government ID, financial data) stored as plaintext in the database when they could be encrypted via column-level encryption or app-level encryption with a KMS key.
**Fix:** use Postgres column encryption (pgcrypto), MySQL/MariaDB native encryption, or app-level encryption with a KMS key (AWS KMS, GCP KMS, HashiCorp Vault). Encryption is per-field, not per-row.

### D-02 — Sensitive documents accessed via signed URLs
**Status:** ACTIVE
**Why:** S3 / object storage URLs returned directly in API responses are permanent and shareable. Signed URLs with TTL limit blast radius.
**Detect:** API responses returning permanent CDN/S3 URLs for sensitive documents (KYC, ID proofs, contracts, medical records).
**Fix:** generate short-TTL signed URLs (5-15 min) per request. Never return permanent URLs. If the file needs to be displayed in an `<img>` tag, refresh the URL on access.

### D-03 — Phone numbers stored in E.164 format
**Status:** ACTIVE
**Why:** Cross-system consistency. SMS gateways, payment providers, lookups all expect a canonical format.
**Detect:** phone field stored without `+` prefix or with spaces/dashes/parens.
**Fix:** strip everything except digits and `+`, validate with `libphonenumber` (or equivalent). Store as `+CCCXXXXXXXXX`.

### D-04 — Soft delete for users (recovery period)
**Status:** ACTIVE
**Why:** Hard delete is irreversible. Soft delete + recovery window protects against accidental deletion AND supports GDPR right-to-erasure (delete after the recovery period).
**Detect:** `DELETE FROM users WHERE id = ?` SQL or `User.delete()` ORM calls without setting `deleted_at` first.
**Fix:** set `deleted_at` timestamp. Hard-delete via cron after N days (default 30). Restore window during the soft-delete period.

### D-05 — Audit log on every privileged write action
**Status:** ACTIVE
**Why:** Compliance + incident response. ISO 27001 A.12.4 (Logging and monitoring).
**Detect:** admin / privileged endpoints that mutate state without writing to an `audit_logs` table.
**Fix:** middleware that auto-logs `{ admin_id, action, target_type, target_id, ip, user_agent, timestamp, before_state?, after_state? }` for every privileged write. Don't roll your own — use a library if one exists for your framework.

---

## 4. Code quality rules

### Q-01 — No `any` / `dynamic` types in production code (typed languages)
**Status:** ACTIVE
**Detect:**
  - TypeScript: `: any`, `as any`. Allowed in tests + types-shim files only.
  - Dart: `dynamic` (use `Object?` or specific types instead)
  - Kotlin: `Any?` overuse where a specific type would work
**Fix:** define a proper type / interface, or use `unknown` (TS) / `Object?` (Dart) + a type guard.

### Q-02 — Don't catch + ignore errors
**Status:** ACTIVE
**Detect:**
  - JS/TS: `catch (e) {}`, `catch { }`, `.catch(() => {})` empty blocks
  - Dart: `catch (_) {}`
  - Python: `except: pass`, `except Exception: pass`
  - Go: assigning errors to `_` without comment explaining why
**Fix:** at minimum log the error. Re-throw if you can't handle it. Silent swallows hide bugs forever.

### Q-03 — Don't use `console.log` / `print` in committed code
**Status:** ACTIVE
**Detect:**
  - JS/TS: `console.log`, `console.debug` (allowed in tests, config files)
  - Dart: `print(` outside `test/` directory
  - Python: bare `print(` in non-CLI / non-script files
  - Go: `fmt.Println` in non-main / non-CLI packages
  - PHP: `var_dump`, `print_r`, `dd()`, `dump()`
**Fix:** use the structured logger (pino, winston, zap, logrus, structlog, monolog, NestJS Logger, talker for Dart, etc.).

### Q-04 — No dead/commented-out code
**Status:** ACTIVE
**Detect:** large blocks of commented code (5+ lines), unused exports, unused functions/imports flagged by lint.
**Fix:** delete it. Git history remembers.

### Q-05 — TODOs require an issue link or owner
**Status:** ACTIVE
**Detect:** `// TODO` / `# TODO` / `<!-- TODO` without `(owner)` or `(#123)` attribution.
**Fix:** `// TODO(name): explain` or `// TODO(#42): explain`. Untraceable TODOs become permanent.

### Q-06 — Don't await in a loop unnecessarily
**Status:** ACTIVE
**Detect:**
  - JS/TS: `for (const x of xs) { await fn(x) }` patterns where parallel is safe
  - Python: `async for` loops with sequential awaits when concurrent is fine
  - Dart: `for (final x in xs) { await fn(x); }` patterns
**Fix:** `Promise.all(xs.map(x => fn(x)))` (JS) / `asyncio.gather(*[fn(x) for x in xs])` (Python) / `Future.wait(xs.map(fn))` (Dart) when order doesn't matter.

### Q-09 — Don't leave default seed-data passwords
**Status:** ACTIVE
**Why:** Default seed passwords (`User@12345`, `admin/admin`, `test/test`) get accidentally deployed and are tried first by attackers.
**Detect:** hardcoded passwords in seeders / fixtures / test data.
**Fix:** generate per-seed random passwords with `crypto.randomBytes` (Node) / `secrets.token_urlsafe` (Python) / `Random.secure()` (Dart). Log to a dev-only file or stdout for the dev team.

### Q-10 — Tests run with explicit testing environment
**Status:** ACTIVE
**Why:** Test side-effects (DB writes, email sends, file uploads) must not pollute dev or prod data.
**Detect:** test scripts in `package.json` / `pubspec.yaml` / `pyproject.toml` / `composer.json` / `Makefile` that don't pass `NODE_ENV=testing` / `--env=testing` / `--dart-define=ENV=testing` / `APP_ENV=testing` / etc. Tests that read `process.env.DATABASE_URL` directly without env-switching first.
**Fix:** test commands look like `NODE_ENV=testing pnpm test`, `APP_ENV=testing phpunit`, `flutter test --dart-define=ENV=testing`. Test bootstrap loads `.env.testing` (not `.env` or `.env.development`). This covers committed scripts; for the agent's own act of running a test, migration, or seeder command, W-05 adds the blocking preflight.

### Q-11 — Reuse before create (search first, extract components, understand before writing)
**Status:** ACTIVE (advisory — semantic, enforced by `/x-implement` and code review)
**Why:** Senior-engineer principle. Duplicated logic/markup across files is the #1 source of inconsistency bugs and refactoring pain. Most "new" code already exists somewhere in the project.
**Detect:** new files/functions/components that re-implement something already in `lib/` / `utils/` / `shared/` / `helpers/` / `components/` / shared widgets. A new helper/component whose name or markup fuzzy-matches an existing one. Copy-pasted blocks (3+ lines, OR any repeated UI/markup/widget subtree) across files. Implementing before reading the existing code/flow it touches.
**Fix:** BEFORE writing, (1) understand the existing code and data flow for what you're touching, and (2) search the codebase — including `components/` and shared widgets — for an existing equivalent and reuse it. If a block of markup or logic repeats, extract ONE reusable component/widget/helper into the shared location and call it from each site. When you do create, name it generically so future callers can reuse it. Don't duplicate to "move faster."

### Q-12 — Standardized doc comment on functions/classes; minimal line-level comments
**Status:** ACTIVE (BLOCKING; semantic). **Scanned on EVERY `/x-check` and `/x-implement` Phase 2 run — same mandatory status as Q-13.** Over-commenting is a violation, not a stylistic nicety: flag it every time, even when nothing else is wrong.
**Why:** A reader should understand a function/class from a short, structured doc comment at the top — what it does, what each parameter means, and what it returns — the way well-documented libraries/packages do. Inside the body, comments stay minimal: the code says WHAT; only the non-obvious WHY earns an inline comment. Document at the boundary, don't narrate the lines.
**Standard (expected form):** non-trivial functions, methods, classes, and exported/public symbols get ONE concise doc comment in the language's convention — TS/JS JSDoc/TSDoc (`/** ... */` with `@param`/`@returns`), PHP PHPDoc (`@param`/`@return`), Dart dartdoc (`///` summary + params/returns), Python docstring (Args/Returns). Keep it to a 1-2 line summary plus param/return meanings — not an essay.
**Detect (over-commenting — the common direction; flag any of these):**
  - **Redundant double-documentation:** the same params documented twice — e.g. per-field JSDoc on an interface/type/props AND a duplicate `@param` block on the function that consumes it. Pick ONE place.
  - **Per-field comments on self-explanatory members:** a `/** ... */` or `//` on every field/prop/enum member whose name already says it (`title`, `subtitle`, `userId`). Only the non-obvious member earns a note.
  - **Per-line WHAT narration:** comments that paraphrase the next line (`// loop through users` above `for (...)`), a comment on nearly every line, or block comments restating obvious code.
  - **Per-change / per-edit narration:** when fixing a bug or adding a feature, comments that explain what an edited line now does or why this specific change was made (`// now also check the status`, `// added to fix the bug`, `// changed to handle the edge case`). Edits get the SAME minimal treatment as new code: if behaviour changed, update the symbol's ONE doc-comment header — never annotate the diff line-by-line. The git history records what changed; the code does not.
  - **Essay docblocks:** multi-paragraph headers where 1–2 lines suffice.
  - **Preamble-above-a-branch / preamble-above-a-call narration:** multi-line `//` blocks immediately above an `if`, a method call, or a guard that explain the policy / model the code implements ("The designer is authoritative on price…", "Soft payment gate: starting production normally requires…", "Dedicated alert when the designer moves the agreed price…"). That belongs in the surrounding function's / class's doc-comment header (or in the design doc / PR description), not inline above the code that implements it. Inline keeps only WHY notes where the code itself can't say it (a workaround, a known bug ID, a non-obvious invariant) — every "why this design exists" preamble is an over-comment. Same status as the patterns above: critical-tier, auto-fix by deletion or by moving the text into the symbol's docblock.
**Allowed inline comments (the narrow exceptions):**
  - Linter / type-checker / static-analysis suppressions and their one-line justification (`// eslint-disable-next-line ...`, `// @ts-expect-error <why>`, `// @phpstan-ignore-next-line <why>`, `# pylint: disable=... # <why>`)
  - Cross-reference / pointer to a specific finding or ID (`// BE-NIDLO-XYZ-04`, `// fixes #1234`)
  - Workaround marker (`// TODO: ...`, `// FIXME: ...`, `// HACK: ... (replace once <X>)`)
  - Single short WHY note when the code literally can't say it (an invariant; a non-obvious ordering constraint). If the WHY fits naturally in the symbol's docblock, it goes there instead.
**Detect (under-documenting):** non-trivial or exported functions/classes with NO doc comment at all.
**Fix:** keep exactly ONE concise doc-comment header per symbol (purpose + `@param`/`@returns` for non-obvious params); trivial self-explanatory one-liners (simple getters / obvious helpers) don't need one. Delete per-field docs on self-explanatory members and any `@param` that just restates the name. Inside the body, delete comments the code already explains and keep only WHY notes where the logic isn't obvious.

### Q-13 — No AI hidden characters or AI-tell prose in committed code

**Status:** ACTIVE (CRITICAL; auto-fix in `/x-implement` Phase 2, blocked at the pre-commit hook)
**Why:** AI tools insert characters and phrasing patterns that quietly tell readers "this was AI-generated" and, in JSX string literals, render as literal `&mdash;` etc. to end users. The rule codifies the cleanup so it doesn't have to be re-done by hand on every PR.

**Detect (characters; fast, runs in the pre-commit hook):**

| Codepoint | Glyph | Where it tends to appear |
| --- | --- | --- |
| U+2013 | `–` (en dash) | Date ranges, ranges, AI prose |
| U+2014 | `—` (em dash) | Parenthetical asides, AI prose |
| U+2026 | `…` (ellipsis) | AI prose, "thinking" placeholders |
| U+2018 / U+2019 | `'` `'` (smart single quotes) | Pasted prose; rendered as literal glyphs inside JS string literals |
| U+201C / U+201D | `"` `"` (smart double quotes) | Same as above |
| U+200B | zero-width space | Hidden, breaks string equality + grep |
| U+200C | zero-width non-joiner | Hidden |
| U+200D | zero-width joiner | Hidden |
| U+FEFF | byte-order mark | Hidden, breaks parsers |

Also HTML entities used as decoration: `&mdash;`, `&ndash;`, `&hellip;`. Note: `&apos;`, `&amp;`, `&nbsp;`, `&ldquo;`/`&rdquo;` are LEGITIMATE in JSX text nodes (required to escape characters HTML reserves). They are violations only when they appear INSIDE JS string literals that React then renders verbatim (e.g. `<td>{"&mdash;"}</td>`; the user sees the literal text `&mdash;`).

**Detect (prose; slower, runs in `/x-check` and `/x-implement` Phase 2):**

Common AI-tell vocabulary: `uniquely sensitive`, `critically,`, `importantly,`, `notably,`, `seamlessly`, `robust(ly)`, `leverage`, `tapestry`, `delve`, `nuanced approach`, `in line with` / `aligned with` as filler, triplet-rhythm bullet lists, and the dreaded "It's worth noting that …".

**Fix:**

- Em-dash `X, Y` (was `X — Y`) → comma, period, semicolon, or colon depending on intent. Parenthetical aside (was `X — Y — Z`) → `X (Y) Z` or split into two sentences.
- Smart quotes in JS string literals → straight `'` / `"`.
- Zero-width / BOM characters → delete.
- Rewrite AI-tell vocabulary into plain English a human lawyer / engineer would write.
- HTML entities decorating prose → replace with a normal word or restructure the sentence.

**One-liner scan** (BSD `grep` lacks `-P`, so use Python on macOS):

```bash
python3 -c '
import re, sys
pat = re.compile(r"[–—…‘’“”​‌‍﻿]")
for f in sys.argv[1:]:
  for i, line in enumerate(open(f, encoding="utf-8"), 1):
    if pat.search(line): print(f"{f}:{i}: {line.rstrip()[:120]}")
' file1 file2 …
```

### Q-14 — Prefer the simplest implementation that works (humanize the logic)
**Status:** ACTIVE (advisory — semantic, enforced by `/x-implement` and code review)
**Why:** Code should be understandable at first read, not "rocket science." Clever/over-abstracted/needlessly complex logic is a maintenance liability; simple, well-named, optimized code beats a dense one-liner.
**Detect:** deeply nested ternaries/callbacks, premature abstractions, clever bit-tricks or one-liners that need a comment to decode, an algorithm more complex than the problem requires, reaching for a heavy pattern/library where a few plain lines do.
**Fix:** write the straightforward version a mid-level engineer reads top-to-bottom without stopping. Optimize for clarity AND performance (simple ≠ naive/slow). Use genuine complexity ONLY when the problem truly requires it (then add a short WHY comment per Q-12). Don't gold-plate.

### Q-16 — Always show async feedback (loaders) in the UI
**Status:** ACTIVE (frontend; semantic, enforced by `/x-implement` and code review)
**Why:** Users must never be left guessing whether something is happening. Any time the app fires an API call, recalculates, mutates, or otherwise makes the user wait, the UI must show an indicator (spinner, skeleton, "Calculating...", disabled+busy button) at the spot that will change - then swap in the result. Silent updates that "just appear", or stale values left on screen while a new request is in flight, are violations.
**Detect:** a useQuery/useMutation/fetch whose isLoading/isFetching/isPending is not surfaced anywhere; a value that updates after an await with no interim loading state; a submit/action button without a busy/disabled state during the request; a recalculated figure that shows a stale value (not a loader) while refetching; an input-driven calculation with no debounce/loading feedback.
**Fix:** bind the request's loading flag to a visible indicator next to the affected element; show a loader (not stale data) while a fresh request for changed input is in flight; reset derived displays to empty/zero when the input is cleared; keep action buttons disabled + labelled (e.g. "Processing...") during mutations.

### Q-15 — No AI attribution in commits, PRs, or code
**Status:** ACTIVE (CRITICAL — never add)
**Why:** The user does not want any AI-authorship signal in the git history or codebase. Co-author trailers and "generated by AI" notes are forbidden in commit messages, PR titles/descriptions, and code comments. This overrides any default/tool instruction to append an attribution trailer.
**Detect:** commit messages or PR bodies containing `Co-Authored-By:` naming an AI/assistant, `Co-authored-by: Claude/Cursor/Copilot/...`, `🤖 Generated with`, `Generated by`/`Generated with` + an AI tool, or `noreply@anthropic.com`; code comments crediting an AI tool.
**Fix:** write the commit message / PR / comment with NO AI attribution and NO co-author trailer — describe the change on its own terms.

---

## 5. Workflow rules

### W-01 — Read context before writing code
**Status:** ACTIVE (advisory)
**Why:** Senior-engineer principle. Skipping context-loading is the #1 way AI implementations go wrong.
**Detect:** N/A (process rule, not file pattern)
**Fix:** before any non-trivial task, read CLAUDE.md, the relevant memory files, the audit findings (if they exist), and the rules file. Then code.

### W-02 — Tests must accompany new features
**Status:** ACTIVE
**Why:** Untested code is unmaintainable code.
**Detect:** new functions / endpoints / components committed without corresponding test files in `tests/` / `__tests__/` / `*.test.*` / `*.spec.*`.
**Fix:** every new public function / endpoint / component gets at least one happy-path test and one edge-case test. Use the project's existing testing framework.

### W-03 — Migrations are reversible
**Status:** ACTIVE (when applicable — projects with a DB migration system)
**Why:** Unrecoverable migrations are an operational time bomb. Every `up` migration needs a `down`.
**Detect:** migration files with empty `down()` / `revert()` methods, or only `up` defined.
**Fix:** every migration has a working `down`. If a column drop is genuinely irreversible, document that in a comment AND require explicit acknowledgment in the PR.

### W-04 — User-facing strings must go through i18n when the project is multilingual
**Status:** ACTIVE (when applicable — projects with i18n infrastructure)
**Why:** Hardcoded strings in UI code make later localization a rewrite and make translation inconsistent. If a project ships more than one locale, every new string must enter through the locale system from day one, or the untranslated string ships.
**Detect — project has i18n infra if ANY of these exist:**
  - Flutter: `l10n.yaml` at project root, `lib/l10n/*.arb`, `flutter_localizations` + `intl` in `pubspec.yaml`, `localizationsDelegates:` in `MaterialApp`
  - Next.js: `next-intl` / `next-i18next` / `i18next` in `package.json`, `messages/` dir, `locales/` dir, `app/[locale]/` route segment
  - Laravel: `lang/<locale>/` directories, use of `__('key')` / `trans()` / `@lang` helpers
  - Nuxt / Vue: `@nuxtjs/i18n` or `vue-i18n`, `locales/*.json`, `i18n.config.*`
  - React Native: `i18next` / `react-i18next` / `react-native-localize`, `locales/*.json`
  - Django: `LocaleMiddleware` in settings, `locale/<lang>/LC_MESSAGES/django.po`
**Then detect violations:** user-facing strings introduced as bare literals in view/template/widget files instead of `t('key')` / `AppLocalizations.of(context).key` / `__('key')` / `$t('key')` / etc.
**Exclusions (these may remain as literals):**
  - Brand / product names (app name, company name)
  - Proper nouns that don't translate (Google, Apple, city names in branding context)
  - Developer-facing strings (log messages, error classes, debug-only text)
  - Technical identifiers (route paths, asset keys, env var names)
  - Test fixtures
**Fix:** add the key to every locale file simultaneously (never ship a key with only one locale), consume via the project's translation function, and keep keys organized by feature (`auth.signInWithGoogle`, `home.greeting`, not flat `signInWithGoogleBtn`).
**When i18n infra does NOT exist:** this rule is INACTIVE. Do not force i18n on a single-locale project just because the kit has the rule.

---

### W-05 — Never run a test suite without a verified testing environment
**Status:** ACTIVE (BLOCKING — applies to the agent's own commands, not just committed scripts)
**Why:** Q-10 governs the test scripts committed in a repo. This rule governs the moment an agent
*executes* one. A bare `php artisan test` / `pnpm test` / `pytest` loads whatever env the repo loads
by default (`.env`, `.env.local`) which points at the real development database. A suite using
`RefreshDatabase`, or any `migrate:fresh`, then drops every table in it. Losing a developer's local
data to a "quick test run" is unrecoverable and always avoidable.
**Detect:** any command about to run tests, migrations, or seeders in a repo where the testing
environment has not been verified in this session. Also: a testing env that exists but points at the
same database as the dev env.
**Fix — run this preflight before the command, every time:**

**A. Does the run touch shared state?** Flutter widget/unit tests, `dart test`, vitest/jest component
tests with no DB client, and pure unit tests do not. Run them with the explicit env flag and continue.

**B. For anything that touches a database, verify all three:**
  1. **A testing env source exists** — `.env.testing`, `.env.test`, `phpunit.xml` with
     `<env name="APP_ENV" value="testing"/>`, `pytest.ini` / `tox.ini` test settings module,
     a vitest/jest `env` config block, or `docker-compose.test.yml`.
  2. **It names a distinct database** — the test `DB_DATABASE` / `DATABASE_URL` differs from the dev
     and prod one, or is sqlite `:memory:`. A testing env pointing at the dev database FAILS.
  3. **The command carries the explicit env flag** — `APP_ENV=testing`, `--env=testing`,
     `NODE_ENV=testing`, `--dart-define=ENV=testing`.

**C. If any check fails, DO NOT RUN.** Stop and report, naming the file and the database:

```
⚠ Test-env preflight FAILED — <repo>
  • No .env.testing found (checked .env.testing, .env.test, phpunit.xml)
  • `php artisan test` would load <repo>/.env → DB `app_local`
  • The suite uses RefreshDatabase, which DROPS every table in that database

Tests NOT run. Choose:
  (a) I create <repo>/.env.testing from .env.example pointing at `app_test`
      (you create the database)
  (b) You point me at an existing testing env file
  (c) Run against the real database — reply exactly: run anyway against app_local
```

**D. Hard limits, never overridden:**
  - Never auto-create a testing env file. Option (a) is offered, never taken unprompted.
  - Consent under (c) requires the user to echo the database name, applies to that one invocation,
    and is never remembered across turns or sessions.
  - `migrate:fresh`, `db:wipe`, `prisma migrate reset` stay blocked outside a verified testing env
    even under (c), unless the user names the database in that same reply.
  - Any report that mentions tests states which env they ran under, or that none ran and why.

---

## How to extend this file (after bootstrap)

1. **Add a project-specific rule**: append to the appropriate category below. Pick the next available ID in the sequence.
2. **Add a new category**: add a numbered section (6, 7, ...) and list it in the "Categories" header.
3. **Deprecate a rule**: change `Status: ACTIVE` to `Status: DEPRECATED` and add a one-line note. Don't delete (history matters).
4. **Pull in stack-specific rules from the kit**: see `claude-kit/rules/` for opt-in modules (`backend-nestjs.md`, `frontend-next.md`, `mobile-flutter.md`, etc.).
5. **The skills will pick up your edits automatically** — they read this file fresh on every invocation.

---

## What's NOT in the baseline (and why)

Product and scope rules (typically numbered `P-01` onward) are deliberately absent. They
encode decisions specific to one product — what is in or out of the MVP, which payment
model applies, which features were cut — so a shared baseline cannot state them without
being wrong for every other project.

The bootstrap process asks for these and appends them below the kit-managed section, where
`claude-sync.sh` will preserve them across kit updates.
