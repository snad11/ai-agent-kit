#!/usr/bin/env bash
# repair-sentinel.sh - make a project's rules.md safe to sync.
#
# Usage:  bash repair-sentinel.sh <project-path> [--apply] [--force-keep-project] [--target claude|agents]
#
# agent-sync.sh and claude-sync.sh rebuild rules.md from the kit and preserve only
# what sits BELOW the sentinel:
#
#     <!-- kit-managed above — project rules below -->
#
# A project whose rules.md predates the sentinel therefore loses every rule it added
# the first time it is synced. This script finds those rules and moves them below the
# sentinel first, so the sync has nothing to discard.
#
# Read-only by default. --apply is the only mode that writes, and it always writes
# <project>/<rules-dir>/rules.md.bak-<ts> first - inside the project, because several
# of these projects have no git history to recover from.
#
# Classification, by rule ID (the `### <ID> — title` heading):
#   kit-identical  same ID, same body as the kit would generate -> safe to regenerate
#   kit-modified   same ID, different body -> the project edited a kit rule
#   project-only   ID the kit doesn't know -> must end up below the sentinel
#
# kit-modified rules are never resolved automatically: silently reverting a hand-tuned
# rule is the exact failure this script exists to prevent. It reports them and exits 2.
# --force-keep-project treats them as project-only, preserving the project's version
# below the sentinel (the kit's copy still lands above it, so the project's wins by
# being last).

set -euo pipefail

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; BLUE=$'\033[0;34m'
BOLD=$'\033[1m'; NC=$'\033[0m'

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SENTINEL='<!-- kit-managed above — project rules below -->'

TARGET="${1:-}"
shift || true
APPLY=0
FORCE_KEEP=0
FORCED_TARGET=""
while [ $# -gt 0 ]; do
    case "$1" in
        --apply) APPLY=1; shift ;;
        --force-keep-project) FORCE_KEEP=1; shift ;;
        --target) FORCED_TARGET="$2"; shift 2 ;;
        --target=*) FORCED_TARGET="${1#--target=}"; shift ;;
        *) printf '%sUnknown argument: %s%s\n' "$RED" "$1" "$NC" >&2; exit 1 ;;
    esac
done

if [ -z "$TARGET" ]; then
    printf '%sUsage: bash repair-sentinel.sh <project-path> [--apply] [--force-keep-project]%s\n' "$RED" "$NC" >&2
    exit 1
fi
if [ ! -d "$TARGET" ]; then
    printf '%sNo such directory: %s%s\n' "$RED" "$TARGET" "$NC" >&2
    exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

RULES=""
if [ -n "$FORCED_TARGET" ]; then
    case "$FORCED_TARGET" in
        claude) RULES="$TARGET/.claude/rules.md" ;;
        agents) RULES="$TARGET/.agents/rules.md" ;;
        *) printf '%s--target must be claude or agents%s\n' "$RED" "$NC" >&2; exit 1 ;;
    esac
elif [ -f "$TARGET/.agents/rules.md" ]; then
    RULES="$TARGET/.agents/rules.md"
elif [ -f "$TARGET/.claude/rules.md" ]; then
    RULES="$TARGET/.claude/rules.md"
fi

PROJECT_LABEL="$(basename "$TARGET")"
printf '%srepair-sentinel: %s%s\n' "$BOLD" "$PROJECT_LABEL" "$NC"

if [ -z "$RULES" ] || [ ! -f "$RULES" ]; then
    printf '  %sno rules.md%s - nothing to protect; the sync will write the first one\n' "$BLUE" "$NC"
    exit 0
fi
printf '  file: %s\n' "${RULES#"$TARGET"/}"

if grep -qF "$SENTINEL" "$RULES"; then
    printf '  %ssentinel present%s - already safe to sync\n' "$GREEN" "$NC"
    exit 0
fi

