#!/usr/bin/env bash
# agent-sync.sh — propagate kit updates into an already-bootstrapped project.
#
# Usage:  bash agent-sync.sh <project-path> [--target agents|zcode|claude|all]
#
# What it does:
#   1. Overwrites <project>/.agents/skills/*/SKILL.md with the kit's latest
#      (skills are kit-managed; per-project customization is not supported).
#      Mirrors to .claude/skills when that target is active.
#   2. Rebuilds <project>/.agents/rules.md from:
#        rules-baseline.md + detected stack modules + preserved project additions.
#      Project additions = everything below the sentinel
#        <!-- kit-managed above — project rules below -->
#      If the sentinel is missing (first sync), the existing file is backed up
#      and a fresh file is written WITHOUT any project additions — review the
#      backup diff to re-apply. Mirrors to .claude/rules.md when active.
#   3. Refreshes templates/audit-prompt.md and the scripts under .agents/scripts.
#   4. Refreshes the plan-mode hook registration (target-aware).
#   5. Re-clones memory into AGENTS.md (so new/edited memory files appear in-context).
#   6. Seeds feedback_seniority_and_workflow.md into the project's memory dir
#      only if missing (never overwrites).
#   7. Does NOT touch CLAUDE.md, MEMORY.md, other memory files, or the
#      precommit/workflow scripts — those are project-owned.
#
# Default target is read from the project (presence of .zcode / .claude); falls
# back to "agents". Pass --target to force.

set -euo pipefail

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; BLUE=$'\033[0;34m'
BOLD=$'\033[1m'; NC=$'\033[0m'

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-}"
shift || true
AGENT_TARGET=""
while [ $# -gt 0 ]; do
    case "$1" in
        --target) AGENT_TARGET="$2"; shift 2 ;;
        --target=*) AGENT_TARGET="${1#--target=}"; shift ;;
        *) shift ;;
    esac
done

if [ -z "$TARGET" ]; then
    printf '%sUsage: bash agent-sync.sh <project-path> [--target agents|zcode|claude|all]%s\n' "$RED" "$NC" >&2
    exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

if [ "$KIT_DIR" = "$TARGET" ]; then
    printf '%sRefusing to sync kit into itself.%s\n' "$RED" "$NC" >&2; exit 1
fi
if [ ! -d "$TARGET/.agents" ]; then
    printf '%s%s has no .agents/ — run agent-init.sh first.%s\n' "$RED" "$TARGET" "$NC" >&2; exit 1
fi

# Infer target if not given.
if [ -z "$AGENT_TARGET" ]; then
    if [ -d "$TARGET/.claude" ] && [ -d "$TARGET/.zcode" ]; then AGENT_TARGET=all
    elif [ -d "$TARGET/.zcode" ]; then AGENT_TARGET=zcode
    elif [ -d "$TARGET/.claude" ]; then AGENT_TARGET=claude
    else AGENT_TARGET=agents; fi
fi

SENTINEL='<!-- kit-managed above — project rules below -->'
TS="$(date +%Y%m%d-%H%M%S)"

PROJECT_NAME="$(basename "$TARGET")"
MEMORY_KEY="$(printf '%s' "$TARGET" | sed 's|/|-|g')"
MEMORY_ROOT="$HOME/.agents/projects/${MEMORY_KEY}/memory"

# shellcheck source=scripts/_subst.sh
. "$KIT_DIR/scripts/_subst.sh"

printf '%sagent-sync -> %s  (target=%s)%s\n\n' "$BOLD" "$TARGET" "$AGENT_TARGET" "$NC"

