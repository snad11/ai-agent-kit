# Windsurf kit

Installs the shared **skills + rules + memory + hooks** system into any project,
in the layout Windsurf actually reads.

> `$KIT` is your clone of this repo — e.g. `export KIT=~/ai-agent-kit`.
> See the [root README](../README.md#install).

## Quick start

```bash
cd /path/to/your/project
bash $KIT/windsurf-kit/windsurf-init.sh .
```

Then finish the conversational phases by referencing `@$KIT/windsurf-kit/BOOTSTRAP.md`
in Windsurf.

## What it writes

| Path | What it is |
|---|---|
| `AGENTS.md` | The file Windsurf reads automatically. Rules index + memory clone. |
| `.windsurf/rules/project-rules.md` | Universal rule baseline plus auto-detected stack modules. |
| `.windsurf/kit/scripts/` | Pre-commit scanner, hook + workflow installers, memory cloner. |
| `.windsurf/kit/workflows/x-check.yml` | GitHub Actions check, staged into `.github/` by `install-hooks.sh`. |

## Commands

The seven skills are installed as `md` commands in `.windsurf/workflows/`: `/x-implement`, `/x-check`, `/x-rules`, `/x-prompt`, `/x-check-file`, `/x-add-rule`, `/x-audit`.

## Caveat

Current builds prefer .devin/rules/ which takes precedence over .windsurf/

## Keeping in step

This kit's shared assets are mirrored from `agent-kit`, and `windsurf-init.sh`
is generated. Do not hand-edit either:

```bash
bash $KIT/agent-kit/kit-scaffold.sh   # regenerate installers
bash $KIT/agent-kit/kit-sync.sh       # mirror rules/skills/scripts
bash $KIT/agent-kit/kit-sync.sh --check   # CI gate
```
