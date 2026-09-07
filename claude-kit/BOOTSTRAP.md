# BOOTSTRAP — Replicate the Claude Kit in any project

**This is the master orchestration prompt for setting up a new project with the same skills + rules + audit + memory system across all your projects (originally extracted from a reference project).**

## How to use this file

In any project (whether it's an existing codebase or a fresh empty folder), open Claude Code and reference this file. Three ways:

```
@/Users/mac/Projects/.ai/claude-kit/BOOTSTRAP.md please bootstrap this project
```

or

```
@/Users/mac/Projects/.ai/claude-kit/BOOTSTRAP.md
```

(then ask Claude to follow the instructions)

or run the helper script directly:

```
bash /Users/mac/Projects/.ai/claude-kit/claude-init.sh
```

The bootstrap is **conversational** — Claude will ask questions, you answer, and at the end the project has the full system installed.

---

## Instructions for Claude (read this entire file before doing anything)

You are bootstrapping a new project with the Claude Kit. This is a multi-phase process. Do not skip phases. Do not auto-answer questions on the user's behalf. Be senior-engineer-level deliberate.

### Phase 0 — Confirm what we're doing

Before any file operations:

1. **State your understanding**: "I'm going to bootstrap this project with the Claude Kit. That means: (a) detect what's in this project, (b) audit each detected repo, (c) install skills + rules + scripts + workflow into `.claude/`, (d) create CLAUDE.md, (e) set up memory files, (f) install git pre-commit hook + GitHub Actions workflow. This will take a while — the audit phase alone runs LLM-based analysis on every source file."
2. **Ask the user to confirm** the project's working directory. Run `pwd` to show it. Ask: "Bootstrapping into `<pwd>`? If you meant a different folder, cd there first and re-invoke."
3. **Wait for explicit confirmation** before proceeding.

### Phase 1 — Discover the project

Goal: figure out what's in this folder. Don't assume monorepo, don't assume single-stack.

1. Run `ls -la` to see the top-level layout.
2. Look for these markers:
   - `package.json` in root → single-repo Node project (could be backend or frontend)
   - `package.json` in subfolders → likely monorepo with one or more JS/TS sub-projects
   - `pubspec.yaml` → Flutter (could be in root or in a subfolder)
   - `composer.json` → PHP (Laravel, Symfony, generic PHP)
   - `requirements.txt` / `pyproject.toml` / `setup.py` → Python
   - `go.mod` → Go
   - `Cargo.toml` → Rust
   - `Gemfile` → Ruby
   - `pom.xml` / `build.gradle` → Java
3. For each detected repo, identify:
   - **Path** (relative to project root)
   - **Stack** (the framework, not just the language — e.g. "NestJS" not "Node", "Next.js" not "React")
   - **Source directory** (`src`, `app`, `lib`, etc.)
   - **Test directory** (`test`, `tests`, `__tests__`, etc. — if it exists)
   - **Source file count** (rough — `find <src> -type f | wc -l`)
   - **Existing CI?** (look for `.github/workflows/`)
   - **Existing precommit hook?** (look for `.git/hooks/pre-commit` that isn't the sample)
4. **Present the discovered repos** to the user as a table:

   | Path | Stack | Source files | CI? | Hook? |
   |---|---|---|---|---|

5. **Ask the user**:
   - "Did I miss any repos? Any of these I should ignore?"
   - "Is there a primary working branch (e.g. a dedicated dev branch), or are we using `main` directly?"
   - "Is there a project lead / dev lead name to use in CLAUDE.md?"
6. Wait for answers. Adjust the repo list if needed.

### Phase 2 — Gather project context

Don't skip this phase. The audit + rules + memory all need this context.

Ask the user (one question at a time, don't fire 5 at once):

1. **Project name** — what should we call this project in CLAUDE.md and memory? (default: the folder name)
2. **One-paragraph description** — what is this project? Who uses it? What problem does it solve?
3. **Phase / state** — is this MVP, post-launch, mature production, greenfield? Any "Phase 2" features that should be excluded from MVP rules?
4. **Spec docs** — are there any client or product docs (PDF, MD, Notion exports) that document what the project should do? If yes, where do they live? Are they confidential?
5. **Vendors / infra** — DB, hosting, auth, payments, email, SMS, push, monitoring? Which are actually live vs which are TODO?
6. **Known issues / amendments** — anything that looks like best practice but is intentionally NOT being implemented? (e.g. a capability intentionally deferred from the MVP.)

Capture answers as you go. You'll save them to memory in Phase 5.

### Phase 3 — Run the audit

For each detected repo, launch a `general-purpose` agent (in the background, in parallel if there are multiple repos) using the audit prompt template at `/Users/mac/Projects/.ai/claude-kit/templates/audit-prompt.md`.

Steps:

1. Create the audit output directory: `mkdir -p audits/<repo>/`
2. Read the audit prompt template
3. Substitute the placeholders for each repo (REPO_NAME, REPO_PATH, STACK_DESCRIPTION, SOURCE_COUNT, SOURCE_DIR, TEST_DIR, AUDIT_OUTPUT_PATH, KEY_CONFIG_FILES, TOP_FOLDER_TYPE)
4. Launch a `general-purpose` agent (NOT Explore — Explore can't write files) in the background with the substituted prompt as the agent prompt
5. Tell the user: "Audit launched for `<repo>` (background). I'll continue with Phases 4-6 while it runs and notify when each repo's audit completes."
6. **DO NOT wait for the audits to complete** — they take 10-20 minutes per repo. Continue with the next phases in parallel.

### Phase 4 — Install the skills + scripts + workflow

This phase happens while audits are running.

Use the helper script:

```bash
bash /Users/mac/Projects/.ai/claude-kit/claude-init.sh <project-root>
```

OR do it manually if the script isn't available:

1. Create `<project>/.claude/{skills,scripts,workflows}/` directories
2. **Copy + substitute placeholders** in every file from `claude-kit/skills/` to `<project>/.claude/skills/`. Substitution:
   - `{{PROJECT_ROOT}}` → the absolute project path
   - `{{PROJECT_NAME}}` → the user-supplied project name
   - `{{MEMORY_ROOT}}` → `~/.claude/projects/<memory-key>/memory` where `<memory-key>` is the project path with `/` replaced by `-`
3. **Copy + substitute** scripts: `claude-kit/scripts/x-precommit.sh` → `<project>/.claude/scripts/x-precommit.sh` (and `install-hooks.sh`, `install-workflows.sh`)
4. **Copy** workflow template: `claude-kit/workflows/x-check.yml` → `<project>/.claude/workflows/x-check.yml`
5. **Build the rules file**: 
   - Start with `claude-kit/rules/rules-baseline.md` content
   - Append the appropriate stack modules based on detected repos:
     - NestJS detected → append `claude-kit/rules/backend-nestjs.md`
     - Laravel detected → append `claude-kit/rules/backend-laravel.md`
     - Django detected → append `claude-kit/rules/backend-django.md`
     - Next.js detected → append `claude-kit/rules/frontend-next.md`
     - React (non-Next) detected → append `claude-kit/rules/frontend-react.md`
     - Vue (non-Nuxt) detected → append `claude-kit/rules/frontend-vue.md`
     - Nuxt detected → append `claude-kit/rules/frontend-nuxt.md` (also append vue.md first since nuxt extends it)
     - Flutter detected → append `claude-kit/rules/mobile-flutter.md`
     - React Native detected → append `claude-kit/rules/mobile-react-native.md`
   - Write the combined file to `<project>/.claude/rules.md`
6. **Generate CLAUDE.md** from the template at `claude-kit/templates/CLAUDE.md.template`. Substitute:
   - `{{PROJECT_NAME}}` → user-supplied name
   - `{{PROJECT_DESCRIPTION}}` → user-supplied paragraph
   - `{{REPOS_TABLE}}` → markdown table of detected repos with their paths + stacks
   - `{{DEV_LEAD_NAME}}` → user-supplied name (or "the dev team")
   - `{{DEV_BRANCH}}` → user-supplied branch (or "main")
   - `{{MEMORY_PROJECT_KEY}}` → memory folder name
   - `{{BOOTSTRAP_DATE}}` → today's date
   - `{{PROJECT_STATE_NOTES}}` → user-supplied phase/state info
   - `{{PROJECT_DONT_LIST}}` → bullet list of "what NOT to do" derived from amendments + universal rules
7. Write `CLAUDE.md` to the project root.

### Phase 5 — Set up memory

1. Compute the memory path: `~/.claude/projects/<memory-key>/memory/` where `<memory-key>` = project absolute path with `/` replaced by `-`
2. `mkdir -p` the memory folder
3. **Copy the seniority memory template** with placeholder substitution:
   - `{{PROJECT_NAME}}` → user-supplied name
   - Source: `claude-kit/templates/feedback_seniority_and_workflow.md`
   - Dest: `<memory-folder>/feedback_seniority_and_workflow.md`
4. **Generate the memory files** based on Phase 2 answers:
   - `MEMORY.md` (the index)
   - `project_scope.md` (from the project description + user type answers)
   - `project_features.md` (from the MVP / amendments answers)
   - `project_vendors.md` (from the vendor answers)
   - `reference_docs.md` (from the spec docs answers, if any)
   - `reference_commands.md` (from the commands template, with project paths substituted)
   - `feedback_confidentiality.md` ONLY if the user said the spec docs are confidential
5. Show the user the list of memory files created and ask: "Anything else I should save to memory before we move on?"

### Phase 6 — Install hooks + workflows

1. Run `bash <project>/.claude/scripts/install-hooks.sh all` (with `<project>` substituted)
2. Run `bash <project>/.claude/scripts/install-workflows.sh all` — this STAGES the `.github/` files but does NOT commit them
3. Tell the user: "Pre-commit hook installed in every detected repo. GitHub Actions workflow staged in `.github/`. You'll need to commit + push the staged files in each repo for CI to go live. I won't commit without your explicit confirmation."

### Phase 7 — Wait for audits + finalize

1. Wait for the background audit agents to complete (Claude Code will notify when each finishes).
2. After all audits are complete, write `audits/README.md` cross-referencing each repo's audit (use a consistent cross-reference format; reuse a prior project's `audits/README.md` as a template if one exists).
3. Update `<memory-folder>/project_audits.md` with a high-level summary of the audit findings (top 5 critical per repo, cross-cutting themes).
4. **Final report** to the user:

```
✅ Bootstrap complete

Files created:
- CLAUDE.md (project root)
- .claude/rules.md (N rules)
- .claude/skills/ (6 skills)
- .claude/scripts/ (3 scripts)
- .claude/workflows/x-check.yml
- audits/ (N repo audit folders)
- ~/.claude/projects/<key>/memory/ (M memory files)

Hooks installed:
- <repo1>/.git/hooks/pre-commit
- <repo2>/.git/hooks/pre-commit
- ...

CI staged (you commit + push):
- <repo1>/.github/workflows/x-check.yml
- <repo1>/.github/scripts/x-precommit.sh
- ...

Next steps:
1. Restart Claude Code so the new skills load
2. Try /x-rules to see your rule list
3. Try /x-check to audit any uncommitted changes
4. Try /x-implement <task> for your first scoped piece of work
5. Commit + push the staged .github/ files when ready

Audit highlights:
[top 5 critical findings across all repos]
```

5. Mark the bootstrap complete in memory: append a `**Bootstrapped:** <date>` line to `MEMORY.md`.

---

## Constraints (hard rules for the bootstrap process)

- **DO NOT skip Phase 0 (confirm)**. The user must explicitly say "yes, bootstrap" before any file operations.
- **DO NOT skip Phase 2 (gather context)**. The audit + memory + rules all depend on what the user answers here.
- **DO NOT auto-detect stack incorrectly**. If you can't tell whether the project is React or Next.js, ASK. Don't guess.
- **DO NOT commit anything**. The bootstrap stages files but the user commits.
- **DO NOT modify code in the existing repos**. The audit READS files but doesn't write to them. The bootstrap WRITES to `.claude/`, `audits/`, `CLAUDE.md`, and the memory folder — nothing else.
- **DO NOT use the Explore agent for the audit** — Explore is read-only and can't write the audit MD files. Use `general-purpose`.
- **DO ask one question at a time** in Phase 2 — don't fire 5 questions in one message.
- **DO run the audits in the background** in Phase 3 and continue with Phases 4-6 in parallel. Don't block the whole bootstrap waiting on a 20-minute audit.
- **DO use the kit's templates** — don't reinvent the rules file or the CLAUDE.md format from scratch. The templates in `claude-kit/templates/` and `claude-kit/rules/` are the source of truth.
- **DO save user answers to memory immediately** as you collect them in Phase 2 — don't wait until Phase 5.

---

## What to do if the project is not a typical web/mobile project

The kit is designed for web (frontend/backend) and mobile projects. If the project is something else:

- **Library / package** — skip the audit (no app to audit). Still install the rules + skills + hooks. Use the universal baseline + appropriate language module if it exists.
- **Desktop app** (Electron, Tauri) — treat the renderer like frontend, the main process like backend
- **CLI tool** — treat as backend. Use the language-appropriate rules.
- **Documentation / static site** — install rules + skills but skip the audit. Probably don't need the precommit hook either.
- **Mixed (e.g. monorepo with backend + frontend + mobile + library + docs)** — bootstrap the whole monorepo as one project with multiple repos. Run the audit on each app, skip libraries/docs.

If you encounter a stack that doesn't have a rules module in the kit (`backend-go.md`, `mobile-swift.md`, etc.), tell the user: "I don't have a stack module for `<stack>`. I'll use the universal baseline only. You can add a stack module later by editing `<project>/.claude/rules.md` or by contributing one back to `claude-kit/rules/`."

---

## What this bootstrap does NOT do

- Does not commit anything
- Does not push anything
- Does not modify code in the source repos
- Does not run tests
- Does not install npm/yarn/composer/pip dependencies
- Does not configure linters / formatters / type-checkers (those are project-specific)
- Does not generate any new product features
- Does not modify the existing CI if one is present (it stages a new workflow file in `.github/workflows/x-check.yml` which lives alongside any existing workflows)

---

## After bootstrap — adding rules / extending the system

Once bootstrap is complete, the user manages the system project-by-project:

- **Add a rule**: edit `<project>/.claude/rules.md` directly OR use `/x-add-rule <category> <description>`
- **Add a skill**: drop a new `<name>/SKILL.md` file in `<project>/.claude/skills/`
- **Update the precommit hook patterns**: edit `<project>/.claude/scripts/x-precommit.sh` and re-run `bash <project>/.claude/scripts/install-hooks.sh all --force`
- **Update the workflow**: edit `<project>/.claude/workflows/x-check.yml` and re-run `bash <project>/.claude/scripts/install-workflows.sh all --force`

### Updating the kit itself (affects future bootstraps)

If the user discovers a rule that should be universal (apply to all future projects), they edit `/Users/mac/Projects/.ai/claude-kit/rules/rules-baseline.md` or the appropriate stack module. The next project bootstrapped will get the updated rules. Existing projects need to re-run the bootstrap (or manually copy the new rules into their `.claude/rules.md`).

---

## Recovery: what to do if the bootstrap fails partway

The bootstrap is mostly idempotent — re-running it won't break anything. But if a phase fails:

- **Phase 1-2 failure** (discovery / questions): just restart, the questions will re-ask. Nothing to clean up.
- **Phase 3 failure** (audit didn't write files): the agent crashed. Restart the audit for the affected repo only.
- **Phase 4 failure** (file installation): re-run with `--force` to overwrite partial state.
- **Phase 5 failure** (memory): delete the memory folder and re-run Phase 5 only.
- **Phase 6 failure** (hooks/workflows): the installers are idempotent — re-run them.

If everything is broken, delete `<project>/.claude/`, `<project>/CLAUDE.md`, `<project>/audits/`, and `~/.claude/projects/<key>/memory/`, then start over.

---

**Kit version:** 1.1
**Last updated:** 2026-07-19
