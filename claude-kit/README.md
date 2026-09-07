# Claude Kit — Portable AI development system

**Version:** 1.0
**Author:** Solomon Darku (Snad)
**Built:** 2026-04-09 → 2026-04-10
**Origin:** Extracted from the XLent Choice project's Claude Code setup

---

## What is this?

A reusable toolkit that bootstraps **any project** with:

| Component | What it does |
|---|---|
| **6 skills** (`/x-implement`, `/x-prompt`, `/x-rules`, `/x-check`, `/x-check-file`, `/x-add-rule`) | Slash commands for planning, implementing, auditing, and managing rules |
| **80+ rules** (baseline + stack modules) | Enforced code quality, security, auth, and workflow rules |
| **Pre-commit hook** (L3) | Pure bash, millisecond checks, blocks commits with critical violations |
| **GitHub Actions workflow** (L4) | Same checks on every PR/push, posts violation comments |
| **CLAUDE.md template** | Project anchor file generated per-project |
| **Memory file templates** | Per-project memory for seniority context, project scope, features, vendors, audits |
| **Audit prompt template** | Parameterized deep-audit prompt that runs file-by-file on any stack |
| **BOOTSTRAP.md** | Master orchestration prompt that Claude follows to set everything up |

Originally built for the XLent Choice project (NestJS + Next.js + Flutter), now portable to **any stack**.

---

## Quick start

### Option A: Fully conversational (recommended)

```
cd /path/to/your/project
# Open Claude Code, then type:
@/Users/mac/Projects/.ai/claude-kit/BOOTSTRAP.md please bootstrap this project
```

Claude will:
1. Detect your stack (Node, PHP, Python, Flutter, etc.)
2. Ask you about the project scope and context
3. Audit every source file, line-by-line
4. Install skills + rules + scripts + workflow
5. Generate CLAUDE.md
6. Set up memory files
7. Install pre-commit hook
8. Stage the GitHub Actions workflow

### Option B: Script first, Claude second

```
bash /Users/mac/Projects/.ai/claude-kit/claude-init.sh /path/to/your/project
```

This does the mechanical file copies instantly. Then open Claude Code in the project and reference `@BOOTSTRAP.md` to finish the conversational steps (audits, CLAUDE.md, memory).

---

## Stack support

### Rule modules included (auto-detected)

| Stack | Module | Key rules |
|---|---|---|
| **NestJS / TypeScript** | `rules/backend-nestjs.md` | DTOs, transactions, no raw SQL, cron locking, permission guards |
| **Laravel / PHP** | `rules/backend-laravel.md` | Form Requests, N+1 prevention, mass assignment, Policies, queue idempotency |
| **Django / Python** | `rules/backend-django.md` | Serializers, select_related, permission_classes, Celery idempotency |
| **Next.js / React** | `rules/frontend-next.md` | Real data (no mocks), TanStack Query, error boundaries, `'use client'` discipline, `next/image` |
| **React (Vite/CRA)** | `rules/frontend-react.md` | Data fetching, error boundaries, memoization, stable list keys |
| **Vue 3** | `rules/frontend-vue.md` | Composition API, Pinia, VeeValidate, reactive patterns, `v-html` sanitization |
| **Nuxt 3** | `rules/frontend-nuxt.md` | `useFetch`/`useAsyncData`, server routes auth, `useState` SSR safety, `useRuntimeConfig` |
| **Flutter / Dart** | `rules/mobile-flutter.md` | Loading states, Riverpod select, const constructors, secure storage, upload await |
| **React Native** | `rules/mobile-react-native.md` | SecureStore, FlatList, memoization, image caching, permission manifests |

**Need another stack?** Add a `rules/<stack>.md` file following the same format. The `claude-init.sh` will pick it up if the detection logic matches.

### Universal baseline (always included)

`rules/rules-baseline.md` — 40+ rules covering:
- Auth & Authorization (A-01 through A-07)
- Security (S-01 through S-13)
- Data & Privacy (D-01 through D-05)
- Code Quality (Q-01 through Q-12)
- Workflow (W-01 through W-03)

---

## Folder layout

