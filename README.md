# ai-agent-kit

One home for a portable AI-agent governance system — the same **skills + rules + memory + hooks**
layer, installable into any project, for any AI coding agent.

The problem it solves: different agents read different files. Claude Code auto-loads `CLAUDE.md`
and a memory folder; ZCode, Codex and Cursor auto-load `AGENTS.md` and `.agents/`. Writing the
same governance twice is how it drifts. These kits emit one governance layer from one source.

## What's in here

| Directory | What it is |
|---|---|
| [`agent-kit/`](agent-kit/) | **The current kit.** Multi-agent: emits `AGENTS.md` + `.agents/`, with `--target agents\|zcode\|claude\|all` selecting which agent conventions also get populated. |
| [`claude-kit/`](claude-kit/) | **The origin.** Claude Code only: emits `CLAUDE.md` + `.claude/`. Still works unchanged; kept for history and for Claude-only projects. |
| [`PROMPT_GENERATOR.md`](PROMPT_GENERATOR.md) | The shared planning standard (v3) that both kits' `/x-prompt` and `/x-implement` skills consume. Agent-facing — it turns a messy request into a scoped, verifiable plan before any code is written. |

## Which one to use

Use **`agent-kit`** for new work. It is a superset: its rules, skills, scripts and templates are
copied verbatim from `claude-kit`, and `--target claude` reproduces the `claude-kit` output. Reach
for `claude-kit` only when you specifically want the original Claude-only installer.

The key generalization is the **memory-into-anchor clone**. Claude auto-loads its memory folder,
but no other agent does, so `agent-kit` also clones every memory file verbatim into `AGENTS.md` —
giving every agent the same always-in-context guarantee.

## Install

The kit lives **outside** the projects it bootstraps — clone it once, anywhere, and point it at
projects as you go. It is never cloned into a project.

```bash
git clone git@github.com:snad11/ai-agent-kit.git ~/ai-agent-kit

# Point $KIT at your clone. Add this to ~/.zshrc so it persists.
export KIT=~/ai-agent-kit
```

Every command in this repo is written in terms of `$KIT`, so once that is exported the examples
are copy-pasteable as-is. The installers resolve their own location at runtime, so the clone can
live wherever you like.

## Bootstrap a project

`cd` into the project you want to bootstrap, then paste one of the following into your agent.

### Any agent — agent-kit (recommended)

```
@$KIT/agent-kit/BOOTSTRAP.md

Bootstrap THIS project with the Agent Kit. Read BOOTSTRAP.md fully and follow every
phase exactly, in order, without skipping:
- Phase 0: confirm the working directory AND the --target with me before any file operations.
- Phase 1: detect the stack(s) here — do not assume; if unsure, ask.
- Phase 2: ask me the context questions ONE AT A TIME.
- Phase 3: audit every source file line-by-line (background agents).
- Phases 4-6: install skills + rules + scripts + workflow, generate AGENTS.md (and CLAUDE.md
  for target claude/all), set up memory and clone it into the anchor, install the pre-commit
  hook, stage the CI workflow.
Apply the same depth and rigor the kit was built with. Do not commit anything. Do not
modify source code — only .agents/, .claude/, .zcode/, AGENTS.md, CLAUDE.md, audits/, and
the memory folder.
```

Or run the mechanical installer first and let the agent finish the conversational phases:

```bash
bash $KIT/agent-kit/agent-init.sh . --target all
```

### Claude Code only — claude-kit

```
@$KIT/claude-kit/BOOTSTRAP.md

Bootstrap THIS project with the Claude Kit. Read BOOTSTRAP.md fully and follow every
phase exactly, in order, without skipping:
- Phase 0: confirm the working directory with me before any file operations.
- Phase 1: detect the stack(s) here — do not assume; if unsure, ask.
- Phase 2: ask me the context questions ONE AT A TIME.
- Phase 3: audit every source file line-by-line (background agents).
- Phases 4-6: install skills + rules + scripts + workflow, generate CLAUDE.md, set up
  memory, install the pre-commit hook, stage the CI workflow.
Apply the same depth and rigor the kit was built with. Do not commit anything. Do not
modify source code — only .claude/, CLAUDE.md, audits/, and the memory folder.
```

Full details in [agent-kit/README.md](agent-kit/README.md) and [claude-kit/README.md](claude-kit/README.md).

## What both kits install

Seven skills (`/x-implement`, `/x-check`, `/x-rules`, `/x-prompt`, `/x-check-file`, `/x-add-rule`,
`/x-audit`), a universal rule baseline plus auto-detected stack modules (NestJS, Laravel, Django,
Next.js, React, Vue, Flutter and more), a pure-bash pre-commit hook, a matching GitHub Actions
check, per-project memory files, and a plan-mode context hook.

## Versions

Version numbers for the kits, the skills, and `PROMPT_GENERATOR.md` are pinned here and nowhere
else. Do not read a version from any other file.

| Component | Version |
|---|---|
| `agent-kit` | 1.1 |
| `claude-kit` | 1.2 |
| `PROMPT_GENERATOR.md` | 3.0 |
