#!/usr/bin/env bash
# selftest.sh - bootstrap a throwaway project and assert the output is clean.
#
# Guards the property that makes the kit safe to use on public repos: nothing it writes
# into a project may contain an absolute path, another project's name, or a personal
# branch. Run after any change to the installers or to a file they copy.
#
# Usage: bash scripts/selftest.sh

set -uo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
PROJ="$WORK/sample-project"
FAILURES=0

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

pass() { printf "  ✅ %s\n" "$1"; }
fail() { printf "  ❌ %s\n" "$1"; FAILURES=$((FAILURES + 1)); }

mkdir -p "$PROJ"
git -C "$PROJ" init -q

printf "\n=== bootstrapping into %s ===\n" "$PROJ"
if ! bash "$KIT_DIR/claude-init.sh" "$PROJ" >"$WORK/init.log" 2>&1; then
    printf "claude-init.sh failed:\n"; cat "$WORK/init.log"; exit 1
fi

check_clean() {
    local label="$1"

    # Absolute home paths. MEMORY_ROOT legitimately expands to one, but it is only ever
    # substituted into files written outside the repo, so .claude/ must have none.
    if grep -rn '/Users/' "$PROJ/.claude" >"$WORK/hits" 2>/dev/null; then
        fail "$label: absolute paths in .claude/"; sed 's/^/       /' "$WORK/hits"
    else
        pass "$label: no absolute paths"
    fi

    if grep -rniE 'stitchub|xlent|dev-snad|\bsnad\b|escrow|paystack' "$PROJ/.claude" >"$WORK/hits" 2>/dev/null; then
        fail "$label: foreign project/person/product names"; sed 's/^/       /' "$WORK/hits"
    else
        pass "$label: no foreign names"
    fi

    # Only the sed-managed tokens must be gone; audit-prompt.md keeps its
    # deliberately LLM-filled placeholders.
    if grep -rnE '\{\{(PROJECT_ROOT|PROJECT_NAME|MEMORY_ROOT)\}\}' "$PROJ/.claude" >"$WORK/hits" 2>/dev/null; then
        fail "$label: unsubstituted tokens"; sed 's/^/       /' "$WORK/hits"
    else
        pass "$label: all tokens substituted"
    fi
}

printf "\n=== after claude-init.sh ===\n"
check_clean "init"

printf "\n=== scanner behaviour ===\n"
HOOK="$PROJ/.claude/scripts/x-precommit.sh"

# Negative control: 'escrow' was an XLent-only rule and must no longer block anyone.
mkdir -p "$PROJ/src"
printf 'export const escrowStatus = "held";\n' > "$PROJ/src/payments.ts"
git -C "$PROJ" add -A >/dev/null 2>&1
# Assert on the absence of a P-01/escrow finding rather than the exit code, so an
# unrelated violation elsewhere in the tree cannot mask or fake this result.
(cd "$PROJ" && bash "$HOOK") >"$WORK/escrow.log" 2>&1
if grep -qiE 'P-01|escrow' "$WORK/escrow.log"; then
    fail "escrow still reported"; grep -iE 'P-01|escrow' "$WORK/escrow.log" | sed 's/^/       /'
else
    pass "escrow code no longer reported (P-01 removed)"
fi

# Positive control: the scanner must still catch a real violation, proving the P-01
# deletion did not break the surrounding control flow.
printf 'export const note = "em\xe2\x80\x94dash";\n' > "$PROJ/src/bad.ts"
git -C "$PROJ" add -A >/dev/null 2>&1
if (cd "$PROJ" && bash "$HOOK") >"$WORK/q13.log" 2>&1; then
    fail "scanner did NOT catch a Q-13 violation - control flow may be broken"
    sed 's/^/       /' "$WORK/q13.log"
else
    pass "scanner still catches Q-13"
fi

printf "\n=== after claude-sync.sh ===\n"
if ! bash "$KIT_DIR/claude-sync.sh" "$PROJ" >"$WORK/sync.log" 2>&1; then
    fail "claude-sync.sh failed"; sed 's/^/       /' "$WORK/sync.log"
else
    check_clean "sync"
fi

printf "\n"
if [ "$FAILURES" -eq 0 ]; then
    printf "✅ selftest passed\n\n"; exit 0
fi
printf "❌ selftest failed (%s check(s))\n\n" "$FAILURES"; exit 1
