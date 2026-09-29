#!/usr/bin/env bash
# install-plan-hook.sh — install the plan-mode context hook into a project.
#
# Usage:  bash install-plan-hook.sh <project-path>
#
# Idempotent. It:
#   1. Copies plan-mode-context.sh into <project>/.claude/scripts/ (with the
#      project name substituted into the banner) and makes it executable.
#   2. Registers a UserPromptSubmit hook in <project>/.claude/settings.local.json
#      pointing at that script — without disturbing existing permissions or hooks,
#      and skipping the insert if the same hook command is already present.
#
# Called by claude-init.sh (new projects) and claude-sync.sh (existing projects),
# and safe to run standalone to (re)deploy the hook.
set -euo pipefail

KIT_SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:?Usage: install-plan-hook.sh <project-path>}"
TARGET="$(cd "$TARGET" && pwd)"

[ -d "$TARGET/.claude" ] || { printf '❌ %s has no .claude/ — run claude-init.sh first.\n' "$TARGET" >&2; exit 1; }

PROJECT_NAME="$(basename "$TARGET")"
mkdir -p "$TARGET/.claude/scripts"
sed "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
    "$KIT_SCRIPTS/plan-mode-context.sh" > "$TARGET/.claude/scripts/plan-mode-context.sh"
chmod +x "$TARGET/.claude/scripts/plan-mode-context.sh"

SETTINGS="$TARGET/.claude/settings.local.json"
HOOKCMD='$CLAUDE_PROJECT_DIR/.claude/scripts/plan-mode-context.sh'

python3 - "$SETTINGS" "$HOOKCMD" <<'PY'
import json, os, sys
path, cmd = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    with open(path) as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError:
            data = {}
# Q-15: stop Claude Code from appending its co-author trailer / PR footer.
no_attr = {"attribution": {"commit": "", "pr": ""}, "includeCoAuthoredBy": False}
attr_changed = any(data.get(k) != v for k, v in no_attr.items())
data.update(no_attr)
hooks = data.setdefault("hooks", {})
ups = hooks.setdefault("UserPromptSubmit", [])
already = any(
    isinstance(h, dict) and h.get("command") == cmd
    for entry in ups if isinstance(entry, dict)
    for h in entry.get("hooks", []) if isinstance(entry.get("hooks"), list)
)
if already:
    print("  · hook already present — skipped")
else:
    ups.append({"hooks": [{"type": "command", "command": cmd}]})
    print("  ✓ registered UserPromptSubmit hook")
if attr_changed:
    print("  ✓ disabled Claude co-author trailer (Q-15)")
if attr_changed or not already:
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PY

printf '  ✓ scripts/plan-mode-context.sh\n'
