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

## Quick start

```bash
# Mechanical: detect stack, emit dirs, build rules, generate anchor file, clone memory, install plan-hook
bash agent-kit/agent-init.sh /path/to/project --target all

# Conversational: context Q&A, audits, author memory
# In your agent, reference agent-kit/BOOTSTRAP.md
```

Full details in [agent-kit/README.md](agent-kit/README.md) and [claude-kit/README.md](claude-kit/README.md).

## What both kits install

Seven skills (`/x-implement`, `/x-check`, `/x-rules`, `/x-prompt`, `/x-check-file`, `/x-add-rule`,
`/x-audit`), a universal rule baseline plus auto-detected stack modules (NestJS, Laravel, Django,
Next.js, React, Vue, Flutter and more), a pure-bash pre-commit hook, a matching GitHub Actions
check, per-project memory files, and a plan-mode context hook.
