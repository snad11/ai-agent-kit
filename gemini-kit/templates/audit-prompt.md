# Audit prompt template

**Use this template when launching a deep audit agent on a single repo during the bootstrap process.** It scales to a full codebase — hundreds of source files, hundreds of findings, a structured markdown document per module.

The template is parameterized — substitute the placeholders for the specific repo + stack you're auditing.

---

## Placeholders to substitute

- `{{REPO_NAME}}` — short name like `backend`, `admin-dashboard`, `mobile`
- `{{REPO_PATH}}` — absolute path to the repo, e.g. `<projects-dir>/myapp/backend`
- `{{STACK_DESCRIPTION}}` — e.g. "NestJS + Drizzle + TypeScript", "Laravel 11 + Eloquent + PHP 8.3", "Flutter + Riverpod + Dart 3.5"
- `{{SOURCE_COUNT}}` — number of source files in the main folder (run `find <src-dir> -type f | wc -l`)
- `{{SOURCE_DIR}}` — main source directory like `src`, `app`, `lib`
- `{{TEST_DIR}}` — test directory like `test`, `tests`, `__tests__`, `spec`
- `{{AUDIT_OUTPUT_PATH}}` — `<project-root>/audits/{{REPO_NAME}}/`
- `{{KEY_CONFIG_FILES}}` — comma-separated list of config files Claude should read first (e.g. `package.json, tsconfig.json, drizzle.config.ts, docker-compose.yml`)
- `{{TOP_FOLDER_TYPE}}` — what to call the top-level grouping (`module` for backend, `section` for frontend, `feature` for mobile)

---

## The prompt itself

Copy the block below into a `general-purpose` agent invocation. Replace placeholders before sending.

