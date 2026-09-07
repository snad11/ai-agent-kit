#!/usr/bin/env bash
# claude-sync.sh — propagate kit updates into an already-bootstrapped project
#
# Usage:  bash /Users/mac/Projects/.ai/claude-kit/claude-sync.sh <project-path>
#
# What it does:
#   1. Overwrites <project>/.claude/skills/*/SKILL.md with the kit's latest
#      (skills are kit-managed; per-project customization is not supported)
#   2. Rebuilds <project>/.claude/rules.md from:
#        rules-baseline.md + detected stack modules + preserved project additions
#      Project additions = everything below the sentinel
#        <!-- kit-managed above — project rules below -->
#      If the sentinel is missing (first sync), the existing file is backed up
#      and a fresh file is written WITHOUT any project additions — review the
#      backup diff to re-apply.
#   3. Copies templates/feedback_seniority_and_workflow.md into the project's
#      memory dir only if missing (never overwrites).
#   4. Installs/refreshes the plan-mode hook via install-plan-hook.sh
#      (copies .claude/scripts/plan-mode-context.sh + registers the
#      UserPromptSubmit hook in settings.local.json, idempotently).
#   5. Does NOT touch CLAUDE.md, MEMORY.md, other memory files, or the
#      precommit/workflow scripts — those are project-owned.
#
# Stack detection re-uses the same logic as claude-init.sh.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'
BOLD='\033[1m'; NC='\033[0m'

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-}"

if [ -z "$TARGET" ]; then
    printf "${RED}Usage: bash claude-sync.sh <project-path>${NC}\n" >&2
    exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

if [ "$KIT_DIR" = "$TARGET" ]; then
    printf "${RED}❌ Refusing to sync kit into itself.${NC}\n" >&2
    exit 1
fi
if [ ! -d "$TARGET/.claude" ]; then
    printf "${RED}❌ %s has no .claude/ — run claude-init.sh first.${NC}\n" "$TARGET" >&2
    exit 1
fi

SENTINEL='<!-- kit-managed above — project rules below -->'
TS="$(date +%Y%m%d-%H%M%S)"

# Needed by subst_copy, and computed the same way claude-init.sh does it.
PROJECT_NAME="$(basename "$TARGET")"
MEMORY_KEY="$(printf '%s' "$TARGET" | sed 's|/|-|g')"
MEMORY_ROOT="$HOME/.claude/projects/${MEMORY_KEY}/memory"

# shellcheck source=scripts/_subst.sh
. "$KIT_DIR/scripts/_subst.sh"

printf "${BOLD}claude-sync → %s${NC}\n\n" "$TARGET"

# -----------------------------------------------------------------------------
# 1) Skills
# -----------------------------------------------------------------------------
printf "${BOLD}Syncing skills...${NC}\n"
mkdir -p "$TARGET/.claude/skills"
for skill_dir in "$KIT_DIR/skills"/*/; do
    skill_name="$(basename "$skill_dir")"
    mkdir -p "$TARGET/.claude/skills/$skill_name"
    subst_copy "$skill_dir/SKILL.md" "$TARGET/.claude/skills/$skill_name/SKILL.md"
    printf "  ${GREEN}✓${NC} skills/%s/SKILL.md\n" "$skill_name"
done
printf "\n"

printf "${BOLD}Syncing templates...${NC}\n"
mkdir -p "$TARGET/.claude/templates"
subst_copy "$KIT_DIR/templates/audit-prompt.md" "$TARGET/.claude/templates/audit-prompt.md"
printf "  ${GREEN}✓${NC} templates/audit-prompt.md\n\n"

# -----------------------------------------------------------------------------
# 2) Rebuild rules.md
# -----------------------------------------------------------------------------
RULES_TARGET="$TARGET/.claude/rules.md"

# Detect stacks (same logic as init, simplified — reads what the project has)
. "$KIT_DIR/scripts/_detect_stacks.sh"
STACKS="$(detect_stacks)"

printf "${BOLD}Rebuilding rules.md...${NC}\n"
printf "  detected stacks: ${BLUE}%s${NC}\n" "${STACKS:-(none)}"

# Extract project additions (below sentinel) if present
PROJECT_TAIL=""
if [ -f "$RULES_TARGET" ]; then
    backup="/tmp/claude-kit-rules-sync-${TS}.md"
    cp "$RULES_TARGET" "$backup"
    printf "  backed up existing → ${BLUE}%s${NC}\n" "$backup"
    if grep -qF "$SENTINEL" "$RULES_TARGET"; then
        PROJECT_TAIL="$(awk -v s="$SENTINEL" 'found{print} index($0,s){found=1}' "$RULES_TARGET")"
        lines="$(printf '%s\n' "$PROJECT_TAIL" | wc -l | tr -d ' ')"
        printf "  preserved %s lines of project-added rules\n" "$lines"
    else
        printf "  ${YELLOW}⚠ no sentinel found — writing fresh (review backup to re-apply any custom rules)${NC}\n"
    fi
fi

# Rebuild
subst_copy "$KIT_DIR/rules/rules-baseline.md" "$RULES_TARGET"
if [ -n "$STACKS" ]; then
    while IFS= read -r stack; do
        [ -z "$stack" ] && continue
        module="$KIT_DIR/rules/${stack}.md"
        if [ -f "$module" ]; then
            printf "\n---\n\n" >> "$RULES_TARGET"
            cat "$module" >> "$RULES_TARGET"
            printf "  ${GREEN}✓${NC} appended %s\n" "$stack"
        fi
    done <<< "$STACKS"
fi
{
    printf "\n---\n\n"
    printf "%s\n\n" "$SENTINEL"
    printf "<!-- Add project-specific rules below. Anything below the sentinel survives \`claude-sync.sh\` runs. -->\n"
    if [ -n "$PROJECT_TAIL" ]; then
        printf "\n"
        printf "%s\n" "$PROJECT_TAIL"
    fi
} >> "$RULES_TARGET"
printf "  ${GREEN}✓${NC} rules.md rebuilt (%s rules)\n\n" "$(grep -c '^### ' "$RULES_TARGET")"

# -----------------------------------------------------------------------------
# 3) Memory baseline (only if missing)
# -----------------------------------------------------------------------------
# Derive memory dir from project path — same rule as init
mkdir -p "$MEMORY_ROOT"
if [ ! -f "$MEMORY_ROOT/feedback_seniority_and_workflow.md" ]; then
    subst_copy "$KIT_DIR/templates/feedback_seniority_and_workflow.md" "$MEMORY_ROOT/feedback_seniority_and_workflow.md"
    printf "${BOLD}Memory:${NC} seeded feedback_seniority_and_workflow.md\n"
else
    printf "${BOLD}Memory:${NC} feedback_seniority_and_workflow.md already present — skipped\n"
fi

# -----------------------------------------------------------------------------
# 4) Plan-mode hook (idempotent)
# -----------------------------------------------------------------------------
printf "\n${BOLD}Plan-mode hook...${NC}\n"
bash "$KIT_DIR/scripts/install-plan-hook.sh" "$TARGET"

printf "\n${GREEN}${BOLD}✅ sync complete${NC}\n"
printf "  review diff: ${BLUE}git -C %s diff .claude${NC}\n" "$TARGET"
