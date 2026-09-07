# agent-kit

A portable bootstrap kit that installs the same **skills + rules + memory + hooks** system into any project, for **any** AI coding agent. One source, multiple agent targets.

It is the multi-agent generalization of [`claude-kit`](../claude-kit/) (which targets Claude Code only). `claude-kit` is untouched; `agent-kit` adds target selection and standards-based output.

## Why

Different agents read different files: Claude Code auto-loads `CLAUDE.md` and a memory folder; ZCode/Codex/Cursor auto-load `AGENTS.md` and `.agents/`. Writing the same governance twice is how it drifts. This kit emits **one** governance layer from **one** source, with a `--target` flag that picks which agent conventions also get populated.

The key insight (proven on the `provx` project): the kit's *content* — rules, skills, scripts, the planning standard — is already tool-agnostic. Only three things are agent-specific (output dir, memory auto-loading, plan-hook output format), and each generalizes cleanly.

## What it installs

| Asset | Universal home | Also mirrored to (per target) |
|---|---|---|
| **7 skills** (`/x-implement`, `/x-check`, `/x-rules`, `/x-prompt`, `/x-check-file`, `/x-add-rule`, `/x-audit`) | `.agents/skills/` | `.claude/skills/` (copy), `.zcode/skills/` (symlink) |
| **Rules** (universal baseline + stack modules) | `.agents/rules.md` | `.claude/rules.md` (copy) |
| **Scripts** (precommit, installers, plan-hook) | `.agents/scripts/` | `.claude/scripts/`, `.zcode/scripts/` |
| **Anchor file** | `AGENTS.md` | `CLAUDE.md` (claude/all) |
| **Memory** | `~/.agents/projects/<key>/memory/` | `~/.claude/projects/<key>/memory/` (claude/all) — **and cloned verbatim into `AGENTS.md`** |
| **Plan-mode hook** | `.agents/scripts/plan-mode-context.sh` (plain text) | `.zcode/scripts/plan-mode-context.zcode.sh` (JSON wrapper) registered in `.zcode/config.json`; or `.claude/settings.local.json` |
| **CI workflow** | `.agents/workflows/x-check.yml` | staged into `.github/` per repo |
| **Git hooks** | `x-precommit.sh` | installed into `.git/hooks/` per repo (tool-agnostic) |

The **memory-into-anchor clone** is the core generalization: Claude auto-loads its memory folder, but no other agent does. Cloning every memory file verbatim into `AGENTS.md` gives every agent the same always-in-context guarantee. `clone-memory.sh` does this idempotently between markers.

## Targets

```
--target agents   (default)  AGENTS.md + .agents/{skills,scripts,rules.md,...}      [ZCode, Codex, Cursor, any AGENTS.md reader]
--target zcode               above + .zcode/{skills(symlinks),scripts,config.json}  [ZCode native]
--target claude              CLAUDE.md + .claude/{skills,scripts,rules.md,...}      [Claude Code]
--target all                 everything (AGENTS.md + CLAUDE.md + .agents + .zcode + .claude)
```

`.agents/skills/` always holds the real files. `.zcode/skills/` are symlinks into it (zero drift). `.claude/skills/` are real copies (Claude's installer convention).

## Usage

### Quick start (mechanical install + conversational finish)

```bash
# 1. Mechanical: detect stack, emit dirs, build rules, generate AGENTS.md, clone memory, install plan-hook
bash /Users/mac/Projects/.ai/agent-kit/agent-init.sh . --target all

# 2. Conversational: context Q&A, audits, author memory, (for claude/all) generate CLAUDE.md
#    In your agent, reference:
@/Users/mac/Projects/.ai/agent-kit/BOOTSTRAP.md
```

### Standalone scripts

```bash
agent-init.sh <path> --target zcode        # bootstrap into a project
agent-sync.sh  <path>                       # re-sync skills/rules/templates + re-clone memory (preserves project rules)
scripts/install-hooks.sh all                # deploy the pre-commit hook into every detected git repo
scripts/install-workflows.sh all            # stage the x-check GitHub Action into .github/
scripts/clone-memory.sh AGENTS.md <memdir>  # refresh the memory clone in an anchor file
scripts/install-plan-hook.sh <path> <target># (re)register the plan-mode hook for a target
```

## Relationship to `claude-kit`

| | `claude-kit` | `agent-kit` |
|---|---|---|
| Targets | Claude Code only | ZCode, Codex, Cursor, Claude Code, any `AGENTS.md` reader |
| Anchor | `CLAUDE.md` | `AGENTS.md` (+ `CLAUDE.md` when claude/all) |
| Memory | `~/.claude/.../memory/` (auto-loaded by Claude) | same **plus** cloned verbatim into `AGENTS.md` (so non-Claude agents see it) |
| Skills dir | `.claude/skills/` | `.agents/skills/` (+ mirrors/symlinks per target) |
| Plan hook | plain text (Claude) | plain text **and** JSON wrapper (ZCode) |
| Shared content | source of truth | rules, skills, git/CI scripts, templates copied verbatim from `claude-kit` |

`claude-kit` continues to work unchanged for Claude Code projects. `agent-kit` is the choice when a project is (or may become) multi-agent.

## Structure

```
agent-kit/
├── README.md  BOOTSTRAP.md  agent-init.sh  agent-sync.sh
├── rules/        # baseline + stack modules (copied from claude-kit)
├── skills/       # 7 skills (copied from claude-kit)
├── scripts/      # _subst.sh, x-precommit.sh, install-{hooks,workflows,plan-hook}.sh,
│                  # plan-mode-context.sh + plan-mode-context.zcode.sh, clone-memory.sh
├── templates/    # AGENTS.md.template (new), CLAUDE.md.template, audit-prompt.md, ...
└── workflows/    # x-check.yml
```

## What it does NOT do

Commit or push anything, modify source code, run tests, install dependencies, configure linters, generate features, or replace existing CI (it stages a new `x-check.yml` alongside whatever's there).

---

**Version:** 1.0 · **Updated:** 2026-07-25 · Generalized from `claude-kit` v1.1
