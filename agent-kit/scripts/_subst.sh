#!/usr/bin/env bash
# Shared template substitution for agent-init.sh and agent-sync.sh.
#
# Sourced, never executed. Callers must have these env vars set:
#   TARGET         absolute project path
#   PROJECT_NAME   short project name (basename of TARGET)
#   MEMORY_ROOT    absolute memory dir (e.g. ~/.agents/projects/<key>/memory)
#   AGENT_TARGET   one of: agents | zcode | claude | all
#
# Substituted tokens (every copied file goes through subst_copy):
#   {{PROJECT_ROOT}}    -> TARGET
#   {{PROJECT_NAME}}    -> PROJECT_NAME
#   {{MEMORY_ROOT}}     -> MEMORY_ROOT
#   {{AGENT_TARGET}}    -> AGENT_TARGET
#   {{ANCHOR_FILE}}     -> AGENTS.md (always; multi-target agents all read it)
#   {{RULES_PATH}}      -> path to rules.md relative to TARGET, e.g. .agents/rules.md
#   {{SKILLS_DIR}}      -> primary skills dir, e.g. .agents/skills
#   {{TEMPLATES_DIR}}   -> primary templates dir, e.g. .agents/templates
#   {{MEMORY_DIR_HINT}} -> MEMORY_ROOT with $HOME collapsed to ~, safe to embed in
#                          files that live inside the repo (no absolute path leak)
#
# A plain `cp` would leave literal {{TOKEN}} text in the project, so keep the two
# installers and this helper in step.

# Resolve the primary rules/skills location for the active target.
# .agents/ is the universal home; .claude/ and .zcode/ reuse it (symlinks or copies).
_subst_primary_dirs() {
    case "${AGENT_TARGET:-agents}" in
        claude) printf '%s\n%s\n%s\n' ".claude/rules.md" ".claude/skills" ".claude/templates" ;;
        *)      printf '%s\n%s\n%s\n' ".agents/rules.md" ".agents/skills" ".agents/templates" ;;
    esac
}

subst_copy() {
    local src="$1"
    local dst="$2"
    : "${TARGET:?subst_copy: TARGET is not set}"
    : "${PROJECT_NAME:?subst_copy: PROJECT_NAME is not set}"
    : "${MEMORY_ROOT:?subst_copy: MEMORY_ROOT is not set}"
    : "${AGENT_TARGET:?subst_copy: AGENT_TARGET is not set}"

    local dirs rules_path skills_dir templates_dir
    local memory_hint="~${MEMORY_ROOT#"$HOME"}"
    dirs="$(_subst_primary_dirs)"
    rules_path="$(printf '%s\n' "$dirs" | sed -n '1p')"
    skills_dir="$(printf '%s\n' "$dirs" | sed -n '2p')"
    templates_dir="$(printf '%s\n' "$dirs" | sed -n '3p')"

    sed -e "s|{{PROJECT_ROOT}}|${TARGET}|g" \
        -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
        -e "s|{{MEMORY_ROOT}}|${MEMORY_ROOT}|g" \
        -e "s|{{MEMORY_DIR_HINT}}|${memory_hint}|g" \
        -e "s|{{AGENT_TARGET}}|${AGENT_TARGET}|g" \
        -e "s|{{ANCHOR_FILE}}|AGENTS.md|g" \
        -e "s|{{RULES_PATH}}|${rules_path}|g" \
        -e "s|{{SKILLS_DIR}}|${skills_dir}|g" \
        -e "s|{{TEMPLATES_DIR}}|${templates_dir}|g" \
        "$src" > "$dst"
}
