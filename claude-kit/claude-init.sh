#!/usr/bin/env bash
# claude-init.sh — Install the Claude Kit into a target project
#
# Usage:
#     bash claude-init.sh [target-project-path]
#     bash claude-init.sh .                        # current directory
#     bash claude-init.sh /path/to/other/project   # explicit path
#
# What it does:
#   1. Verifies the target is a directory and is sensible
#   2. Detects which stack rule modules to include (by looking for package.json, pubspec.yaml, etc.)
#   3. Creates .claude/ structure (skills, scripts, workflows)
#   4. Substitutes placeholders in every copied file
#   5. Builds .claude/rules.md from baseline + detected stack modules
#   6. Does NOT generate CLAUDE.md (Claude's conversational bootstrap does that — this script is called by Claude or run standalone for the file-copy step only)
#   7. Does NOT run audits (Claude's conversational bootstrap handles that)
#   8. Does NOT install git hooks (call install-hooks.sh separately)
#
# This script is the "mechanical" part of the bootstrap. The "conversational" part
# (gathering project context, running audits, generating CLAUDE.md, setting up memory)
# is handled by Claude following @claude-kit/BOOTSTRAP.md.
#
# You can run this script standalone to get the file structure in place, then run
# Claude + BOOTSTRAP.md to fill in the conversational pieces. Or let Claude run
# both end-to-end.

set -e

# ============================================================
# Colors
# ============================================================

RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'
BOLD=$'\033[1m'

if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
    RED=""; YELLOW=""; GREEN=""; BLUE=""; NC=""; BOLD=""
fi

# ============================================================
# Paths
# ============================================================

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_INPUT="${1:-.}"

if [ "$TARGET_INPUT" = "." ]; then
    TARGET="$(pwd)"
else
    TARGET="$(cd "$TARGET_INPUT" 2>/dev/null && pwd)" || {
        printf "${RED}❌ Target does not exist or is not a directory: %s${NC}\n" "$TARGET_INPUT" >&2
        exit 1
    }
fi

PROJECT_NAME="$(basename "$TARGET")"

# ============================================================
# Help
# ============================================================

