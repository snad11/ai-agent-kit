# GitHub Copilot kit

Installs the shared **skills + rules + memory + hooks** system into any project,
in the layout GitHub Copilot actually reads.

> `$KIT` is your clone of this repo — e.g. `export KIT=~/ai-agent-kit`.
> See the [root README](../README.md#install).

## Quick start

```bash
cd /path/to/your/project
bash $KIT/copilot-kit/copilot-init.sh .
```

Then finish the conversational phases by referencing `@$KIT/copilot-kit/BOOTSTRAP.md`
in GitHub Copilot.

## What it writes

| Path | What it is |
|---|---|
| `.github/copilot-instructions.md` | The file GitHub Copilot reads automatically. Rules index + memory clone. |
| `.github/copilot-instructions.md` | Universal rule baseline plus auto-detected stack modules. |
| `.github/scripts/` | Pre-commit scanner, hook + workflow installers, memory cloner. |
| `.github/workflows/x-check.yml` | GitHub Actions check, staged into `.github/` by `install-hooks.sh`. |

## Commands

The seven skills are installed as `instructions` commands in `.github/instructions/`: `/x-implement`, `/x-check`, `/x-rules`, `/x-prompt`, `/x-check-file`, `/x-add-rule`, `/x-audit`.

## Caveat

Scoped rules use .instructions.md with applyTo frontmatter globs

## Keeping in step

This kit's shared assets are mirrored from `agent-kit`, and `copilot-init.sh`
is generated. Do not hand-edit either:

```bash
bash $KIT/agent-kit/kit-scaffold.sh   # regenerate installers
bash $KIT/agent-kit/kit-sync.sh       # mirror rules/skills/scripts
bash $KIT/agent-kit/kit-sync.sh --check   # CI gate
```
