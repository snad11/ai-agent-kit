#!/usr/bin/env bash
# install-plan-hook.sh — install the plan-mode context hook into a project.
#
# Usage:  bash install-plan-hook.sh <project-path> <agent-target>
#
#   <agent-target>  agents | zcode | claude | all   (default: agents)
#
# Target behavior:
#   agents / claude  -> register a UserPromptSubmit hook in .claude/settings.local.json
#                       pointing at the plain-text script (Claude accepts plain text).
#   zcode            -> register a UserPromptSubmit hook in .zcode/config.json pointing
#                       at the JSON-wrapping adapter (ZCode requires strict JSON output).
#   all              -> do both (claude settings + zcode config).
#
# Idempotent: skips the insert if the same hook command is already present.
# Copies the plan-mode scripts into the project's scripts dir (co-located so the
# project is self-contained), substituting {{PROJECT_NAME}} into the banner.

set -euo pipefail

TARGET="${1:?Usage: install-plan-hook.sh <project-path> [agent-target]}"
AGENT_TARGET="${2:-agents}"
TARGET="$(cd "$TARGET" && pwd)"

KIT_SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="$(basename "$TARGET")"

# Decide which script locations to install. .agents/scripts is the universal home;
# .claude/scripts and .zcode/scripts get co-located copies when those targets apply.
install_scripts_to() {
    local sdir="$1"
    mkdir -p "$sdir"
    sed "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
        "$KIT_SCRIPTS/plan-mode-context.sh" > "$sdir/plan-mode-context.sh"
    chmod +x "$sdir/plan-mode-context.sh"
    # The ZCode adapter is only needed for the zcode target, but it's small and
    # harmless; always ship it alongside so the hook config is self-contained.
    cp "$KIT_SCRIPTS/plan-mode-context.zcode.sh" "$sdir/plan-mode-context.zcode.sh"
    chmod +x "$sdir/plan-mode-context.zcode.sh"
}

register_claude_hook() {
    local settings="$TARGET/.claude/settings.local.json"
    local hookcmd='$CLAUDE_PROJECT_DIR/.claude/scripts/plan-mode-context.sh'
    python3 - "$settings" "$hookcmd" <<'PY'
import json, os, sys
path, cmd = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except json.JSONDecodeError: data = {}
hooks = data.setdefault("hooks", {})
ups = hooks.setdefault("UserPromptSubmit", [])
already = any(
    isinstance(h, dict) and h.get("command") == cmd
    for entry in ups if isinstance(entry, dict)
    for h in entry.get("hooks", []) if isinstance(entry.get("hooks"), list)
)
if not already:
    ups.append({"hooks": [{"type": "command", "command": cmd}]})
    with open(path, "w") as f:
        json.dump(data, f, indent=2); f.write("\n")
    print("  + registered Claude UserPromptSubmit hook -> settings.local.json")
else:
    print("  = Claude hook already present")
PY
}

register_zcode_hook() {
    local cfg="$TARGET/.zcode/config.json"
    local rel="${TARGET}/.zcode/scripts/plan-mode-context.zcode.sh"
    # Use ${ZCODE_PROJECT_DIR} so the path resolves regardless of clone location.
    local hookcmd='bash "${ZCODE_PROJECT_DIR}/.zcode/scripts/plan-mode-context.zcode.sh"'
    python3 - "$cfg" "$hookcmd" <<'PY'
import json, os, sys
path, cmd = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except json.JSONDecodeError: data = {}
hooks = data.setdefault("hooks", {})
hooks["enabled"] = True
events = hooks.setdefault("events", {})
ups = events.setdefault("UserPromptSubmit", [])
already = any(
    isinstance(h, dict) and h.get("command") == cmd
    for entry in ups if isinstance(entry, dict)
    for h in entry.get("hooks", []) if isinstance(entry.get("hooks"), list)
)
if not already:
    ups.append({"matcher": "", "hooks": [{"type": "command", "command": cmd, "timeout": 10}]})
    with open(path, "w") as f:
        json.dump(data, f, indent=2); f.write("\n")
    print("  + registered ZCode UserPromptSubmit hook -> .zcode/config.json")
else:
    print("  = ZCode hook already present")
PY
}

# Always install the universal scripts under .agents/scripts (real home).
install_scripts_to "$TARGET/.agents/scripts"

case "$AGENT_TARGET" in
    agents)
        # agents target has no per-tool hook config to write; the .agents/scripts
        # copy is available for any agent that supports UserPromptSubmit hooks.
        printf '  + scripts installed to .agents/scripts (no per-tool config for "agents" target)\n'
        ;;
    claude)
        install_scripts_to "$TARGET/.claude/scripts"
        register_claude_hook
        ;;
    zcode)
        mkdir -p "$TARGET/.zcode/scripts"
        cp "$TARGET/.agents/scripts/plan-mode-context.sh"     "$TARGET/.zcode/scripts/plan-mode-context.sh"
        cp "$TARGET/.agents/scripts/plan-mode-context.zcode.sh" "$TARGET/.zcode/scripts/plan-mode-context.zcode.sh"
        register_zcode_hook
        ;;
    all)
        install_scripts_to "$TARGET/.claude/scripts"
        register_claude_hook
        mkdir -p "$TARGET/.zcode/scripts"
        cp "$TARGET/.agents/scripts/plan-mode-context.sh"     "$TARGET/.zcode/scripts/plan-mode-context.sh"
        cp "$TARGET/.agents/scripts/plan-mode-context.zcode.sh" "$TARGET/.zcode/scripts/plan-mode-context.zcode.sh"
        register_zcode_hook
        ;;
    *)
        printf 'install-plan-hook: unknown target "%s" (use agents|zcode|claude|all)\n' "$AGENT_TARGET" >&2
        exit 1
        ;;
esac

printf '  ok plan-mode hook installed (target=%s)\n' "$AGENT_TARGET"
