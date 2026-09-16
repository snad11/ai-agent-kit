#!/usr/bin/env bash
# cline-init.sh — install the Cline kit into a target project.
#
# GENERATED FILE — do not edit by hand.
# Source: agent-kit/templates/kit-init.sh.template + agent-kit/kits.manifest
# Regenerate: bash agent-kit/kit-scaffold.sh
#
# Usage:
#     bash cline-init.sh [target-project-path]
#     bash cline-init.sh .
#
# Emits:
#     .clinerules/project-rules.md            rules (universal baseline + detected stack modules)
#     AGENTS.md           anchor file the agent reads, with memory cloned in
#     no slash-command format for this agent
#
# Does NOT: commit, modify source code, install dependencies, or run tests.

set -e

RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'; GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'; NC=$'\033[0m'; BOLD=$'\033[1m'

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_INPUT="${1:-.}"

if [ "$TARGET_INPUT" = "--help" ] || [ "$TARGET_INPUT" = "-h" ]; then
    cat <<EOF
${BOLD}cline-init.sh${NC} — install the Cline kit into a target project

${BOLD}Usage:${NC}
    bash cline-init.sh [target-path]

${BOLD}Emits:${NC}
    .clinerules/project-rules.md
    AGENTS.md
    no slash-command format for this agent

${BOLD}Examples:${NC}
    bash $KIT_DIR/cline-init.sh
    bash $KIT_DIR/cline-init.sh /path/to/project

${BOLD}After running:${NC}
    Reference @$KIT_DIR/BOOTSTRAP.md in Cline to finish the
    conversational phases (context, audits, memory).
EOF
    exit 0
fi

[ -d "$TARGET_INPUT" ] || { printf '%sTarget does not exist or is not a directory: %s%s\n' "$RED" "$TARGET_INPUT" "$NC" >&2; exit 1; }
TARGET="$(cd "$TARGET_INPUT" && pwd)"
PROJECT_NAME="$(basename "$TARGET")"

if [ "$KIT_DIR" = "$TARGET" ]; then
    printf '%sRefusing to install the kit into itself.%s\n' "$RED" "$NC" >&2
    exit 1
fi

MEMORY_KEY="$(printf '%s' "$TARGET" | sed 's|/|-|g')"
MEMORY_ROOT="$HOME/.agents/projects/${MEMORY_KEY}/memory"
export TARGET PROJECT_NAME MEMORY_ROOT
export AGENT_TARGET="cline"

printf '\n%sCline kit%s\n' "$BOLD" "$NC"
printf '  Kit:      %s\n' "$KIT_DIR"
printf '  Project:  %s\n' "$TARGET"
printf '  Memory:   %s\n\n' "$MEMORY_ROOT"

. "$KIT_DIR/scripts/_subst.sh"
. "$KIT_DIR/scripts/_detect_stacks.sh"

# ============================================================
# Directories
# ============================================================
mkdir -p "$(dirname "$TARGET/.clinerules/project-rules.md")"
mkdir -p "$(dirname "$TARGET/AGENTS.md")"
mkdir -p "$TARGET/.clinerules"


# ============================================================
# Scripts (agent-agnostic: precommit, hooks, workflow installers)
# ============================================================
printf '%sCopying scripts...%s\n' "$BOLD" "$NC"
SCRIPTS_DIR="$TARGET/.clinerules/scripts"
mkdir -p "$SCRIPTS_DIR"
for script in x-precommit.sh install-hooks.sh install-workflows.sh clone-memory.sh; do
    [ -f "$KIT_DIR/scripts/$script" ] || continue
    subst_copy "$KIT_DIR/scripts/$script" "$SCRIPTS_DIR/$script"
    chmod +x "$SCRIPTS_DIR/$script"
    printf '  %sok%s scripts/%s\n' "$GREEN" "$NC" "$script"
done

mkdir -p "$TARGET/.clinerules/workflows"
subst_copy "$KIT_DIR/workflows/x-check.yml" "$TARGET/.clinerules/workflows/x-check.yml"
printf '  %sok%s workflows/x-check.yml\n' "$GREEN" "$NC"

mkdir -p "$TARGET/.clinerules/templates"
subst_copy "$KIT_DIR/templates/audit-prompt.md" "$TARGET/.clinerules/templates/audit-prompt.md"
printf '  %sok%s templates/audit-prompt.md\n\n' "$GREEN" "$NC"

