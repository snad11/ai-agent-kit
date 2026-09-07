#!/usr/bin/env bash
# agent-init.sh — Install the Agent Kit into a target project (multi-agent).
#
# Usage:
#     bash agent-init.sh [target-project-path] [--target agents|zcode|claude|all]
#     bash agent-init.sh . --target all
#     bash agent-init.sh /path/to/project --target zcode
#
# What it does (the "mechanical" part of the bootstrap):
#   1. Detects which stack rule modules to include (package.json, pubspec.yaml, ...)
#   2. Emits the agent dirs for the chosen target:
#        agents (default) -> AGENTS.md + .agents/{skills,scripts,rules.md,workflows,templates}
#        zcode            -> above + .zcode/{skills(symlinks),scripts,config.json}
#        claude           -> CLAUDE.md + .claude/{skills,scripts,rules.md,workflows,templates}
#        all              -> everything (AGENTS.md + CLAUDE.md + .agents + .zcode + .claude)
#   3. Substitutes placeholders in every copied file
#   4. Builds rules.md from baseline + detected stack modules
#   5. Generates AGENTS.md from the template + clones memory verbatim into it
#   6. Installs the plan-mode hook (target-aware)
#   7. Does NOT run audits / gather context (the conversational BOOTSTRAP.md does that)
#   8. Does NOT install git hooks (call install-hooks.sh separately)
#   9. Does NOT commit anything
#
# This is the generalized port of claude-kit/claude-init.sh. The "conversational"
# pieces (project context, audits, memory authoring) are handled by an agent
# following @agent-kit/BOOTSTRAP.md.

set -e

# ============================================================
# Colors
# ============================================================
RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'; GREEN=$'\033[0;32m'; BLUE=$'\033[0;34m'
NC=$'\033[0m'; BOLD=$'\033[1m'
if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
    RED=""; YELLOW=""; GREEN=""; BLUE=""; NC=""; BOLD=""
fi

# ============================================================
# Defaults + arg parsing
# ============================================================
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_INPUT="."
AGENT_TARGET="agents"

while [ $# -gt 0 ]; do
    case "$1" in
        --target) AGENT_TARGET="$2"; shift 2 ;;
        --target=*) AGENT_TARGET="${1#--target=}"; shift ;;
        --help|-h) AGENT_TARGET="__help__"; shift ;;
        *) TARGET_INPUT="$1"; shift ;;
    esac
done

print_help() {
    cat <<EOF
${BOLD}agent-init.sh${NC} — Install the Agent Kit into a target project (multi-agent)

${BOLD}Usage:${NC}
    bash agent-init.sh [target-path] [--target agents|zcode|claude|all]

${BOLD}Arguments:${NC}
    target-path    Path to the target project (default: current directory)
    --target T     Which agent output(s) to emit (default: agents)

${BOLD}Targets:${NC}
    agents   AGENTS.md + .agents/{skills,scripts,rules.md,...}     [ZCode, Codex, Cursor, any AGENTS.md reader]
    zcode    above + .zcode/{skills(symlinks),scripts,config.json} [ZCode native]
    claude   CLAUDE.md + .claude/{skills,scripts,rules.md,...}     [Claude Code]
    all      everything (AGENTS.md + CLAUDE.md + .agents + .zcode + .claude)

${BOLD}What it does NOT do:${NC}
    - Commit anything
    - Modify code in the target project
    - Install deps, run tests, run audits, or author memory content
      (the conversational BOOTSTRAP.md handles context + audits + memory)

${BOLD}Examples:${NC}
    bash agent-init.sh --target all
    bash agent-init.sh . --target zcode
    bash agent-init.sh /path/to/project --target claude

${BOLD}After running:${NC}
    Reference @$(basename "$KIT_DIR")/BOOTSTRAP.md to continue with the
    conversational phases (discovery, context, audits, memory).
EOF
}

if [ "$AGENT_TARGET" = "__help__" ]; then print_help; exit 0; fi
case "$AGENT_TARGET" in
    agents|zcode|claude|all) : ;;
    *) printf '%sunknown target "%s" (use agents|zcode|claude|all)%s\n' "$RED" "$AGENT_TARGET" "$NC" >&2; exit 1 ;;
esac

# Resolve TARGET
if [ "$TARGET_INPUT" = "." ]; then
    TARGET="$(pwd)"
else
    TARGET="$(cd "$TARGET_INPUT" 2>/dev/null && pwd)" || {
        printf '%sTarget does not exist or is not a directory: %s%s\n' "$RED" "$TARGET_INPUT" "$NC" >&2
        exit 1
    }
fi
PROJECT_NAME="$(basename "$TARGET")"

# ============================================================
# Sanity checks
# ============================================================
if [ "$KIT_DIR" = "$TARGET" ]; then
    printf '%sCannot bootstrap the kit into itself.%s\n' "$RED" "$NC" >&2; exit 1
