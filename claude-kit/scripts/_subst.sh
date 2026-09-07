#!/usr/bin/env bash
# Shared template substitution for claude-init.sh and claude-sync.sh.
#
# Sourced, never executed. Callers must have TARGET, PROJECT_NAME, and MEMORY_ROOT set.
#
# Every file the kit copies into a project goes through subst_copy - a plain `cp` would
# leave literal {{TOKEN}} text in the project, so keep the two installers in step.

subst_copy() {
    local src="$1"
    local dst="$2"
    : "${TARGET:?subst_copy: TARGET is not set}"
    : "${PROJECT_NAME:?subst_copy: PROJECT_NAME is not set}"
    : "${MEMORY_ROOT:?subst_copy: MEMORY_ROOT is not set}"
    sed -e "s|{{PROJECT_ROOT}}|${TARGET}|g" \
        -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
        -e "s|{{MEMORY_ROOT}}|${MEMORY_ROOT}|g" \
        "$src" > "$dst"
}