```
You are auditing the **{{REPO_NAME}}** repo at `{{REPO_PATH}}`. Stack: {{STACK_DESCRIPTION}}. Source file count: ~{{SOURCE_COUNT}} in `{{SOURCE_DIR}}/`.

The user wants a *vivid, file-by-file, function-by-function* audit. You have full Write tool access — you MUST write the audit as a structured set of markdown files into `{{AUDIT_OUTPUT_PATH}}` (the directory already exists). Do NOT just summarize in your final response; the deliverable is the markdown files on disk.

## What to produce (write each as a separate file)

1. **`{{AUDIT_OUTPUT_PATH}}/00_OVERVIEW.md`** — high-level summary:
   - Stack (versions, key dependencies — read package.json / pubspec.yaml / composer.json / etc.)
   - Top-level folder layout under `{{SOURCE_DIR}}/` with one-line descriptions
   - Entry points and bootstrap flow
   - List of all top-level {{TOP_FOLDER_TYPE}}s discovered
   - Environment variables required (read .env.example / example.env)
   - Docker / dev setup (Dockerfile, docker-compose.yml if present)
   - DB / ORM config (if applicable)
   - A "{{TOP_FOLDER_TYPE}}s index" table linking to the per-{{TOP_FOLDER_TYPE}} audit files below

2. **`{{AUDIT_OUTPUT_PATH}}/01_ARCHITECTURE.md`** — architectural notes:
   - Request lifecycle / data flow / component tree (whichever applies to the stack)
   - Auth strategy (JWT? sessions? OAuth?)
   - Data access patterns (ORM, query builder, raw SQL, repositories)
   - Cross-cutting concerns (logging, error handling, validation, rate limiting)
   - External integrations (third-party APIs, queues, storage, push notifications)

3. **One file per top-level {{TOP_FOLDER_TYPE}} under `{{SOURCE_DIR}}/`** named `{{TOP_FOLDER_TYPE}}_<name>.md`. For each:
   - Path
   - Purpose
   - List **every file** in the {{TOP_FOLDER_TYPE}} with: path, purpose, exported symbols
   - For each controller/route/component: list every endpoint/route/prop with type and description
   - For each service/repository/store: list every public method with signature and a 1–2 line description
   - For each model/entity/schema/DTO: fields, types, validation rules
   - Dependencies (which other {{TOP_FOLDER_TYPE}}s it imports from)
   - Database tables it touches (if backend)
   - **Findings**: bugs, smells, security concerns, missing validation, N+1 issues, missing tests, TODOs, dead code, hardcoded secrets, anything notable
   - **Performance / Web Vitals** (for frontend files): LCP element hidden behind `opacity:0` entrance; loading/skeleton states with no contentful element (FCP); above-the-fold image without priority / undimensioned images (LCP/CLS); heavy or disabled-feature dependencies eagerly imported into the root/shared bundle; heavy synchronous interaction handlers / large unmemoized re-renders (INP); content injected above existing content or skeleton/content size mismatch (CLS); uncached per-request SSR fetches or routes needlessly dynamic (TTFB)

4. **`{{AUDIT_OUTPUT_PATH}}/99_FINDINGS.md`** — consolidated findings, ordered by severity:
   - Critical bugs / security issues
   - High-priority improvements
   - Medium-priority cleanup
   - Performance / Web Vitals issues (LCP, FCP, INP, CLS, TTFB, bundle size — frontend repos)
   - Missing features / TODOs
   - Test coverage gaps (look at `{{TEST_DIR}}/`)
   - Each finding should reference file paths and line numbers using markdown links like `[file.ts:42](../../{{REPO_NAME}}/{{SOURCE_DIR}}/file.ts#L42)`

## How to do the audit

- Read these config files first: {{KEY_CONFIG_FILES}}
- Then read the entry point ({{SOURCE_DIR}}/main.* or equivalent)
- Then walk `{{SOURCE_DIR}}/` directory by directory and read **every** file
- Use Glob to enumerate files; use Read to actually read them
- Be exhaustive — line-by-line / function-by-function coverage. Don't skip "boring" files (interfaces, constants, DTOs) — list them.
- For very large files, read them in full
- Use markdown link format `[name](../../{{REPO_NAME}}/{{SOURCE_DIR}}/...#L<line>)` for every code reference

## Guidelines

- Be specific and concrete — include real method names, real route paths, real schema field names. No vague hand-waving.
- Don't hallucinate; if you can't determine something, say "unclear — needs verification"
- Findings must be actionable ("missing input validation on email field" ✓, "could be better" ✗)
- When you spot a security issue (SQLi, missing auth guard, secret in code, weak crypto), call it out clearly in the relevant {{TOP_FOLDER_TYPE}} file AND in 99_FINDINGS.md
- Use h2/h3 headings, tables, and bullet lists for scannability
- Split a {{TOP_FOLDER_TYPE}} file if it gets very long (>500 lines)

**Confirm the files exist on disk before finishing.** When done, return a brief summary (under 300 words) listing: which MD files you created (with paths), total source files audited, and the top 5 most critical findings across the codebase.
```

---

## How to use this template programmatically

In `BOOTSTRAP.md`, the bootstrap process loops over each detected repo and:

1. Creates the audit output directory: `mkdir -p audits/<repo>/`
2. Substitutes the placeholders for that repo
3. Launches a `general-purpose` agent in the background with the substituted prompt
4. Waits for completion (or runs all 3 in parallel if there are 3 repos)
5. After completion, writes a top-level `audits/README.md` cross-referencing all repo audits

The same pattern works for any stack — only the placeholders change.

---

## Stack hints (what `{{TOP_FOLDER_TYPE}}` should be)

| Stack | TOP_FOLDER_TYPE |
|---|---|
| NestJS / Express / Fastify (backend) | `module` |
| Laravel (backend) | `feature` (or `module` if using Laravel modules) |
| Django (backend) | `app` (Django's term) |
| Next.js / Nuxt / SvelteKit | `section` (groups: `app`, `components`, `lib`, `hooks`, etc.) |
| React / Vue / generic SPA | `section` |
| Flutter | `feature` (groups under `lib/`) |
| React Native | `feature` (groups under `src/`) |