fi
# .agents/ is the universal marker that the kit already ran.
if [ -d "$TARGET/.agents" ] && [ -z "${FORCE:-}" ]; then
    printf '%s%s/.agents already exists.%s Re-run with FORCE=1 to overwrite, or use agent-sync.sh.\n' "$YELLOW" "$TARGET" "$NC" >&2
    exit 1
fi

# ============================================================
# Stack detection (same logic as claude-kit)
# ============================================================
detect_stacks() {
    local detected=()
    if find "$TARGET" -maxdepth 3 -name "package.json" -not -path "*/node_modules/*" | head -1 | grep -q .; then
        if find "$TARGET" -maxdepth 4 -name "nest-cli.json" 2>/dev/null | head -1 | grep -q .; then detected+=("backend-nestjs"); fi
        if find "$TARGET" -maxdepth 4 -name "next.config.*" 2>/dev/null | head -1 | grep -q .; then
            detected+=("frontend-next")
        elif find "$TARGET" -maxdepth 4 -name "nuxt.config.*" 2>/dev/null | head -1 | grep -q .; then
            detected+=("frontend-nuxt"); detected+=("frontend-vue")
        elif find "$TARGET" -maxdepth 4 -name "vite.config.*" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q .; then
            if find "$TARGET" -maxdepth 4 -name "package.json" -not -path "*/node_modules/*" -exec grep -l '"react"' {} \; 2>/dev/null | head -1 | grep -q .; then
                detected+=("frontend-react")
            elif find "$TARGET" -maxdepth 4 -name "package.json" -not -path "*/node_modules/*" -exec grep -l '"vue"' {} \; 2>/dev/null | head -1 | grep -q .; then
                detected+=("frontend-vue")
            fi
        fi
    fi
    if find "$TARGET" -maxdepth 3 -name "composer.json" 2>/dev/null | head -1 | grep -q .; then
        if find "$TARGET" -maxdepth 4 -name "artisan" 2>/dev/null | head -1 | grep -q .; then detected+=("backend-laravel"); fi
    fi
    if find "$TARGET" -maxdepth 4 -name "manage.py" 2>/dev/null | head -1 | grep -q .; then
        detected+=("backend-django")
    elif grep -rIl --include="pyproject.toml" --include="requirements*.txt" -e "fastapi" "$TARGET" 2>/dev/null | head -1 | grep -q .; then
        detected+=("backend-fastapi")
    fi
    if find "$TARGET" -maxdepth 3 -name "pubspec.yaml" 2>/dev/null | head -1 | grep -q .; then detected+=("mobile-flutter"); fi
    if find "$TARGET" -maxdepth 3 -name "app.json" 2>/dev/null | head -1 | grep -q .; then
        if grep -l "react-native" "$TARGET"/package.json 2>/dev/null | head -1 | grep -q .; then detected+=("mobile-react-native"); fi
    fi
    printf '%s\n' "${detected[@]}"
}
STACKS="$(detect_stacks)"

# ============================================================
# Memory root (universal: ~/.agents/projects/<key>/memory)
# ============================================================
MEMORY_KEY="$(printf '%s' "$TARGET" | sed 's|/|-|g')"
MEMORY_ROOT="$HOME/.agents/projects/${MEMORY_KEY}/memory"

printf '%sagent-init: bootstrapping %s%s\n\n' "$BOLD" "$PROJECT_NAME" "$NC"
printf '  Target:   %s\n' "$TARGET"
printf '  Kit:      %s\n' "$KIT_DIR"
printf '  Agent:    %s\n' "$AGENT_TARGET"
printf '  Detected: %s\n' "${STACKS:-none (universal baseline only)}"
printf '  Memory:   %s\n\n' "$MEMORY_ROOT"

# ============================================================
# Substitution helper
# ============================================================
# shellcheck source=scripts/_subst.sh
. "$KIT_DIR/scripts/_subst.sh"

# ============================================================
# Emit dirs
# ============================================================
# Always create the universal .agents/ home (real files live here).
printf '%sCreating .agents/ structure...%s\n' "$BOLD" "$NC"
mkdir -p "$TARGET/.agents"/{skills,scripts,workflows,templates}
printf '  %sok%s .agents/{skills,scripts,workflows,templates}\n\n' "$GREEN" "$NC"

# Optionally also create claude/zcode dirs.
[ "$AGENT_TARGET" = claude ] || [ "$AGENT_TARGET" = all ] && {
    mkdir -p "$TARGET/.claude"/{skills,scripts,workflows,templates}
}
[ "$AGENT_TARGET" = zcode ] || [ "$AGENT_TARGET" = all ] && {
    mkdir -p "$TARGET/.zcode"/{scripts}
    mkdir -p "$TARGET/.zcode/skills"
}

