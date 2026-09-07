# BOOTSTRAP — Replicate the Agent Kit in any project (multi-agent)

**Master orchestration prompt for setting up a new project with the same skills + rules + audit + memory system across **any** AI agent (ZCode, Codex, Cursor, Claude Code, and any tool that reads `AGENTS.md`).** Generalized from `claude-kit/BOOTSTRAP.md`; the only material difference is target-awareness and that memory is cloned into `AGENTS.md` so non-Claude agents see it.

## How to use this file

In any project (existing codebase or fresh empty folder), open your agent and reference this file:

```
@/Users/mac/Projects/.ai/agent-kit/BOOTSTRAP.md please bootstrap this project
```

or run the mechanical installer first, then the conversational phases:

```
bash /Users/mac/Projects/.ai/agent-kit/agent-init.sh . --target all
```

The bootstrap is **conversational** — the agent asks questions, you answer, and at the end the project has the full system installed for whichever target(s) you chose.

---

## Instructions for the agent (read this entire file before doing anything)

You are bootstrapping a new project with the Agent Kit. This is a multi-phase process. Do not skip phases. Do not auto-answer questions on the user's behalf. Be senior-engineer-level deliberate.

### Phase 0 — Confirm what we're doing

Before any file operations:

1. **State your understanding**: "I'm going to bootstrap this project with the Agent Kit for target `<T>`. That means: (a) detect what's here, (b) audit each detected repo, (c) install skills + rules + scripts + workflow into the target agent dir(s), (d) create/refresh `AGENTS.md` (and `CLAUDE.md` if claude/all), (e) set up memory and clone it into the anchor, (f) install the git pre-commit hook + stage the GitHub Actions workflow. This will take a while — the audit phase alone runs LLM-based analysis on every source file."
2. **Ask the user to confirm** the project's working directory. Run `pwd`. Ask: "Bootstrapping into `<pwd>`? If you meant a different folder, cd there first and re-invoke."
3. **Confirm the target**: `agents` (default; AGENTS.md + .agents/), `zcode` (+ .zcode/), `claude` (CLAUDE.md + .claude/), or `all`. If the user already passed `--target` to the installer, reuse it.
4. **Wait for explicit confirmation** before proceeding.

### Phase 1 — Discover the project

Goal: figure out what's in this folder. Don't assume monorepo, don't assume single-stack.

1. Run `ls -la`.
2. Look for markers: `package.json` (Node — distinguish Next.js/NestJS/generic), `pubspec.yaml` (Flutter), `composer.json`+`artisan` (Laravel), `manage.py` (Django), `fastapi` in pyproject/requirements (FastAPI), `go.mod`, `Cargo.toml`, `Gemfile`, `pom.xml`/`build.gradle`.
3. For each detected repo, identify: path, stack (the framework, not just the language), source dir, test dir, source file count, existing CI (`.github/workflows/`), existing precommit hook.
4. **Present the discovered repos** as a table (Path | Stack | Source files | CI? | Hook?).
5. **Ask the user**: missed any repos? Any to ignore? Primary working branch? Dev-lead name for the anchor?
6. Wait for answers.

### Phase 2 — Gather project context

Don't skip. The audit + rules + memory all need this. **One question at a time:**

1. **Project name** (default: folder name).
2. **One-paragraph description** — what is it, who uses it, what problem it solves.
3. **Phase / state** — MVP, post-launch, mature, greenfield? Any "Phase 2" features excluded from MVP rules?
4. **Spec docs** — any client/product docs (PDF, MD, Notion exports)? Where? Confidential?
5. **Vendors / infra** — DB, hosting, auth, payments, email, SMS, push, monitoring? Live vs TODO?
6. **Known issues / amendments** — anything that looks like best practice but is intentionally NOT being implemented?

Save answers to memory as you collect them (Phase 5 consolidates).

### Phase 3 — Run the audit

For each detected repo, launch a `general-purpose` agent (background, parallel if multiple) using the audit prompt template at `<project>/.agents/templates/audit-prompt.md`.