# Build what the kit would generate for this project, so rule bodies can be compared.
# shellcheck source=_detect_stacks.sh
. "$KIT_DIR/scripts/_detect_stacks.sh"
STACKS="$(detect_stacks)"
EXPECTED="$(mktemp -t repair-sentinel-expected)"
trap 'rm -f "$EXPECTED"' EXIT
cat "$KIT_DIR/rules/rules-baseline.md" > "$EXPECTED"
if [ -n "${STACKS:-}" ]; then
    while IFS= read -r stack; do
        [ -z "$stack" ] && continue
        [ -f "$KIT_DIR/rules/${stack}.md" ] || continue
        printf '\n---\n\n' >> "$EXPECTED"
        cat "$KIT_DIR/rules/${stack}.md" >> "$EXPECTED"
    done <<< "$STACKS"
fi
printf '  stacks: %s\n' "${STACKS:-(none)}"

REPORT="$(mktemp -t repair-sentinel-report)"
SPLIT="$(mktemp -t repair-sentinel-split)"
trap 'rm -f "$EXPECTED" "$REPORT" "$SPLIT"' EXIT

python3 - "$RULES" "$EXPECTED" "$REPORT" "$SPLIT" "$FORCE_KEEP" <<'PYEOF'
import re, sys, unicodedata

rules_path, expected_path, report_path, split_path, force_keep = sys.argv[1:6]
force_keep = force_keep == "1"

RULE = re.compile(r'^###\s+(\S+)')
ANY_HEADING = re.compile(r'^#{1,6}\s')

def blocks(text):
    """Map rule ID -> body text.

    A rule block ends at the next heading of ANY level, not just the next `###`.
    Ending only on `###` lets the last rule of a section swallow the `##` section
    that follows it, which reports every section-boundary rule as modified.
    """
    out, order, cur, buf = {}, [], None, []
    for line in text.splitlines(keepends=True):
        m = RULE.match(line)
        if m:
            if cur:
                out[cur] = "".join(buf)
            cur = m.group(1)
            order.append(cur)
            buf = [line]
            continue
        if cur and ANY_HEADING.match(line):
            out[cur] = "".join(buf)
            cur, buf = None, []
            continue
        if cur:
            buf.append(line)
    if cur:
        out[cur] = "".join(buf)
    return out, order, ""

def norm(s):
    """Compare rule bodies on content, not on whitespace, separators, or dash variants."""
    s = unicodedata.normalize("NFKC", s)
    s = s.replace("\u2014", "-").replace("\u2013", "-").replace("\u2019", "'")
    s = re.sub(r'^\s*-{3,}\s*$', '', s, flags=re.M)
    return re.sub(r'\s+', ' ', s).strip()

project = open(rules_path, encoding="utf-8").read()
expected = open(expected_path, encoding="utf-8").read()

pblocks, porder, _ = blocks(project)
eblocks, _, _ = blocks(expected)

identical, modified, only = [], [], []
for rid in porder:
    if rid not in eblocks:
        only.append(rid)
    elif norm(pblocks[rid]) == norm(eblocks[rid]):
        identical.append(rid)
    else:
        modified.append(rid)

keep = only + (modified if force_keep else [])
keep_ordered = [r for r in porder if r in set(keep)]

with open(report_path, "w", encoding="utf-8") as f:
    f.write("kit-identical=%d\n" % len(identical))
    f.write("kit-modified=%d\n" % len(modified))
    f.write("project-only=%d\n" % len(only))
    f.write("MODIFIED_IDS=%s\n" % " ".join(modified))
    f.write("ONLY_IDS=%s\n" % " ".join(only))
    f.write("KEEP_IDS=%s\n" % " ".join(keep_ordered))

with open(split_path, "w", encoding="utf-8") as f:
    for rid in keep_ordered:
        body = pblocks[rid]
        if not body.endswith("\n"):
            body += "\n"
        f.write(body)
        if not body.endswith("\n\n"):
            f.write("\n")
PYEOF