# ============================================================
# Copy skills (to .agents/skills — the universal home)
# ============================================================
printf '%sCopying skills -> .agents/skills...%s\n' "$BOLD" "$NC"
for skill_dir in "$KIT_DIR/skills"/*/; do
    skill_name="$(basename "$skill_dir")"
    mkdir -p "$TARGET/.agents/skills/$skill_name"
    subst_copy "$skill_dir/SKILL.md" "$TARGET/.agents/skills/$skill_name/SKILL.md"
    printf '  %sok%s skills/%s/SKILL.md\n' "$GREEN" "$NC" "$skill_name"
done
printf '\n'

# Mirror to .claude/skills (real files) when target includes claude.
case "$AGENT_TARGET" in claude|all)
    printf '%sCopying skills -> .claude/skills...%s\n' "$BOLD" "$NC"
    for skill_dir in "$KIT_DIR/skills"/*/; do
        skill_name="$(basename "$skill_dir")"
        mkdir -p "$TARGET/.claude/skills/$skill_name"
        subst_copy "$skill_dir/SKILL.md" "$TARGET/.claude/skills/$skill_name/SKILL.md"
        printf '  %sok%s .claude/skills/%s/SKILL.md\n' "$GREEN" "$NC" "$skill_name"
    done
    printf '\n' ;;
esac

# For zcode/all: .zcode/skills are symlinks into .agents/skills (proven on provx).
case "$AGENT_TARGET" in zcode|all)
    printf '%sSymlinking .zcode/skills -> .agents/skills...%s\n' "$BOLD" "$NC"
    for skill_dir in "$KIT_DIR/skills"/*/; do
        skill_name="$(basename "$skill_dir")"
        ln -sfn "../../.agents/skills/$skill_name" "$TARGET/.zcode/skills/$skill_name"
        printf '  %sok%s .zcode/skills/%s -> .agents/skills/%s\n' "$GREEN" "$NC" "$skill_name" "$skill_name"
    done
    printf '\n' ;;
esac

# ============================================================
# Copy scripts + workflow + audit template -> .agents/
# ============================================================
printf '%sCopying scripts -> .agents/scripts...%s\n' "$BOLD" "$NC"
for script in x-precommit.sh install-hooks.sh install-workflows.sh plan-mode-context.sh plan-mode-context.zcode.sh clone-memory.sh install-plan-hook.sh; do
    [ -f "$KIT_DIR/scripts/$script" ] || continue
    subst_copy "$KIT_DIR/scripts/$script" "$TARGET/.agents/scripts/$script"
    chmod +x "$TARGET/.agents/scripts/$script"
    printf '  %sok%s scripts/%s\n' "$GREEN" "$NC" "$script"
done
printf '\n'

printf '%sCopying workflow + templates -> .agents/...%s\n' "$BOLD" "$NC"
subst_copy "$KIT_DIR/workflows/x-check.yml" "$TARGET/.agents/workflows/x-check.yml"
printf '  %sok%s workflows/x-check.yml\n' "$GREEN" "$NC"
subst_copy "$KIT_DIR/templates/audit-prompt.md" "$TARGET/.agents/templates/audit-prompt.md"
printf '  %sok%s templates/audit-prompt.md\n\n' "$GREEN" "$NC"

# ============================================================
# Build rules.md (in .agents/, mirrored/symlinked to other targets)
# ============================================================
printf '%sBuilding rules.md...%s\n' "$BOLD" "$NC"
RULES_AGENTS="$TARGET/.agents/rules.md"

build_rules_to() {
    local out="$1"
    local backup=""
    [ -f "$out" ] && { backup="/tmp/agent-kit-rules-$(date +%Y%m%d-%H%M%S).md"; cp "$out" "$backup"; }
    subst_copy "$KIT_DIR/rules/rules-baseline.md" "$out"
    if [ -n "${STACKS:-}" ]; then
        while IFS= read -r stack; do
            [ -z "$stack" ] && continue
            module="$KIT_DIR/rules/${stack}.md"
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
}
build_rules_to "$RULES_AGENTS"

# Mirror rules to claude/zcode targets. Claude gets a real copy (its skills read .claude/rules.md).
# ZCode skills read by absolute path to .agents/rules.md (via substitution), so .zcode needs none.
case "$AGENT_TARGET" in claude|all)
    cp "$RULES_AGENTS" "$TARGET/.claude/rules.md"
    printf '  %sok%s .claude/rules.md (mirror)\n' "$GREEN" "$NC" ;;
esac
printf '\n'

# ============================================================
# Seed memory (the seniority template only; conversational phases author the rest)
# ============================================================
printf '%sSeeding memory baseline...%s\n' "$BOLD" "$NC"
mkdir -p "$MEMORY_ROOT"
if [ ! -f "$MEMORY_ROOT/feedback_seniority_and_workflow.md" ]; then
    subst_copy "$KIT_DIR/templates/feedback_seniority_and_workflow.md" "$MEMORY_ROOT/feedback_seniority_and_workflow.md"
    printf '  %sok%s seeded feedback_seniority_and_workflow.md\n' "$GREEN" "$NC"
else
    printf '  %sskip%s feedback_seniority_and_workflow.md already present\n' "$YELLOW" "$NC"
fi
printf '\n'

# ============================================================
# Generate AGENTS.md + clone memory into it
# ============================================================
printf '%sGenerating AGENTS.md...%s\n' "$BOLD" "$NC"
subst_copy "$KIT_DIR/templates/AGENTS.md.template" "$TARGET/AGENTS.md"
# Clone whatever memory exists so far into the anchor.
if [ -d "$MEMORY_ROOT" ] && ls "$MEMORY_ROOT"/*.md >/dev/null 2>&1; then
    bash "$TARGET/.agents/scripts/clone-memory.sh" "$TARGET/AGENTS.md" "$MEMORY_ROOT" || \
        printf '  %swarn%s memory clone skipped\n' "$YELLOW" "$NC"
fi
printf '  %sok%s AGENTS.md (memory cloned)\n\n' "$GREEN" "$NC"

# For claude/all: CLAUDE.md mirrors AGENTS.md content (Claude auto-loads CLAUDE.md).
# We generate it from its own template in the conversational phase; here just note it.
case "$AGENT_TARGET" in claude|all)
    printf '%sNote:%s CLAUDE.md is generated in the conversational BOOTSTRAP phase (Phase 4).\n' "$BLUE" "$NC"
    printf '       It mirrors AGENTS.md. For now AGENTS.md is the source of truth.\n\n' ;;
esac

# ============================================================
# Install plan-mode hook (target-aware)
# ============================================================
printf '%sInstalling plan-mode hook...%s\n\n' "$BOLD" "$NC"
bash "$KIT_DIR/scripts/install-plan-hook.sh" "$TARGET" "$AGENT_TARGET"
printf '\n'

# ============================================================
# .gitignore hygiene for the bridge dirs (append if absent)
# ============================================================
ensure_gitignore() {
    local gi="$TARGET/.gitignore"
    touch "$gi"
    grep -qF '# ---- Agent Kit' "$gi" || cat >> "$gi" <<'EOF'

# ---- Agent Kit (track governance, ignore per-machine local) ------------------
# .agents/ skills/scripts/rules.md, AGENTS.md are shared governance (tracked).
# Local-only artifacts are ignored:
.agents/settings.local.json
.agents/**/settings.local.json
.zcode/settings.local.json
.zcode/**/settings.local.json
.zcode/plans/
.claude/settings.local.json
.claude/**/settings.local.json
EOF
}
ensure_gitignore

