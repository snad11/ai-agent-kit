#!/usr/bin/env bash
# Template substitution for zed-init.sh.
#
# GENERATED FILE — do not edit by hand.
# Regenerate: bash agent-kit/kit-scaffold.sh
#
# Sourced, never executed. Callers must have TARGET, PROJECT_NAME and MEMORY_ROOT set.
# Path tokens are fixed for this kit because it only ever emits Zed layout.

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
        -e "s|{{AGENT_TARGET}}|zed|g" \
        -e "s|{{ANCHOR_FILE}}|.rules|g" \
        -e "s|{{RULES_PATH}}|.zed/rules.md|g" \
        -e "s|{{SKILLS_DIR}}|.zed/skills|g" \
        -e "s|{{TEMPLATES_DIR}}|.zed/templates|g" \
        "$src" > "$dst"
}
