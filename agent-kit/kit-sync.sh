#!/usr/bin/env bash
# kit-sync.sh - mirror agent-kit's shared assets into claude-kit.
#
# Usage:  bash kit-sync.sh [--check]
#
# agent-kit is the source of truth for rules, skills, templates, and the
# target-agnostic scripts. claude-kit keeps its own installer, sync script,
# _subst.sh, install-plan-hook.sh, selftest.sh, BOOTSTRAP.md, and README.md,
# because those differ by design.
#
# --check compares without writing and exits 1 on drift, so CI can gate on it.

set -euo pipefail

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'
BOLD=$'\033[1m'; NC=$'\033[0m'

SRC="$(cd "$(dirname "$0")" && pwd)"
DST="$(cd "$SRC/../claude-kit" && pwd)"

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

# Files claude-kit owns. Never mirrored, never reported as drift.
KIT_SPECIFIC="claude-init.sh claude-sync.sh BOOTSTRAP.md README.md .gitignore scripts/_subst.sh scripts/install-plan-hook.sh scripts/selftest.sh"

# Assets mirrored from agent-kit. Paths are relative to each kit root.
mirrored_paths() {
    local f
    for f in "$SRC"/rules/*.md;     do [ -f "$f" ] && printf 'rules/%s\n' "$(basename "$f")"; done
    for f in "$SRC"/skills/*/SKILL.md; do [ -f "$f" ] && printf 'skills/%s/SKILL.md\n' "$(basename "$(dirname "$f")")"; done
    for f in "$SRC"/templates/*.md; do
        [ -f "$f" ] || continue
        # AGENTS.md.template is meaningless to a CLAUDE.md-only kit.
        [ "$(basename "$f")" = "AGENTS.md.template" ] && continue
        printf 'templates/%s\n' "$(basename "$f")"
    done
    local s
    for s in x-precommit.sh install-hooks.sh install-workflows.sh plan-mode-context.sh _detect_stacks.sh repair-sentinel.sh repair-sentinel.selftest.sh; do
        [ -f "$SRC/scripts/$s" ] && printf 'scripts/%s\n' "$s"
    done
}

drift=0
copied=0

printf '%skit-sync: %s -> %s%s\n\n' "$BOLD" "$SRC" "$DST" "$NC"

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
done < <(mirrored_paths)

# A file claude-kit has but agent-kit does not is either kit-specific (fine) or
# a leftover from an earlier layout (needs a human).
while IFS= read -r dst_file; do
    rel="${dst_file#"$DST"/}"
    case " $KIT_SPECIFIC " in *" $rel "*) continue ;; esac
    [ "$(basename "$rel")" = ".DS_Store" ] && continue
    if [ ! -f "$SRC/$rel" ]; then
        printf '  %sorphan%s %s (in claude-kit, absent from agent-kit)\n' "$YELLOW" "$NC" "$rel"
        drift=$((drift + 1))
    fi
done < <(find "$DST" -type f \( -path '*/rules/*' -o -path '*/skills/*' -o -path '*/templates/*' -o -path '*/scripts/*' \))

printf '\n'
if [ "$CHECK" -eq 1 ]; then
    if [ "$drift" -eq 0 ]; then
        printf '%s%sin sync%s\n' "$GREEN" "$BOLD" "$NC"
        exit 0
    fi
    printf '%s%s%s file(s) drifted - run: bash %s%s\n' "$RED" "$BOLD" "$drift" "$0" "$NC" >&2
    exit 1
fi
printf '%s%smirrored %s file(s)%s\n' "$GREEN" "$BOLD" "$copied" "$NC"
