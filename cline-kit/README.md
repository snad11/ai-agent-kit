# Cline kit

Installs the shared **skills + rules + memory + hooks** system into any project,
in the layout Cline actually reads.

> `$KIT` is your clone of this repo — e.g. `export KIT=~/ai-agent-kit`.
> See the [root README](../README.md#install).

## Quick start

```bash
cd /path/to/your/project
bash $KIT/cline-kit/cline-init.sh .
```

Then finish the conversational phases by referencing `@$KIT/cline-kit/BOOTSTRAP.md`
in Cline.

## What it writes

| Path | What it is |
|---|---|
| `AGENTS.md` | The file Cline reads automatically. Rules index + memory clone. |
| `.clinerules/project-rules.md` | Universal rule baseline plus auto-detected stack modules. |
| `.clinerules/scripts/` | Pre-commit scanner, hook + workflow installers, memory cloner. |
| `.clinerules/workflows/x-check.yml` | GitHub Actions check, staged into `.github/` by `install-hooks.sh`. |

## Commands

This agent has no slash-command format. The seven skills ship as documented workflows inside `AGENTS.md`, not as invokable commands.

## Caveat

Reads .clinerules/ plus .cursorrules, .windsurfrules and AGENTS.md

## Keeping in step

This kit's shared assets are mirrored from `agent-kit`, and `cline-init.sh`
is generated. Do not hand-edit either:

```bash
bash $KIT/agent-kit/kit-scaffold.sh   # regenerate installers
bash $KIT/agent-kit/kit-sync.sh       # mirror rules/skills/scripts
bash $KIT/agent-kit/kit-sync.sh --check   # CI gate
```