1. `mkdir -p audits/<repo>/`
2. Read the audit prompt template.
3. Substitute placeholders per repo (REPO_NAME, REPO_PATH, STACK_DESCRIPTION, SOURCE_COUNT, SOURCE_DIR, TEST_DIR, AUDIT_OUTPUT_PATH, KEY_CONFIG_FILES, TOP_FOLDER_TYPE).
4. Launch a `general-purpose` agent (**not** a read-only Explore agent — it can't write files) in the background.
5. Tell the user audits are running; continue with Phases 4-6 in parallel.
6. **Do not wait** — audits take 10-20 min per repo.

### Phase 4 — Install skills + scripts + workflow (if not already done by agent-init.sh)

If `agent-init.sh` already ran, the files are in place; this phase reduces to verifying and authoring `CLAUDE.md` for claude/all targets. Otherwise:

```bash
bash /Users/mac/Projects/.ai/agent-kit/agent-init.sh <project-root> --target <T>
```

Then, for **claude/all** targets only, generate `CLAUDE.md` from `agent-kit/templates/CLAUDE.md.template`, substituting `{{PROJECT_NAME}}`, `{{PROJECT_DESCRIPTION}}`, `{{REPOS_TABLE}}`, `{{DEV_LEAD_NAME}}`, `{{DEV_BRANCH}}`, `{{MEMORY_PROJECT_KEY}}`, `{{BOOTSTRAP_DATE}}`, `{{PROJECT_STATE_NOTES}}`, `{{PROJECT_DONT_LIST}}`. (`AGENTS.md` is already generated by the installer; `CLAUDE.md` mirrors it for Claude Code, which auto-loads `CLAUDE.md` specifically.)

### Phase 5 — Set up memory + clone into the anchor

1. Memory path: `~/.agents/projects/<memory-key>/memory/` where `<memory-key>` = project absolute path with `/` replaced by `-`. (For claude/all, also mirror under `~/.claude/projects/<key>/memory/` so Claude auto-loads it.)
2. `mkdir -p` the memory folder.
3. Author the memory files from Phase 2 answers: `MEMORY.md` (index), `project_scope.md`, `project_features.md`, `project_vendors.md`, `reference_docs.md` (if specs exist), `reference_commands.md` (from the commands template, paths substituted), `feedback_confidentiality.md` (only if specs are confidential). The seniority template was already seeded by `agent-init.sh`.
4. **Clone every memory file verbatim into `AGENTS.md`** via `bash <project>/.agents/scripts/clone-memory.sh <project>/AGENTS.md <memory-dir>`. This is the key generalization: non-Claude agents don't auto-load memory, so it must be in-context.
5. Ask the user: "Anything else to save to memory before we move on?"

### Phase 6 — Install hooks + workflows

1. `bash <project>/.agents/scripts/install-hooks.sh all`
2. `bash <project>/.agents/scripts/install-workflows.sh all` (stages `.github/` files, does NOT commit)
3. Tell the user hooks are installed and CI is staged; they must commit + push for CI to go live. Do not commit without explicit confirmation.

### Phase 7 — Wait for audits + finalize

1. Wait for the background audit agents to complete.
2. Write `audits/README.md` cross-referencing each repo's audit.
3. Update `<memory-dir>/project_audits.md` with a high-level summary (top 5 critical per repo, cross-cutting themes).
4. **Re-run the memory clone** so the new `project_audits.md` appears in `AGENTS.md`.
5. **Final report** (files created, hooks installed, CI staged, next steps, audit highlights).
6. Append `**Bootstrapped:** <date> (target: <T>)` to `MEMORY.md`.

#### Required outcomes

Every item is observable. The bootstrap isn't done until each is true. Verify, don't assume.

- [ ] The user explicitly confirmed the working directory in Phase 0
- [ ] Every Phase 2 question was asked ONE at a time, and every answer is in the memory folder
- [ ] `rules.md` exists, ends with the sentinel `<!-- kit-managed above — project rules below -->`, and its rule count is greater than the baseline's
- [ ] Every detected stack has its rules module appended, and every appended module matches a stack that actually exists in the project
- [ ] All 7 skills are present under the target's skills dir and contain no literal `{{TOKEN}}` text
- [ ] The anchor file (`AGENTS.md` and/or `CLAUDE.md`) exists and carries the cloned memory block
- [ ] The pre-commit hook is installed AND was smoke-tested against one staged file
- [ ] `x-check.yml` is staged alongside existing workflows, not over them
- [ ] The plan-mode hook is registered for every active target
- [ ] `audits/<repo>/` holds one line-by-line audit per detected repo, or the skip reason is stated
- [ ] Nothing was committed, and no source file was modified

---

## Constraints (hard rules)

- **Do not skip Phase 0 (confirm)** or **Phase 2 (context)**. The user must explicitly say "yes, bootstrap".
- **Do not auto-detect stack incorrectly.** If unsure React vs Next.js, ASK.
- **Do not commit anything.** The bootstrap stages files; the user commits.
- **Do not modify source code** in existing repos. Writes are confined to `.agents/` (and `.zcode/`/`.claude/` for those targets), `AGENTS.md`/`CLAUDE.md`, `audits/`, and the memory folder.
- **Do not use a read-only/Explore agent for the audit** — it can't write the audit MDs. Use `general-purpose`.
- **Do ask one question at a time** in Phase 2.
- **Do run audits in the background** and continue Phases 4-6 in parallel.
- **Do use the kit's templates** — don't reinvent the rules file or anchor format.
- **Do clone memory into `AGENTS.md`** (Phase 5) — that's the whole point of the multi-agent kit.
- **Do save user answers to memory immediately** as collected in Phase 2.
- **Do not overwrite an existing `rules.md` that has no sentinel.** Its project rules live above the line the sync preserves, so a rebuild discards them. Run `scripts/repair-sentinel.sh <project>` first, read the report, then sync.
- **Do not delete the in-project `rules.md.bak-<ts>`** a repair or sync writes. For a project without git it is the only rollback.

---

## Non-web projects

- **Library / package** — skip the audit. Still install rules + skills + hooks.
- **Desktop (Electron/Tauri)** — renderer = frontend, main = backend.
- **CLI tool** — treat as backend.
- **Docs / static site** — install rules + skills, skip audit and precommit hook.
- **Mixed monorepo** — bootstrap as one project with multiple repos; audit each app, skip libs/docs.

If a stack has no rules module in the kit, tell the user: "No module for `<stack>` — using the universal baseline only. Add one later by editing `rules.md` or contributing to `agent-kit/rules/`."

---

## What this bootstrap does NOT do

Commit, push, modify source code, run tests, install deps, configure linters/formatters, generate product features, or modify existing CI (it stages a new `x-check.yml` alongside any existing workflows).

---

## After bootstrap — extending the system

- **Add a rule**: edit `<project>/.agents/rules.md` (or `/x-add-rule`).
- **Add a skill**: drop `<name>/SKILL.md` in `<project>/.agents/skills/`.
- **Update the precommit hook**: edit `.agents/scripts/x-precommit.sh`, re-run `install-hooks.sh all --force`.
- **Update CI**: edit `.agents/workflows/x-check.yml`, re-run `install-workflows.sh all --force`.
- **Propagate kit updates**: `bash agent-kit/agent-sync.sh <project>` re-syncs skills/rules/templates and re-clones memory, preserving project-added rules below the sentinel.
- **Update the kit itself**: edit `agent-kit/rules/rules-baseline.md` or stack modules; future bootstraps get them; existing projects run `agent-sync.sh`.

---

## Recovery

Mostly idempotent. If a phase fails: Phases 1-2 just re-ask; Phase 3 restart the affected repo's audit; Phase 4 re-run with `FORCE=1`; Phase 5 delete the memory folder and re-run Phase 5; Phase 6 re-run the idempotent installers. Nuclear option: delete `.agents/`, `.zcode/`/`.claude/` (if those targets), `AGENTS.md`/`CLAUDE.md`, `audits/`, and the memory folder, then start over.

---

**Kit version:** 1.1
**Last updated:** 2026-07-25
