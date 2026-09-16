#!/usr/bin/env bash
# repair-sentinel.selftest.sh - assert the repair never loses a project rule.
#
# Runs against throwaway fixture directories under $TMPDIR. Touches no project,
# no database, no network. Exits 0 when every case passes.

set -uo pipefail

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; BOLD=$'\033[1m'; NC=$'\033[0m'

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPAIR="$KIT_DIR/scripts/repair-sentinel.sh"
SENTINEL='<!-- kit-managed above — project rules below -->'
FIXTURES="$(mktemp -d -t repair-sentinel-selftest)"
trap 'rm -rf "$FIXTURES"' EXIT

pass=0; fail=0
check() {
    local name="$1" cond="$2"
    if [ "$cond" = "1" ]; then
        printf '  %sPASS%s %s\n' "$GREEN" "$NC" "$name"; pass=$((pass+1))
    else
        printf '  %sFAIL%s %s\n' "$RED" "$NC" "$name"; fail=$((fail+1))
    fi
}

new_fixture() {
    local name="$1"
    local dir="$FIXTURES/$name"
    mkdir -p "$dir/.claude"
    cat "$KIT_DIR/rules/rules-baseline.md" > "$dir/.claude/rules.md"
    printf '%s' "$dir"
}

printf '%srepair-sentinel selftest%s\n\n' "$BOLD" "$NC"

# Case 1: project-only rules are preserved and end up below the sentinel.
printf '%scase 1: project-only rules survive%s\n' "$BOLD" "$NC"
d="$(new_fixture project-only)"
cat >> "$d/.claude/rules.md" <<'EOF'

### ZZ-01 — a rule the kit has never heard of

**Why:** it is project specific.
**Detect:** grep for it.
**Fix:** keep it.

### ZZ-02 — a second one

**Why:** two is better than one for this test.
**Detect:** grep.
**Fix:** keep.
EOF
out="$($REPAIR "$d" --apply 2>&1)"; rc=$?
check "exits 0" "$([ $rc -eq 0 ] && echo 1 || echo 0)"
check "ZZ-01 preserved" "$(grep -qc '^### ZZ-01' "$d/.claude/rules.md" >/dev/null && grep -q '^### ZZ-01' "$d/.claude/rules.md" && echo 1 || echo 0)"
check "ZZ-02 preserved" "$(grep -q '^### ZZ-02' "$d/.claude/rules.md" && echo 1 || echo 0)"
check "sentinel written" "$(grep -qF "$SENTINEL" "$d/.claude/rules.md" && echo 1 || echo 0)"
check "ZZ-01 sits BELOW the sentinel" \
    "$([ "$(grep -nF "$SENTINEL" "$d/.claude/rules.md" | cut -d: -f1)" -lt "$(grep -n '^### ZZ-01' "$d/.claude/rules.md" | cut -d: -f1)" ] && echo 1 || echo 0)"
check "in-project backup written" "$(ls "$d/.claude/"rules.md.bak-* >/dev/null 2>&1 && echo 1 || echo 0)"

# Case 2: an edited kit rule blocks the repair rather than being reverted.
printf '\n%scase 2: kit-modified rule blocks%s\n' "$BOLD" "$NC"
d="$(new_fixture kit-modified)"
python3 - "$d/.claude/rules.md" <<'PYEOF'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
s = s.replace("**Why:**", "**Why (project override):**", 1)
io.open(p, "w", encoding="utf-8").write(s)
PYEOF
before="$(md5 -q "$d/.claude/rules.md" 2>/dev/null || md5sum "$d/.claude/rules.md" | cut -d' ' -f1)"
out="$($REPAIR "$d" --apply 2>&1)"; rc=$?
after="$(md5 -q "$d/.claude/rules.md" 2>/dev/null || md5sum "$d/.claude/rules.md" | cut -d' ' -f1)"
check "exits 2" "$([ $rc -eq 2 ] && echo 1 || echo 0)"
check "file left untouched" "$([ "$before" = "$after" ] && echo 1 || echo 0)"
check "names the offending ID" "$(printf '%s' "$out" | grep -q 'kit-modified:  *[1-9]' && echo 1 || echo 0)"
check "offers a resolution" "$(printf '%s' "$out" | grep -q -- '--force-keep-project' && echo 1 || echo 0)"

