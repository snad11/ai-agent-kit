# Gemini CLI kit

Installs the shared **skills + rules + memory + hooks** system into any project,
in the layout Gemini CLI actually reads.

> `$KIT` is your clone of this repo — e.g. `export KIT=~/ai-agent-kit`.
> See the [root README](../README.md#install).

## Quick start

```bash
cd /path/to/your/project
bash $KIT/gemini-kit/gemini-init.sh .
```

Then finish the conversational phases by referencing `@$KIT/gemini-kit/BOOTSTRAP.md`
in Gemini CLI.

## What it writes

| Path | What it is |
|---|---|
| `GEMINI.md` | The file Gemini CLI reads automatically. Rules index + memory clone. |
| `.gemini/rules.md` | Universal rule baseline plus auto-detected stack modules. |
| `.gemini/scripts/` | Pre-commit scanner, hook + workflow installers, memory cloner. |
| `.gemini/workflows/x-check.yml` | GitHub Actions check, staged into `.github/` by `install-hooks.sh`. |

## Commands

The seven skills are installed as `toml` commands in `.gemini/commands/`: `/x-implement`, `/x-check`, `/x-rules`, `/x-prompt`, `/x-check-file`, `/x-add-rule`, `/x-audit`.

## Caveat

Custom commands are TOML with prompt/description; reload with /commands reload

## Keeping in step

This kit's shared assets are mirrored from `agent-kit`, and `gemini-init.sh`
is generated. Do not hand-edit either:

```bash
bash $KIT/agent-kit/kit-scaffold.sh   # regenerate installers
bash $KIT/agent-kit/kit-sync.sh       # mirror rules/skills/scripts
bash $KIT/agent-kit/kit-sync.sh --check   # CI gate
```