print_help() {
    cat <<EOF
${BOLD}claude-init.sh${NC} — Install Claude Kit into a target project

${BOLD}Usage:${NC}
    bash claude-init.sh [target-path]

${BOLD}Arguments:${NC}
    target-path    Path to the target project (default: current directory)

${BOLD}What it does:${NC}
    1. Detects stack (Node, Flutter, PHP, Python, Go, Ruby, Java)
    2. Creates target/.claude/ structure
    3. Copies skills + scripts + workflows with placeholder substitution
    4. Builds target/.claude/rules.md from baseline + detected stack modules
    5. Does NOT run audits, gather context, create CLAUDE.md, or install hooks
       (those are handled by Claude following BOOTSTRAP.md conversationally)

${BOLD}What it does NOT do:${NC}
    - Commit anything
    - Modify code in the target project
    - Install npm/yarn/composer/pip deps
    - Generate CLAUDE.md (Claude conversational step)
    - Run audits (Claude conversational step)

${BOLD}Examples:${NC}
    bash /Users/mac/Projects/.ai/claude-kit/claude-init.sh
    bash /Users/mac/Projects/.ai/claude-kit/claude-init.sh .
    bash /Users/mac/Projects/.ai/claude-kit/claude-init.sh /path/to/other/project

${BOLD}After running this script:${NC}
    1. The target has .claude/ populated and rules.md built
    2. Open Claude Code in the target directory
    3. Reference @/Users/mac/Projects/.ai/claude-kit/BOOTSTRAP.md to continue with
       conversational phases (discovery, context gathering, audits, CLAUDE.md,
       memory, hooks, workflows)
EOF
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    print_help
    exit 0
fi

# ============================================================
# Sanity checks
# ============================================================

if [ "$KIT_DIR" = "$TARGET" ]; then
    printf "${RED}❌ Cannot bootstrap the kit into itself. Target must be a different project.${NC}\n" >&2
    exit 1
fi

if [ -d "$TARGET/.claude" ] && [ -z "${FORCE:-}" ]; then
    printf "${YELLOW}⚠ %s/.claude already exists.${NC}\n" "$TARGET"
    printf "  Re-run with FORCE=1 to overwrite existing files (existing rules.md will be backed up to /tmp).\n"
    exit 1
fi

# ============================================================
# Stack detection
# ============================================================

detect_stacks() {
    local detected=()

    # Backend stacks
    if find "$TARGET" -maxdepth 3 -name "package.json" -not -path "*/node_modules/*" | head -1 | grep -q .; then
        # Node — distinguish Next.js / NestJS / generic
        if find "$TARGET" -maxdepth 4 -name "nest-cli.json" 2>/dev/null | head -1 | grep -q .; then
            detected+=("backend-nestjs")
        fi
        if find "$TARGET" -maxdepth 4 -name "next.config.*" 2>/dev/null | head -1 | grep -q .; then
            detected+=("frontend-next")
        elif find "$TARGET" -maxdepth 4 -name "nuxt.config.*" 2>/dev/null | head -1 | grep -q .; then
            detected+=("frontend-nuxt")
            detected+=("frontend-vue")
        # Generic React / Vue on Vite (without Next/Nuxt): detect via vite.config + the framework dep
        elif find "$TARGET" -maxdepth 4 -name "vite.config.*" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q .; then
            if find "$TARGET" -maxdepth 4 -name "package.json" -not -path "*/node_modules/*" -exec grep -l '"react"' {} \; 2>/dev/null | head -1 | grep -q .; then
                detected+=("frontend-react")
            elif find "$TARGET" -maxdepth 4 -name "package.json" -not -path "*/node_modules/*" -exec grep -l '"vue"' {} \; 2>/dev/null | head -1 | grep -q .; then
                detected+=("frontend-vue")
            fi
        fi
    fi

    if find "$TARGET" -maxdepth 3 -name "composer.json" 2>/dev/null | head -1 | grep -q .; then
        if find "$TARGET" -maxdepth 4 -name "artisan" 2>/dev/null | head -1 | grep -q .; then
            detected+=("backend-laravel")
        fi
    fi

    # Python: Django (manage.py) → django; else FastAPI (fastapi dependency) → fastapi
    if find "$TARGET" -maxdepth 4 -name "manage.py" 2>/dev/null | head -1 | grep -q .; then
        detected+=("backend-django")
    elif grep -rIl --include="pyproject.toml" --include="requirements*.txt" -e "fastapi" "$TARGET" 2>/dev/null | head -1 | grep -q .; then
        detected+=("backend-fastapi")
    fi

    # Mobile stacks
    if find "$TARGET" -maxdepth 3 -name "pubspec.yaml" 2>/dev/null | head -1 | grep -q .; then
        detected+=("mobile-flutter")
    fi

    if find "$TARGET" -maxdepth 3 -name "app.json" 2>/dev/null | head -1 | grep -q .; then
        # Could be Expo / RN — check for React Native indicators
        if grep -l "react-native" "$TARGET"/package.json 2>/dev/null | head -1 | grep -q .; then
            detected+=("mobile-react-native")
        fi
    fi

    printf "%s\n" "${detected[@]}"
}

STACKS=$(detect_stacks)

printf "${BOLD}claude-init: bootstrapping ${BLUE}%s${NC}\n\n" "$PROJECT_NAME"
printf "  Target:   %s\n" "$TARGET"
printf "  Kit:      %s\n" "$KIT_DIR"
printf "  Detected: %s\n\n" "${STACKS:-none (universal baseline only)}"

# ============================================================
# Compute memory key
# ============================================================

# Convert /Users/mac/Projects/myapp → -Users-mac-Projects-myapp
MEMORY_KEY=$(echo "$TARGET" | sed 's|/|-|g')
MEMORY_ROOT="$HOME/.claude/projects/${MEMORY_KEY}/memory"

printf "${BOLD}Memory will live at:${NC} %s\n\n" "$MEMORY_ROOT"

# ============================================================
# Create directory structure
# ============================================================

printf "${BOLD}Creating directory structure...${NC}\n"
mkdir -p "$TARGET/.claude/skills"
mkdir -p "$TARGET/.claude/scripts"
mkdir -p "$TARGET/.claude/workflows"
printf "  ${GREEN}✓${NC} .claude/skills/\n"
printf "  ${GREEN}✓${NC} .claude/scripts/\n"
printf "  ${GREEN}✓${NC} .claude/workflows/\n\n"

# ============================================================
# Copy + substitute helper (shared with claude-sync.sh)
# ============================================================

# shellcheck source=scripts/_subst.sh
. "$KIT_DIR/scripts/_subst.sh"

# ============================================================
# Copy skills
# ============================================================

printf "${BOLD}Copying skills...${NC}\n"
for skill_dir in "$KIT_DIR/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    mkdir -p "$TARGET/.claude/skills/$skill_name"
    subst_copy "$skill_dir/SKILL.md" "$TARGET/.claude/skills/$skill_name/SKILL.md"
    printf "  ${GREEN}✓${NC} skills/%s/SKILL.md\n" "$skill_name"
done
printf "\n"

# ============================================================
# Copy scripts
# ============================================================

printf "${BOLD}Copying scripts...${NC}\n"
for script in x-precommit.sh install-hooks.sh install-workflows.sh; do
    subst_copy "$KIT_DIR/scripts/$script" "$TARGET/.claude/scripts/$script"
    chmod +x "$TARGET/.claude/scripts/$script"
    printf "  ${GREEN}✓${NC} scripts/%s\n" "$script"
done
printf "\n"

# ============================================================
# Copy workflow
# ============================================================

printf "${BOLD}Copying workflows...${NC}\n"
subst_copy "$KIT_DIR/workflows/x-check.yml" "$TARGET/.claude/workflows/x-check.yml"
printf "  ${GREEN}✓${NC} workflows/x-check.yml\n\n"

# ============================================================
# Copy templates the skills read at runtime
# ============================================================

# Shipped into the project so the skills resolve them repo-relatively. Referencing the
# kit by absolute path would break on any other machine — and leak a local path into a
# repo that may well be published.
printf "${BOLD}Copying templates...${NC}\n"
mkdir -p "$TARGET/.claude/templates"
subst_copy "$KIT_DIR/templates/audit-prompt.md" "$TARGET/.claude/templates/audit-prompt.md"
printf "  ${GREEN}✓${NC} templates/audit-prompt.md\n\n"

# ============================================================
# Install plan-mode hook
# ============================================================

printf "${BOLD}Installing plan-mode hook...${NC}\n"
bash "$KIT_DIR/scripts/install-plan-hook.sh" "$TARGET"
printf "\n"

# ============================================================
# Build rules.md
# ============================================================

printf "${BOLD}Building rules.md...${NC}\n"
RULES_TARGET="$TARGET/.claude/rules.md"

# Backup existing rules if present
if [ -f "$RULES_TARGET" ]; then
    backup="/tmp/claude-kit-rules-backup-$(date +%Y%m%d-%H%M%S).md"
    cp "$RULES_TARGET" "$backup"
    printf "  ${BLUE}backed up existing rules to %s${NC}\n" "$backup"
fi

# Start with baseline
subst_copy "$KIT_DIR/rules/rules-baseline.md" "$RULES_TARGET"
printf "  ${GREEN}✓${NC} baseline (rules-baseline.md)\n"

# Append detected stack modules
if [ -n "$STACKS" ]; then
    while IFS= read -r stack; do
        [ -z "$stack" ] && continue
        module_file="$KIT_DIR/rules/${stack}.md"
        if [ -f "$module_file" ]; then
            printf "\n---\n\n" >> "$RULES_TARGET"
            cat "$module_file" >> "$RULES_TARGET"
            printf "  ${GREEN}✓${NC} appended %s\n" "$stack"
        else
            printf "  ${YELLOW}⚠${NC} no module for %s (add one at %s)\n" "$stack" "$module_file"
        fi
    done <<< "$STACKS"
fi
printf "\n"

# ============================================================
# Summary
# ============================================================

RULES_COUNT=$(grep -c "^### " "$RULES_TARGET")
SKILLS_COUNT=$(find "$TARGET/.claude/skills" -name "SKILL.md" | wc -l | tr -d ' ')

cat <<EOF
${GREEN}${BOLD}✅ claude-init complete${NC}

${BOLD}Installed at:${NC}
  ${TARGET}/.claude/

${BOLD}Summary:${NC}
  Skills:     ${SKILLS_COUNT}
  Rules:      ${RULES_COUNT}
  Stacks:     ${STACKS:-universal only}
  Memory key: ${MEMORY_KEY}

${BOLD}Next steps:${NC}

  ${BOLD}1. Continue the bootstrap with Claude Code (conversational):${NC}
     Open Claude Code in ${TARGET} and reference:
     ${BLUE}@/Users/mac/Projects/.ai/claude-kit/BOOTSTRAP.md${NC}

     This will:
     - Ask you about the project scope / context
     - Run the audit pass on your repos
     - Generate CLAUDE.md
     - Set up memory files at ${MEMORY_ROOT}
     - Install git pre-commit hooks
     - Stage .github/ workflow files

  ${BOLD}2. OR do the manual steps yourself:${NC}
     - Write ${TARGET}/CLAUDE.md (see ${KIT_DIR}/templates/CLAUDE.md.template)
     - mkdir -p ${MEMORY_ROOT}
     - Copy ${KIT_DIR}/templates/feedback_seniority_and_workflow.md to ${MEMORY_ROOT}/
     - Install hooks: ${BLUE}bash ${TARGET}/.claude/scripts/install-hooks.sh all${NC}
     - Stage workflow: ${BLUE}bash ${TARGET}/.claude/scripts/install-workflows.sh all${NC}

  ${BOLD}3. Restart Claude Code${NC} so the new skills load, then try:
     ${BLUE}/x-rules${NC}        (list all rules)
     ${BLUE}/x-check${NC}        (audit uncommitted changes)
     ${BLUE}/x-implement${NC}    (canonical work command)

EOF