# ============================================================
# Rules
# ============================================================
printf '%sBuilding rules...%s\n' "$BOLD" "$NC"
RULES_OUT="$TARGET/.clinerules/project-rules.md"
STACKS="$(detect_stacks)"

build_rules_to() {
    local out="$1"
    local backup=""
    [ -f "$out" ] && { backup="${out}.bak.$(date +%Y%m%d-%H%M%S)"; cp "$out" "$backup"; }
    subst_copy "$KIT_DIR/rules/rules-baseline.md" "$out"
    if [ -n "${STACKS:-}" ]; then
        while IFS= read -r stack; do
            [ -z "$stack" ] && continue
            local module="$KIT_DIR/rules/${stack}.md"
            if [ -f "$module" ]; then
                printf '\n---\n\n' >> "$out"
                cat "$module" >> "$out"
                printf '  %sok%s appended %s\n' "$GREEN" "$NC" "$stack"
            else
                printf '  %swarn%s no module for %s\n' "$YELLOW" "$NC" "$stack"
            fi
        done <<< "$STACKS"
    fi
    [ -n "$backup" ] && printf '  %sbacked up prior rules to %s%s\n' "$BLUE" "$backup" "$NC"
    # Explicit success: on a fresh install $backup is empty, so the test above
    # returns 1 and would become this function's exit status under `set -e`.
    return 0
}
build_rules_to "$RULES_OUT"
printf '  %sok%s .clinerules/project-rules.md\n\n' "$GREEN" "$NC"

# ============================================================
# Commands / skills
# ============================================================
printf '%sSkills...%s\n' "$BOLD" "$NC"
printf '  %snote%s this agent has no slash-command format; the skills are\n' "$BLUE" "$NC"
printf '       described as workflows inside the anchor file instead.\n\n'

# ============================================================
# Memory baseline
# ============================================================
printf '%sSeeding memory baseline...%s\n' "$BOLD" "$NC"
mkdir -p "$MEMORY_ROOT"
if [ ! -f "$MEMORY_ROOT/feedback_seniority_and_workflow.md" ]; then
    subst_copy "$KIT_DIR/templates/feedback_seniority_and_workflow.md" "$MEMORY_ROOT/feedback_seniority_and_workflow.md"
    printf '  %sok%s seeded feedback_seniority_and_workflow.md\n\n' "$GREEN" "$NC"
else
    printf '  %sskip%s already present\n\n' "$YELLOW" "$NC"
fi

# ============================================================
# Anchor + memory clone
# ============================================================
printf '%sGenerating AGENTS.md...%s\n' "$BOLD" "$NC"
subst_copy "$KIT_DIR/templates/AGENTS.md.template" "$TARGET/AGENTS.md"
if ls "$MEMORY_ROOT"/*.md >/dev/null 2>&1; then
    bash "$SCRIPTS_DIR/clone-memory.sh" "$TARGET/AGENTS.md" "$MEMORY_ROOT" >/dev/null || \
        printf '  %swarn%s memory clone skipped\n' "$YELLOW" "$NC"
fi
printf '  %sok%s AGENTS.md (memory cloned)\n\n' "$GREEN" "$NC"


# ============================================================
# Plan-mode hook
# ============================================================
printf '%sPlan-mode hook...%s\n' "$BOLD" "$NC"
printf '  %snote%s this agent exposes no UserPromptSubmit hook; the context\n' "$BLUE" "$NC"
printf '       script is available but not auto-registered.\n\n'

# ============================================================
# Summary
# ============================================================
RULES_COUNT="$(grep -c '^### ' "$RULES_OUT" || true)"

cat <<EOF
${GREEN}${BOLD}OK cline-init complete${NC}

${BOLD}Installed at:${NC}
  ${TARGET}/AGENTS.md
  ${TARGET}/.clinerules/project-rules.md
  ${TARGET}/.clinerules/scripts/

${BOLD}Summary:${NC}
  Agent:      Cline
  Rules:      ${RULES_COUNT}
  Stacks:     ${STACKS:-universal only}
  Memory key: ${MEMORY_KEY}

${BOLD}Note:${NC} Reads .clinerules/ plus .cursorrules, .windsurfrules and AGENTS.md

${BOLD}Next steps:${NC}
  1. Finish the bootstrap conversationally — reference:
     ${BLUE}@${KIT_DIR}/BOOTSTRAP.md${NC}
  2. Install git hooks:  bash ${TARGET}/.clinerules/scripts/install-hooks.sh all
  3. Stage CI workflow:  bash ${TARGET}/.clinerules/scripts/install-workflows.sh all
EOF
