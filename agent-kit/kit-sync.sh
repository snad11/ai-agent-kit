#!/usr/bin/env bash
# kit-sync.sh - mirror agent-kit's shared assets into every sibling *-kit.
#
# Usage:  bash kit-sync.sh [--check] [kit-name ...]
#
# agent-kit is the source of truth for rules, skills, templates, and the
# target-agnostic scripts. Each sibling kit keeps its own installer, sync
# script, _subst.sh, install-plan-hook.sh, selftest.sh, BOOTSTRAP.md and
# README.md, because those differ by design.
#
# With no kit names, every sibling *-kit is synced. Name one or more kits to
# limit the run (e.g. `bash kit-sync.sh --check cursor-kit`).
#
# --check compares without writing and exits 1 on drift, so CI can gate on it.

set -euo pipefail

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'
BOLD=$'\033[1m'; NC=$'\033[0m'

SRC="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SRC/.." && pwd)"

CHECK=0
ONLY=()
for arg in "$@"; do
    case "$arg" in
        --check) CHECK=1 ;;
        -*) printf 'kit-sync: unknown flag %s\n' "$arg" >&2; exit 2 ;;
        *) ONLY+=("$arg") ;;
    esac
done

# Which anchor template each kit owns. Anchor templates are the files matching
# *.md.template; agent-kit holds them all, each kit receives only its own.
kit_anchor_template() {
    case "$1" in
        claude-kit)   printf 'CLAUDE.md.template\n' ;;
        gemini-kit)   printf 'GEMINI.md.template\n' ;;
        copilot-kit)  printf 'COPILOT.md.template\n' ;;
        cursor-kit)   printf 'CURSOR.md.template\n' ;;
        windsurf-kit) printf 'WINDSURF.md.template\n' ;;
        cline-kit)    printf 'CLINE.md.template\n' ;;
        aider-kit)    printf 'CONVENTIONS.md.template\n' ;;
        *)            printf 'AGENTS.md.template\n' ;;
    esac
}

# Files each kit owns outright. Never mirrored, never reported as drift.
kit_specific() {
    local kit="$1" prefix="${1%-kit}"
    printf '%s\n' \
        "${prefix}-init.sh" "${prefix}-sync.sh" \
        "BOOTSTRAP.md" "README.md" ".gitignore" \
        "scripts/_subst.sh" "scripts/install-plan-hook.sh" "scripts/selftest.sh" \
        "templates/$(kit_anchor_template "$kit")"
}