# -----------------------------------------------------------------------------
# 1) Skills + templates + scripts
# -----------------------------------------------------------------------------
printf '%sSyncing skills...%s\n' "$BOLD" "$NC"
sync_skill_to() {
    local home="$1"
    for skill_dir in "$KIT_DIR/skills"/*/; do
        skill_name="$(basename "$skill_dir")"
        mkdir -p "$home/$skill_name"
        subst_copy "$skill_dir/SKILL.md" "$home/$skill_name/SKILL.md"
    done
}
sync_skill_to "$TARGET/.agents/skills"
printf '  %sok%s .agents/skills\n' "$GREEN" "$NC"
case "$AGENT_TARGET" in claude|all)
    sync_skill_to "$TARGET/.claude/skills"
    printf '  %sok%s .claude/skills (mirror)\n' "$GREEN" "$NC" ;;
esac
case "$AGENT_TARGET" in zcode|all)
    # Symlinks just need to exist; recreate to be safe.
    mkdir -p "$TARGET/.zcode/skills"
    for skill_dir in "$KIT_DIR/skills"/*/; do
        skill_name="$(basename "$skill_dir")"
        ln -sfn "../../.agents/skills/$skill_name" "$TARGET/.zcode/skills/$skill_name"
    done
    printf '  %sok%s .zcode/skills (symlinks refreshed)\n' "$GREEN" "$NC" ;;
esac

printf '%sSyncing templates + scripts...%s\n' "$BOLD" "$NC"
mkdir -p "$TARGET/.agents/templates" "$TARGET/.agents/scripts"
subst_copy "$KIT_DIR/templates/audit-prompt.md" "$TARGET/.agents/templates/audit-prompt.md"
for script in x-precommit.sh install-hooks.sh install-workflows.sh plan-mode-context.sh plan-mode-context.zcode.sh clone-memory.sh install-plan-hook.sh; do
    [ -f "$KIT_DIR/scripts/$script" ] || continue
    subst_copy "$KIT_DIR/scripts/$script" "$TARGET/.agents/scripts/$script"
    chmod +x "$TARGET/.agents/scripts/$script"
done
printf '  %sok%s templates/audit-prompt.md + scripts\n\n' "$GREEN" "$NC"

# -----------------------------------------------------------------------------
# 2) Rebuild rules.md (preserve project tail below sentinel)
# -----------------------------------------------------------------------------
. "$KIT_DIR/scripts/_detect_stacks.sh"
STACKS="$(detect_stacks)"
printf '%sRebuilding rules.md...%s (detected: %s)\n' "$BOLD" "$NC" "${STACKS:-(none)}"

RULES_TARGET="$TARGET/.agents/rules.md"
PROJECT_TAIL=""
if [ -f "$RULES_TARGET" ]; then
    backup="/tmp/agent-kit-rules-sync-${TS}.md"
    cp "$RULES_TARGET" "$backup"
    printf '  backed up existing -> %s%s%s\n' "$BLUE" "$backup" "$NC"
    if grep -qF "$SENTINEL" "$RULES_TARGET"; then
        PROJECT_TAIL="$(awk -v s="$SENTINEL" 'found{print} index($0,s){found=1}' "$RULES_TARGET")"
        printf '  preserved %s lines of project-added rules\n' "$(printf '%s\n' "$PROJECT_TAIL" | wc -l | tr -d ' ')"
    else
        printf '  %swarn%s no sentinel — writing fresh (review backup to re-apply custom rules)\n' "$YELLOW" "$NC"
    fi
fi

subst_copy "$KIT_DIR/rules/rules-baseline.md" "$RULES_TARGET"
if [ -n "${STACKS:-}" ]; then
    while IFS= read -r stack; do
        [ -z "$stack" ] && continue
        module="$KIT_DIR/rules/${stack}.md"
        if [ -f "$module" ]; then
            printf '\n---\n\n' >> "$RULES_TARGET"
            cat "$module" >> "$RULES_TARGET"
            printf '  %sok%s appended %s\n' "$GREEN" "$NC" "$stack"
        fi
    done <<< "$STACKS"
fi
{
    printf '\n---\n\n%s\n\n' "$SENTINEL"
    printf '<!-- Add project-specific rules below. Anything below the sentinel survives agent-sync.sh runs. -->\n'
    [ -n "$PROJECT_TAIL" ] && { printf '\n%s\n' "$PROJECT_TAIL"; }
} >> "$RULES_TARGET"
printf '  %sok%s rules.md rebuilt (%s rules)\n' "$GREEN" "$NC" "$(grep -c '^### ' "$RULES_TARGET")"

case "$AGENT_TARGET" in claude|all)
    cp "$RULES_TARGET" "$TARGET/.claude/rules.md"
    printf '  %sok%s .claude/rules.md (mirror)\n' "$GREEN" "$NC" ;;
esac
printf '\n'

# -----------------------------------------------------------------------------
# 3) Memory baseline (seed if missing) + re-clone into AGENTS.md
# -----------------------------------------------------------------------------
mkdir -p "$MEMORY_ROOT"
if [ ! -f "$MEMORY_ROOT/feedback_seniority_and_workflow.md" ]; then
    subst_copy "$KIT_DIR/templates/feedback_seniority_and_workflow.md" "$MEMORY_ROOT/feedback_seniority_and_workflow.md"
    printf '%sMemory:%s seeded feedback_seniority_and_workflow.md\n' "$BOLD" "$NC"
else
    printf '%sMemory:%s feedback_seniority_and_workflow.md already present — skipped\n' "$BOLD" "$NC"
fi

printf '%sRe-cloning memory into AGENTS.md...%s\n' "$BOLD" "$NC"
if [ -f "$TARGET/AGENTS.md" ] && ls "$MEMORY_ROOT"/*.md >/dev/null 2>&1; then
    bash "$TARGET/.agents/scripts/clone-memory.sh" "$TARGET/AGENTS.md" "$MEMORY_ROOT"
else
    printf '  %sskip%s (AGENTS.md or memory dir missing)\n' "$YELLOW" "$NC"
fi

# -----------------------------------------------------------------------------
# 4) Plan-mode hook (target-aware, idempotent)
# -----------------------------------------------------------------------------
printf '\n%sPlan-mode hook...%s\n' "$BOLD" "$NC"
bash "$KIT_DIR/scripts/install-plan-hook.sh" "$TARGET" "$AGENT_TARGET"

printf '\n%s%sOK sync complete%s\n' "$GREEN" "$BOLD" "$NC"
printf '  review diff: %sgit -C %s diff%s\n' "$BLUE" "$TARGET" "$NC"
