# Amp kit

Installs the shared **skills + rules + memory + hooks** system into any project,
in the layout Amp actually reads.

> `$KIT` is your clone of this repo — e.g. `export KIT=~/ai-agent-kit`.
> See the [root README](../README.md#install).

## Quick start

```bash
cd /path/to/your/project
bash $KIT/amp-kit/amp-init.sh .
```

Then finish the conversational phases by referencing `@$KIT/amp-kit/BOOTSTRAP.md`
in Amp.

## What it writes

| Path | What it is |
|---|---|
| `AGENTS.md` | The file Amp reads automatically. Rules index + memory clone. |
| `.agents/rules.md` | Universal rule baseline plus auto-detected stack modules. |
| `.agents/scripts/` | Pre-commit scanner, hook + workflow installers, memory cloner. |
| `.agents/workflows/x-check.yml` | GitHub Actions check, staged into `.github/` by `install-hooks.sh`. |

## Commands

This agent has no slash-command format. The seven skills ship as documented workflows inside `AGENTS.md`, not as invokable commands.

## Caveat

Thin AGENTS.md consumer; no per-tool directory

## Keeping in step

This kit's shared assets are mirrored from `agent-kit`, and `amp-init.sh`
is generated. Do not hand-edit either:

```bash
bash $KIT/agent-kit/kit-scaffold.sh   # regenerate installers
bash $KIT/agent-kit/kit-sync.sh       # mirror rules/skills/scripts
bash $KIT/agent-kit/kit-sync.sh --check   # CI gate
```
