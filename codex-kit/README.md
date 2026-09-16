# Codex CLI kit

Installs the shared **skills + rules + memory + hooks** system into any project,
in the layout Codex CLI actually reads.

> `$KIT` is your clone of this repo — e.g. `export KIT=~/ai-agent-kit`.
> See the [root README](../README.md#install).

## Quick start

```bash
cd /path/to/your/project
bash $KIT/codex-kit/codex-init.sh .
```

Then finish the conversational phases by referencing `@$KIT/codex-kit/BOOTSTRAP.md`
in Codex CLI.

## What it writes

| Path | What it is |
|---|---|
| `AGENTS.md` | The file Codex CLI reads automatically. Rules index + memory clone. |
| `.codex/rules.md` | Universal rule baseline plus auto-detected stack modules. |
| `.codex/scripts/` | Pre-commit scanner, hook + workflow installers, memory cloner. |
| `.codex/workflows/x-check.yml` | GitHub Actions check, staged into `.github/` by `install-hooks.sh`. |

## Commands

This agent has no slash-command format. The seven skills ship as documented workflows inside `AGENTS.md`, not as invokable commands.

## Caveat

AGENTS.md discovery is tunable via ~/.codex/config.toml (project_doc_max_bytes)

## Keeping in step

This kit's shared assets are mirrored from `agent-kit`, and `codex-init.sh`
is generated. Do not hand-edit either:

```bash
bash $KIT/agent-kit/kit-scaffold.sh   # regenerate installers
bash $KIT/agent-kit/kit-sync.sh       # mirror rules/skills/scripts
bash $KIT/agent-kit/kit-sync.sh --check   # CI gate
```
