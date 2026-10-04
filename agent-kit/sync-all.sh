#!/usr/bin/env bash
# sync-all.sh - run the per-project sync for every project in a list.
#
# Usage:  bash sync-all.sh [--dry-run] [--list <file>]
#
# The list (default: projects.list next to this script, kept out of git) has one
# project per line:
#
#     <kit> <project-path> [extra sync args]
#     claude /Users/me/Projects/shop
#     agent  /Users/me/Projects/api --target all
#
# <kit> is `claude` (claude-kit/claude-sync.sh) or `agent` (agent-kit/agent-sync.sh).
# Blank lines and lines starting with # are ignored.
#
# For each project it:
#   1. Skips it when rules.md has no sentinel, because the sync would drop the
#      project's own rules; run scripts/repair-sentinel.sh on it first.
#   2. Runs the sync (unless --dry-run).
#   3. Lists the kit template's "- ❌" lines missing from the project's anchor file
#      (CLAUDE.md / AGENTS.md). The syncs never edit that file, so new kit-wide
#      don'ts reach a project only when someone pastes them in.
#
# Exit status is 1 when any project was skipped or failed.

set -uo pipefail

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'
BOLD=$'\033[1m'; NC=$'\033[0m'

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$KIT_DIR")"
LIST="$KIT_DIR/projects.list"
DRY_RUN=0
SENTINEL='<!-- kit-managed above — project rules below -->'

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --list) LIST="$2"; shift 2 ;;
        -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
        *) echo "${RED}Unknown argument: $1${NC}" >&2; exit 2 ;;
    esac
done

if [ ! -f "$LIST" ]; then
    echo "${RED}No project list at $LIST${NC} (copy projects.list.example and edit it)" >&2
    exit 2
fi

failed=0

while read -r kit path args; do
    case "$kit" in ''|\#*) continue ;; esac

    case "$kit" in
        claude) sync="$REPO_DIR/claude-kit/claude-sync.sh"; rules="$path/.claude/rules.md"
                anchor="$path/CLAUDE.md"; template="$REPO_DIR/claude-kit/templates/CLAUDE.md.template" ;;
        agent)  sync="$KIT_DIR/agent-sync.sh"; rules="$path/.agents/rules.md"
                anchor="$path/AGENTS.md"; template="$KIT_DIR/templates/AGENTS.md.template" ;;
        *) echo "${RED}✗ $path: unknown kit '$kit' (use claude or agent)${NC}"; failed=1; continue ;;
    esac

    echo "${BOLD}== $path ($kit)${NC}"

    if [ ! -d "$path" ]; then
        echo "  ${RED}✗ directory not found${NC}"; failed=1; continue
    fi
    if [ -f "$rules" ] && ! grep -qF "$SENTINEL" "$rules"; then
        echo "  ${YELLOW}⚠ skipped: $rules has no sentinel; run${NC}"
        echo "    bash $KIT_DIR/scripts/repair-sentinel.sh $path"
        failed=1; continue
    fi

    if [ "$DRY_RUN" = 1 ]; then
        echo "  would run: bash $sync $path $args"
    elif ! bash "$sync" "$path" $args </dev/null; then
        echo "  ${RED}✗ sync failed${NC}"; failed=1; continue
    fi

    if [ -f "$anchor" ]; then
        missing=$(grep -F -- '- ❌' "$template" | grep -vF '{{' | grep -vxFf "$anchor")
        if [ -n "$missing" ]; then
            echo "  ${YELLOW}$(basename "$anchor") is missing these kit lines:${NC}"
            printf '%s\n' "$missing" | sed 's/^/    /'
        fi
    fi
    echo "  ${GREEN}✓ done${NC}"
done < "$LIST"

exit "$failed"