# Assets mirrored from agent-kit. Paths are relative to each kit root.
mirrored_paths() {
    local kit="$1" anchor f s
    anchor="$(kit_anchor_template "$kit")"
    for f in "$SRC"/rules/*.md;        do [ -f "$f" ] && printf 'rules/%s\n' "$(basename "$f")"; done
    for f in "$SRC"/skills/*/SKILL.md; do [ -f "$f" ] && printf 'skills/%s/SKILL.md\n' "$(basename "$(dirname "$f")")"; done
    for f in "$SRC"/workflows/*;       do [ -f "$f" ] && printf 'workflows/%s\n' "$(basename "$f")"; done
    for f in "$SRC"/templates/*; do
        [ -f "$f" ] || continue
        local base; base="$(basename "$f")"
        # Anchor templates belong to exactly one kit: ship this kit's, skip the rest.
        case "$base" in
            *.md.template) [ "$base" = "$anchor" ] || continue ;;
        esac
        printf 'templates/%s\n' "$base"
    done
    for s in x-precommit.sh install-hooks.sh install-workflows.sh plan-mode-context.sh \
             _detect_stacks.sh repair-sentinel.sh repair-sentinel.selftest.sh; do
        [ -f "$SRC/scripts/$s" ] && printf 'scripts/%s\n' "$s"
    done
    # clone-memory.sh folds the memory folder into the anchor, which only matters
    # for agents that do NOT auto-load a memory dir. Claude Code does, so
    # claude-kit deliberately ships without it.
    [ "$kit" = "claude-kit" ] || printf 'scripts/clone-memory.sh\n'
    return 0
}

sync_kit() {
    local kit="$1" DST="$ROOT/$kit"
    local drift=0 copied=0 rel src_file dst_file specific

    printf '%s%s%s\n' "$BOLD" "$kit" "$NC"
    specific="$(kit_specific "$kit" | tr '\n' ' ')"

    while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        src_file="$SRC/$rel"
        dst_file="$DST/$rel"
        if [ -f "$dst_file" ] && cmp -s "$src_file" "$dst_file"; then
            continue
        fi
        drift=$((drift + 1))
        if [ "$CHECK" -eq 1 ]; then
            printf '  %sdrift%s %s\n' "$YELLOW" "$NC" "$rel"
            continue
        fi
        mkdir -p "$(dirname "$dst_file")"
        cp "$src_file" "$dst_file"
        [ -x "$src_file" ] && chmod +x "$dst_file"
        copied=$((copied + 1))
        printf '  %sok%s %s\n' "$GREEN" "$NC" "$rel"
    done < <(mirrored_paths "$kit")

    # A file the kit has but agent-kit does not is either kit-specific (fine) or
    # a leftover from an earlier layout (needs a human).
    while IFS= read -r dst_file; do
        rel="${dst_file#"$DST"/}"
        case " $specific " in *" $rel "*) continue ;; esac
        [ "$(basename "$rel")" = ".DS_Store" ] && continue
        if [ ! -f "$SRC/$rel" ]; then
            printf '  %sorphan%s %s (in %s, absent from agent-kit)\n' "$YELLOW" "$NC" "$rel" "$kit"
            drift=$((drift + 1))
        fi
    done < <(find "$DST" -type f \( -path '*/rules/*' -o -path '*/skills/*' \
                -o -path '*/templates/*' -o -path '*/scripts/*' -o -path '*/workflows/*' \))

    if [ "$CHECK" -eq 0 ] && [ "$copied" -gt 0 ]; then
        printf '  %smirrored %s file(s)%s\n' "$GREEN" "$copied" "$NC"
    elif [ "$drift" -eq 0 ]; then
        printf '  %sin sync%s\n' "$GREEN" "$NC"
    fi
    printf '\n'
    return "$([ "$drift" -eq 0 ] && echo 0 || echo 1)"
}

# Discover sibling kits. agent-kit is the source, never a destination.
kits=()
if [ "${#ONLY[@]}" -gt 0 ]; then
    for k in "${ONLY[@]}"; do
        [ -d "$ROOT/$k" ] || { printf 'kit-sync: no such kit: %s\n' "$k" >&2; exit 2; }
        kits+=("$k")
    done
else
    for d in "$ROOT"/*-kit; do
        [ -d "$d" ] || continue
        k="$(basename "$d")"
        [ "$k" = "agent-kit" ] && continue
        kits+=("$k")
    done
fi

if [ "${#kits[@]}" -eq 0 ]; then
    printf '%skit-sync: no destination kits found under %s%s\n' "$YELLOW" "$ROOT" "$NC"
    exit 0
fi

printf '%skit-sync: %s -> %s kit(s)%s\n\n' "$BOLD" "$SRC" "${#kits[@]}" "$NC"

total_drift=0
for kit in "${kits[@]}"; do
    sync_kit "$kit" || total_drift=$((total_drift + 1))
done

if [ "$CHECK" -eq 1 ]; then
    if [ "$total_drift" -eq 0 ]; then
        printf '%s%sall kits in sync%s\n' "$GREEN" "$BOLD" "$NC"
        exit 0
    fi
    printf '%s%s%s kit(s) drifted - run: bash %s%s\n' "$RED" "$BOLD" "$total_drift" "$0" "$NC" >&2
    exit 1
fi
printf '%s%sdone%s\n' "$GREEN" "$BOLD" "$NC"
