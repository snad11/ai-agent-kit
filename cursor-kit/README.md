# Cursor kit

Installs the shared **skills + rules + memory + hooks** system into any project,
in the layout Cursor actually reads.

> `$KIT` is your clone of this repo — e.g. `export KIT=~/ai-agent-kit`.
> See the [root README](../README.md#install).

## Quick start

```bash
cd /path/to/your/project
bash $KIT/cursor-kit/cursor-init.sh .
```

Then finish the conversational phases by referencing `@$KIT/cursor-kit/BOOTSTRAP.md`
in Cursor.

## What it writes

| Path | What it is |
|---|---|
| `AGENTS.md` | The file Cursor reads automatically. Rules index + memory clone. |
| `.cursor/rules/000-project-rules.mdc` | Universal rule baseline plus auto-detected stack modules. |
| `.cursor/scripts/` | Pre-commit scanner, hook + workflow installers, memory cloner. |
| `.cursor/workflows/x-check.yml` | GitHub Actions check, staged into `.github/` by `install-hooks.sh`. |

## Commands

The seven skills are installed as `mdc` commands in `.cursor/commands/`: `/x-implement`, `/x-check`, `/x-rules`, `/x-prompt`, `/x-check-file`, `/x-add-rule`, `/x-audit`.

## Caveat

Reads AGENTS.md natively; .mdc adds per-glob scoping. Legacy .cursorrules is ignored by Agent mode

## Keeping in step

This kit's shared assets are mirrored from `agent-kit`, and `cursor-init.sh`
is generated. Do not hand-edit either:

```bash
bash $KIT/agent-kit/kit-scaffold.sh   # regenerate installers
bash $KIT/agent-kit/kit-sync.sh       # mirror rules/skills/scripts
bash $KIT/agent-kit/kit-sync.sh --check   # CI gate
```
