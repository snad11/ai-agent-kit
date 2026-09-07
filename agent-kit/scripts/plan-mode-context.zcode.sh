#!/usr/bin/env bash
# plan-mode-context.zcode.sh — ZCode adapter for the plan-mode context hook.
#
# The canonical script (plan-mode-context.sh) emits plain text to stdout (the
# Claude Code UserPromptSubmit contract). ZCode parses hook stdout as strict
# JSON and discards anything else, so this adapter runs the canonical script
# and reformats its output as {"additionalContext": "<text>"}.
#
# The canonical script already gates itself on permission_mode == "plan" and
# exits 0 with empty output otherwise, so this wrapper inherits that behavior:
# nothing is injected outside plan mode.
#
# Registered by install-plan-hook.sh (target=zcode) into <project>/.zcode/config.json.
# Do not duplicate the planning standard here; edit plan-mode-context.sh.

set -euo pipefail

# Resolve the canonical script relative to this adapter (sibling file).
CANONICAL="$(dirname "$0")/plan-mode-context.sh"
# Fall back to the agent-kit copy if not co-located (e.g. run from the kit itself).
[ -f "$CANONICAL" ] || CANONICAL="$(dirname "$0")/../scripts/plan-mode-context.sh"

text="$(bash "$CANONICAL")"

# Empty output (non-plan mode) -> emit nothing, exit 0. An empty additionalContext
# would add a blank turn; skipping entirely is cleaner.
if [ -z "$text" ]; then
    exit 0
fi

python3 -c 'import sys, json; print(json.dumps({"additionalContext": sys.stdin.read()}))' <<<"$text"
