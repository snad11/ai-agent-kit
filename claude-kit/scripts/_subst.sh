#!/usr/bin/env bash
# Shared template substitution for claude-init.sh and claude-sync.sh.
#
# Sourced, never executed. Callers must have TARGET, PROJECT_NAME, and MEMORY_ROOT set.
#
# Every file the kit copies into a project goes through subst_copy - a plain `cp` would
# leave literal {{TOKEN}} text in the project, so keep the two installers in step.
#
# Substituted tokens:
#   {{PROJECT_ROOT}}    -> TARGET
#   {{PROJECT_NAME}}    -> PROJECT_NAME
#   {{MEMORY_ROOT}}     -> MEMORY_ROOT
#   {{ANCHOR_FILE}}     -> CLAUDE.md
#   {{RULES_PATH}}      -> .claude/rules.md
#   {{SKILLS_DIR}}      -> .claude/skills
#   {{TEMPLATES_DIR}}   -> .claude/templates
#   {{MEMORY_DIR_HINT}} -> MEMORY_ROOT with $HOME collapsed to ~, safe to embed in
#                          files that live inside the repo (no absolute path leak)
#
# The four path tokens are fixed here because this kit only ever emits .claude/.
# They exist so the shared skills/templates can be written once, tokenized, and
# resolve correctly in every kit. Keep this list in step with agent-kit/scripts/_subst.sh.

subst_copy() {
    local src="$1"
    local dst="$2"
    : "${TARGET:?subst_copy: TARGET is not set}"
    : "${PROJECT_NAME:?subst_copy: PROJECT_NAME is not set}"
    : "${MEMORY_ROOT:?subst_copy: MEMORY_ROOT is not set}"
    local memory_hint="~${MEMORY_ROOT#"$HOME"}"
    sed -e "s|{{PROJECT_ROOT}}|${TARGET}|g" \
        -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
        -e "s|{{MEMORY_ROOT}}|${MEMORY_ROOT}|g" \
        -e "s|{{MEMORY_DIR_HINT}}|${memory_hint}|g" \
        -e "s|{{ANCHOR_FILE}}|CLAUDE.md|g" \
        -e "s|{{RULES_PATH}}|.claude/rules.md|g" \
        -e "s|{{SKILLS_DIR}}|.claude/skills|g" \
        -e "s|{{TEMPLATES_DIR}}|.claude/templates|g" \
        "$src" > "$dst"
}
