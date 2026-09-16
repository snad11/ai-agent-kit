# ai-agent-kit

One home for a portable AI-agent governance system — the same **skills + rules + memory + hooks**
layer, installable into any project, for any AI coding agent.

The problem it solves: different agents read different files. Claude Code auto-loads `CLAUDE.md`
and a memory folder; ZCode, Codex and Cursor auto-load `AGENTS.md` and `.agents/`. Writing the
same governance twice is how it drifts. These kits emit one governance layer from one source.

## What's in here

Eleven kits. Pick the one for your agent — they all install the same governance
(skills, rules, memory, pre-commit hook, CI check), each in the layout its agent reads.

| Kit | Agent | Writes | Commands |
|---|---|---|---|
| [`agent-kit/`](agent-kit/) | Any `AGENTS.md` reader (multi-target) | `AGENTS.md` + `.agents/`, `--target agents\|zcode\|claude\|all` | yes |
| [`claude-kit/`](claude-kit/) | Claude Code | `CLAUDE.md` + `.claude/` | yes |
| [`gemini-kit/`](gemini-kit/) | Gemini CLI | `GEMINI.md` + `.gemini/` | yes — TOML |
| [`copilot-kit/`](copilot-kit/) | GitHub Copilot | `.github/copilot-instructions.md` | yes — `.instructions.md` |
| [`cursor-kit/`](cursor-kit/) | Cursor | `AGENTS.md` + `.cursor/rules/*.mdc` | yes — `.mdc` |
| [`windsurf-kit/`](windsurf-kit/) | Windsurf | `AGENTS.md` + `.windsurf/rules/` | yes — workflows |
| [`cline-kit/`](cline-kit/) | Cline | `AGENTS.md` + `.clinerules/` | no |
| [`codex-kit/`](codex-kit/) | Codex CLI | `AGENTS.md` + `.codex/` | no |
| [`amp-kit/`](amp-kit/) | Amp | `AGENTS.md` | no |
| [`zed-kit/`](zed-kit/) | Zed | `.rules` + `AGENTS.md` | no |
| [`aider-kit/`](aider-kit/) | Aider | `CONVENTIONS.md` | no |

[`PROMPT_GENERATOR.md`](PROMPT_GENERATOR.md) is the shared planning standard (v3) every
kit's `/x-prompt` and `/x-implement` consume.

**"Commands: no"** means that agent has no slash-command mechanism. Those kits still
install every rule, the memory clone, the hook and the CI check — the seven skills ship
as documented workflows in the anchor rather than as invokable commands.

### One project, several agents

Anchor files can shadow each other. Zed loads `.rules`, `.cursorrules`, `.windsurfrules`,
`.clinerules` or `.github/copilot-instructions.md` **instead of** `AGENTS.md` when one is
present, because they rank higher in its priority list — so a project bootstrapped with
several kits can have Zed read a file you did not intend. `zed-kit` writes `.rules` and
mirrors it to `AGENTS.md` for exactly this reason. Windsurf builds now prefer
`.devin/rules/` over `.windsurf/rules/`. Install one kit per project unless you have
checked how the anchors interact.

## Which one to use

Use the kit named after your agent. Use **`agent-kit`** if your tool reads `AGENTS.md` and
isn't listed above, or if you want one install to serve several agents at once via
`--target all`.

All kits share one source: `agent-kit` holds the rules, skills, scripts and templates, and
`kit-sync.sh` mirrors them outward. The per-agent installers are generated from a single
template, so they cannot drift apart. Fix a rule once and every kit gets it.

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

### Any other agent

Every kit follows the same shape — substitute its name:

```bash
bash $KIT/<agent>-kit/<agent>-init.sh .     # e.g. gemini-kit/gemini-init.sh
```

```
@$KIT/<agent>-kit/BOOTSTRAP.md

Bootstrap THIS project with the <Agent> kit. Read BOOTSTRAP.md fully and follow every
phase exactly, in order, without skipping: Phase 0 confirm the working directory,
Phase 1 detect the stack(s), Phase 2 ask me the context questions ONE AT A TIME,
Phase 3 audit every source file line-by-line, Phases 4-6 rules, memory, hooks and CI.
Apply the same depth and rigor the kit was built with. Do not commit anything. Do not
modify source code — only the kit's own directories, the anchor file, audits/ and memory.
```

Each kit's README lists exactly what it writes: [gemini](gemini-kit/README.md) ·
[copilot](copilot-kit/README.md) · [cursor](cursor-kit/README.md) ·
[windsurf](windsurf-kit/README.md) · [cline](cline-kit/README.md) ·
[codex](codex-kit/README.md) · [amp](amp-kit/README.md) · [zed](zed-kit/README.md) ·
[aider](aider-kit/README.md) · [agent-kit](agent-kit/README.md) ·
[claude-kit](claude-kit/README.md).

## What every kit installs

Seven skills (`/x-implement`, `/x-check`, `/x-rules`, `/x-prompt`, `/x-check-file`, `/x-add-rule`,
`/x-audit`), a universal rule baseline plus auto-detected stack modules (NestJS, Laravel, Django,
Next.js, React, Vue, Flutter and more), a pure-bash pre-commit hook, a matching GitHub Actions
check, per-project memory files, and a plan-mode context hook.

Two things vary by agent: whether the skills become invokable commands (see the table above),
and whether the plan-mode hook is auto-registered — only Claude Code and ZCode expose a
`UserPromptSubmit` hook, so other kits install the script without wiring it up.

## Maintaining the kits

`agent-kit` is the source of truth. The other kits are mirrors plus a generated installer,
so never hand-edit a file marked `GENERATED FILE`, or a kit's `rules/`, `skills/`,
`scripts/` or `workflows/`.

```bash
bash agent-kit/kit-scaffold.sh          # regenerate every <agent>-init.sh + _subst.sh
bash agent-kit/kit-sync.sh              # mirror rules, skills, scripts, templates outward
bash agent-kit/kit-scaffold.sh --check  # CI gate: fails if a generated file was edited
bash agent-kit/kit-sync.sh --check      # CI gate: fails on drift or orphaned files
```

To add an agent: add a row to [`agent-kit/kits.manifest`](agent-kit/kits.manifest), run
both scripts, and write the kit's README/BOOTSTRAP prose. No new sync wiring is needed.

## Versions

Version numbers for the kits, the skills, and `PROMPT_GENERATOR.md` are pinned here and nowhere
else. Do not read a version from any other file.

| Component | Version |
|---|---|
| `agent-kit` | 1.1 |
| `claude-kit` | 1.2 |
| `gemini-kit`, `copilot-kit`, `cursor-kit`, `windsurf-kit`, `cline-kit`, `codex-kit`, `amp-kit`, `zed-kit`, `aider-kit` | 1.0 |
| `PROMPT_GENERATOR.md` | 3.0 |

Agent conventions move fast. The anchor path and command format for each kit are recorded
in [`agent-kit/kits.manifest`](agent-kit/kits.manifest) with the date they were verified —
re-check before relying on one.
