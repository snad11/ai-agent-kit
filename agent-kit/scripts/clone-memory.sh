#!/usr/bin/env bash
# clone-memory.sh — fold a memory folder verbatim into an AGENTS.md anchor.
#
# Why this exists: Claude Code auto-loads ~/.claude/projects/<key>/memory/ every
# session; most other agents (ZCode, Codex, Cursor) do not. Cloning the memory
# into AGENTS.md gives every agent the same always-in-context guarantee.
#
# Usage:
#   bash clone-memory.sh <anchor-file> <memory-dir>
#
#   <anchor-file>  path to AGENTS.md (must contain the BEGIN/END MEMORY CLONE markers)
#   <memory-dir>   directory of *.md memory files (e.g. ~/.agents/projects/<key>/memory)
#
# Idempotent: replaces only the content between the markers; everything outside
# is preserved. Each memory file becomes a level-2 section with its source path
# noted, ordered with MEMORY.md first (index) then the rest alphabetically.
#
# Called by agent-init.sh / agent-sync.sh. Safe to run standalone to refresh.

set -euo pipefail

ANCHOR="${1:?Usage: clone-memory.sh <anchor-file> <memory-dir>}"
MEMDIR="${2:?Usage: clone-memory.sh <anchor-file> <memory-dir>}"

[ -f "$ANCHOR" ] || { printf 'clone-memory: anchor not found: %s\n' "$ANCHOR" >&2; exit 1; }
[ -d "$MEMDIR" ] || { printf 'clone-memory: memory dir not found: %s\n' "$MEMDIR" >&2; exit 1; }

BEGIN='<!-- BEGIN MEMORY CLONE -->'
END='<!-- END MEMORY CLONE -->'

grep -qF "$BEGIN" "$ANCHOR" || { printf 'clone-memory: BEGIN marker missing in %s\n' "$ANCHOR" >&2; exit 1; }
grep -qF "$END"   "$ANCHOR" || { printf 'clone-memory: END marker missing in %s\n' "$ANCHOR" >&2; exit 1; }

# Build the clone body in a temp file.
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

{
  printf '\n'
  # Order: MEMORY.md first (it's the index), then the rest alphabetically.
  if [ -f "$MEMDIR/MEMORY.md" ]; then
    printf '## MEMORY.md - index\n*source: %s/MEMORY.md*\n\n' "$MEMDIR"
    # Strip YAML frontmatter from the index body; keep its prose.
    awk 'NR==1 && /^---/{fm=1; next} fm && /^---/{fm=0; next} !fm' "$MEMDIR/MEMORY.md"
    printf '\n\n---\n\n'
  fi
  for f in "$MEMDIR"/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    [ "$base" = "MEMORY.md" ] && continue   # already emitted
    stem="${base%.md}"
    printf '## %s\n*source: %s/%s*\n\n' "$stem" "$MEMDIR" "$base"
    awk 'NR==1 && /^---/{fm=1; next} fm && /^---/{fm=0; next} !fm' "$f"
    printf '\n\n---\n\n'
  done
} > "$TMP"

# Splice: everything up to BEGIN, the new body, everything from END onward.
python3 - "$ANCHOR" "$TMP" "$BEGIN" "$END" <<'PY'
import sys
anchor, body, begin, end = sys.argv[1:5]
with open(anchor, encoding="utf-8") as fh:
    text = fh.read()
i = text.index(begin) + len(begin)
j = text.index(end)
new = text[:i] + "\n" + open(body, encoding="utf-8").read() + text[j:]
with open(anchor, "w", encoding="utf-8") as fh:
    fh.write(new)
PY

printf '  cloned memory into %s\n' "$ANCHOR"