# Case 3: --force-keep-project preserves the project's version.
printf '\n%scase 3: --force-keep-project preserves the edit%s\n' "$BOLD" "$NC"
out="$($REPAIR "$d" --apply --force-keep-project 2>&1)"; rc=$?
check "exits 0" "$([ $rc -eq 0 ] && echo 1 || echo 0)"
check "project override kept" "$(grep -q 'Why (project override)' "$d/.claude/rules.md" && echo 1 || echo 0)"

# Case 4: idempotent - a file that already has a sentinel is left byte-identical.
printf '\n%scase 4: already-sentineled file is untouched%s\n' "$BOLD" "$NC"
d="$(new_fixture already-ok)"
printf '\n---\n\n%s\n\n### YY-01 — kept\n\n**Why:** test.\n' "$SENTINEL" >> "$d/.claude/rules.md"
before="$(md5 -q "$d/.claude/rules.md" 2>/dev/null || md5sum "$d/.claude/rules.md" | cut -d' ' -f1)"
out="$($REPAIR "$d" --apply 2>&1)"; rc=$?
after="$(md5 -q "$d/.claude/rules.md" 2>/dev/null || md5sum "$d/.claude/rules.md" | cut -d' ' -f1)"
check "exits 0" "$([ $rc -eq 0 ] && echo 1 || echo 0)"
check "byte-identical" "$([ "$before" = "$after" ] && echo 1 || echo 0)"

# Case 4b: the last rule before a `##` section is NOT reported as modified.
# Regression: a block that ended only at the next `###` swallowed the following
# `## ` section, so every section-boundary rule looked edited in every project.
printf '\n%scase 4b: section-boundary rule is not a false positive%s\n' "$BOLD" "$NC"
d="$(new_fixture boundary)"
printf '\n### ZZ-77 — project rule after the kit content\n\n**Why:** test.\n' >> "$d/.claude/rules.md"
out="$($REPAIR "$d" 2>&1)"; rc=$?
check "exits 0 (no kit-modified)" "$([ $rc -eq 0 ] && echo 1 || echo 0)"
check "kit-modified is 0" "$(printf '%s' "$out" | grep -q 'kit-modified:  0' && echo 1 || echo 0)"
check "ZZ-77 seen as project-only" "$(printf '%s' "$out" | grep -q 'ZZ-77' && echo 1 || echo 0)"

# Case 5: a project with no rules.md is a no-op, not an error.
printf '\n%scase 5: no rules.md is a no-op%s\n' "$BOLD" "$NC"
d="$FIXTURES/no-rules"; mkdir -p "$d/.claude"
out="$($REPAIR "$d" 2>&1)"; rc=$?
check "exits 0" "$([ $rc -eq 0 ] && echo 1 || echo 0)"
check "says nothing to protect" "$(printf '%s' "$out" | grep -q 'no rules.md' && echo 1 || echo 0)"

# Case 6: report mode writes nothing.
printf '\n%scase 6: report mode is read-only%s\n' "$BOLD" "$NC"
d="$(new_fixture report-only)"
printf '\n### ZZ-09 — project rule\n\n**Why:** test.\n' >> "$d/.claude/rules.md"
before="$(md5 -q "$d/.claude/rules.md" 2>/dev/null || md5sum "$d/.claude/rules.md" | cut -d' ' -f1)"
out="$($REPAIR "$d" 2>&1)"; rc=$?
after="$(md5 -q "$d/.claude/rules.md" 2>/dev/null || md5sum "$d/.claude/rules.md" | cut -d' ' -f1)"
check "exits 0" "$([ $rc -eq 0 ] && echo 1 || echo 0)"
check "file unchanged" "$([ "$before" = "$after" ] && echo 1 || echo 0)"
check "no backup written" "$(ls "$d/.claude/"rules.md.bak-* >/dev/null 2>&1 && echo 0 || echo 1)"

printf '\n%s%s passed, %s failed%s\n' "$BOLD" "$pass" "$fail" "$NC"
[ "$fail" -eq 0 ]