kit_identical_count="$(grep '^kit-identical=' "$REPORT" | cut -d= -f2)"
kit_modified_count="$(grep '^kit-modified=' "$REPORT" | cut -d= -f2)"
project_only_count="$(grep '^project-only=' "$REPORT" | cut -d= -f2)"
modified_ids="$(grep '^MODIFIED_IDS=' "$REPORT" | cut -d= -f2-)"
only_ids="$(grep '^ONLY_IDS=' "$REPORT" | cut -d= -f2-)"

printf '  kit-identical: %s\n' "$kit_identical_count"
printf '  project-only:  %s  %s%s%s\n' "$project_only_count" "$BLUE" "$only_ids" "$NC"
printf '  kit-modified:  %s  %s%s%s\n' "$kit_modified_count" "$YELLOW" "$modified_ids" "$NC"

if [ "$kit_modified_count" -gt 0 ] && [ "$FORCE_KEEP" -eq 0 ]; then
    printf '\n%sSTOP - %s kit rule(s) were edited in place.%s\n' "$RED" "$kit_modified_count" "$NC" >&2
    printf 'A sync would revert them to the kit text. Nothing was written.\n' >&2
    printf 'Review the IDs above, then choose:\n' >&2
    printf '  (a) keep the project versions:  %s--force-keep-project%s\n' "$BOLD" "$NC" >&2
    printf '  (b) accept the kit versions:    edit them out of rules.md, then re-run\n' >&2
    exit 2
fi

if [ "$project_only_count" -eq 0 ] && [ "$kit_modified_count" -eq 0 ]; then
    printf '  %snothing project-specific%s - the sync can rebuild this file safely\n' "$GREEN" "$NC"
    if [ "$APPLY" -eq 1 ]; then
        printf '\n%s\n\n%s\n' "$SENTINEL" '<!-- Add project-specific rules below. Anything below the sentinel survives sync runs. -->' >> "$RULES"
        printf '  %sok%s sentinel appended\n' "$GREEN" "$NC"
    fi
    exit 0
fi

if [ "$APPLY" -eq 0 ]; then
    printf '\n  %sreport only%s - re-run with --apply to move %s rule(s) below the sentinel\n' \
        "$BLUE" "$NC" "$(grep '^KEEP_IDS=' "$REPORT" | cut -d= -f2- | wc -w | tr -d ' ')"
    exit 0
fi

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="${RULES}.bak-${TS}"
cp "$RULES" "$BACKUP"
printf '  backup: %s%s%s\n' "$BLUE" "${BACKUP#"$TARGET"/}" "$NC"

NEW="$(mktemp -t repair-sentinel-new)"
{
    cat "$EXPECTED"
    printf '\n---\n\n%s\n\n' "$SENTINEL"
    printf '<!-- Add project-specific rules below. Anything below the sentinel survives sync runs. -->\n\n'
    cat "$SPLIT"
} > "$NEW"

# Never hand back a file smaller than what it preserves.
if [ ! -s "$NEW" ]; then
    rm -f "$NEW"
    printf '%sRefusing to write an empty rules.md. Original untouched: %s%s\n' "$RED" "$RULES" "$NC" >&2
    exit 1
fi
for rid in $(grep '^KEEP_IDS=' "$REPORT" | cut -d= -f2-); do
    if ! grep -q "^### ${rid}" "$NEW"; then
        rm -f "$NEW"
        printf '%sRule %s did not survive the rewrite. Original untouched: %s%s\n' "$RED" "$rid" "$RULES" "$NC" >&2
        exit 1
    fi
done

mv "$NEW" "$RULES"
printf '  %sok%s rules.md repaired (%s rules, %s below the sentinel)\n' \
    "$GREEN" "$NC" "$(grep -c '^### ' "$RULES")" "$(grep '^KEEP_IDS=' "$REPORT" | cut -d= -f2- | wc -w | tr -d ' ')"