# ============================================================
# Summary
# ============================================================
RULES_COUNT="$(grep -c '^### ' "$RULES_AGENTS")"
SKILLS_COUNT="$(find "$TARGET/.agents/skills" -name 'SKILL.md' | wc -l | tr -d ' ')"

cat <<EOF
${GREEN}${BOLD}OK agent-init complete${NC}

${BOLD}Installed at:${NC}
  ${TARGET}/.agents/   (universal home: skills, scripts, rules.md, workflows, templates)
$(case "$AGENT_TARGET" in
    zcode) printf '  %s/.zcode/   (symlinked skills, scripts, config.json)\n' "$TARGET" ;;
    claude) printf '  %s/.claude/  (real copies)\n' "$TARGET" ;;
    all) printf '  %s/.zcode/   (symlinked skills, scripts, config.json)\n  %s/.claude/  (real copies)\n' "$TARGET" "$TARGET" ;;
esac)
  ${TARGET}/AGENTS.md   (anchor + memory clone)

${BOLD}Summary:${NC}
  Skills:     ${SKILLS_COUNT}
  Rules:      ${RULES_COUNT}
  Stacks:     ${STACKS:-universal only}
  Target:     ${AGENT_TARGET}
  Memory key: ${MEMORY_KEY}

${BOLD}Next steps:${NC}
  1. Continue the bootstrap conversationally:
     reference  ${BLUE}@${KIT_DIR}/BOOTSTRAP.md${NC}
     This gathers project context, runs audits, authors memory, and (for
     claude/all) generates CLAUDE.md.
  2. Install git hooks (every detected repo):
     ${BLUE}bash ${TARGET}/.agents/scripts/install-hooks.sh all${NC}
  3. Stage the CI workflow (per repo):
     ${BLUE}bash ${TARGET}/.agents/scripts/install-workflows.sh all${NC}
  4. Restart your agent so the new skills load, then try:
     ${BLUE}/x-rules${NC}   ${BLUE}/x-check${NC}   ${BLUE}/x-implement <task>${NC}
EOF