```
/Users/mac/Projects/.ai/
├── PROMPT_GENERATOR.md              ← The original prompt generator (pre-existing)
└── claude-kit/
    ├── README.md                    ← You are here
    ├── BOOTSTRAP.md                 ← Master orchestration prompt (Claude follows this)
    ├── claude-init.sh               ← One-shot file installer (mechanical step)
    │
    ├── rules/                       ← Rule modules
    │   ├── rules-baseline.md        ← Universal baseline (always included)
    │   ├── backend-nestjs.md
    │   ├── backend-laravel.md
    │   ├── backend-django.md
    │   ├── frontend-next.md
    │   ├── frontend-react.md
    │   ├── frontend-vue.md
    │   ├── frontend-nuxt.md
    │   ├── mobile-flutter.md
    │   └── mobile-react-native.md
    │
    ├── skills/                      ← Portable skill templates (with {{placeholders}})
    │   ├── x-implement/SKILL.md     ← Canonical 3-phase work command
    │   ├── x-prompt/SKILL.md        ← Plan-only alias
    │   ├── x-rules/SKILL.md
    │   ├── x-check/SKILL.md
    │   ├── x-check-file/SKILL.md
    │   └── x-add-rule/SKILL.md
    │
    ├── scripts/                     ← Portable bash scripts (with {{placeholders}})
    │   ├── x-precommit.sh           ← Pre-commit hook (L3 + L4 shared)
    │   ├── install-hooks.sh         ← Deploy hook into .git/hooks/
    │   └── install-workflows.sh     ← Deploy workflow + script into .github/
    │
    ├── workflows/
    │   └── x-check.yml              ← GitHub Actions workflow template
    │
    └── templates/                   ← Document templates (with {{placeholders}})
        ├── CLAUDE.md.template       ← Project anchor
        ├── audit-prompt.md          ← Parameterized audit agent prompt
        ├── memory-files-template.md ← Memory file creation guide
        └── feedback_seniority_and_workflow.md  ← Seniority + workflow operating mode
```

---

## Maintaining the kit

### Adding a new rule to the baseline
1. Edit `rules/rules-baseline.md`
2. All future bootstraps will include it
3. Existing projects need manual copy (or re-bootstrap)

### Adding a new stack module
1. Create `rules/<stack-name>.md` following the format of existing modules
2. Add detection logic to `claude-init.sh` in the `detect_stacks()` function
3. Add the module to the "Stack support" table in this README

### Adding a new skill
1. Create `skills/<skill-name>/SKILL.md`
2. Use `{{PROJECT_ROOT}}`, `{{PROJECT_NAME}}`, `{{MEMORY_ROOT}}` placeholders for paths
3. `claude-init.sh` will auto-copy it on next bootstrap

### Updating BOOTSTRAP.md
If you change the bootstrap process (e.g. add a Phase 8), update the instructions in `BOOTSTRAP.md`.

### Updating the pre-commit hook
1. Edit `scripts/x-precommit.sh` to add/modify `scan_pattern` lines
2. All future bootstraps will include the updated patterns
3. For existing projects: `bash <project>/.claude/scripts/install-hooks.sh all --force`

---

## How this was built

This kit was extracted from the XLent Choice project's Claude Code setup, which was built over a multi-hour session:

1. **Cloned 3 repos** (NestJS backend, Next.js admin dashboard, Flutter mobile app)
2. **Audited every file** line-by-line across all 305 source files — 240+ findings
3. **Read 4 client PDFs** + 6 spec MDs (14,000+ lines of spec documentation)
4. **Extracted specs** into 7 structured MDs with file:line links cross-referencing the audits
5. **Resolved 12+ outstanding product questions** with the dev lead (Snad)
6. **Built 80 enforced rules** across 9 categories, derived from the audits + specs + confirmed decisions
7. **Built 6 Claude Code skills** (slash commands) for planning, implementing, auditing, and rule management
8. **Built a 4-layer enforcement system** (L1 LLM self-check, L2 LLM sweep, L3 bash pre-commit hook, L4 GitHub Actions CI)
9. **Merged the skills** into a 3-phase canonical work command with opinionated ambiguity scoring + scope-lock contract
10. **Portabilized** everything into this kit with placeholder substitution, stack modules, and a conversational bootstrap process

---

**License:** MIT — use freely in any project
