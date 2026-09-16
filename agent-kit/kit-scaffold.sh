#!/usr/bin/env bash
# kit-scaffold.sh — generate each per-agent kit from kits.manifest + templates.
#
# Usage:  bash kit-scaffold.sh [--check] [kit-name ...]
#
# Generates, per row in kits.manifest:
#   <kit>/<prefix>-init.sh        from templates/kit-init.sh.template
#   <kit>/templates/<ANCHOR>.template   (anchor, derived from AGENTS.md.template)
#   <kit>/README.md               if absent (hand-editable thereafter)
#   <kit>/BOOTSTRAP.md            if absent (hand-editable thereafter)
#
# Shared assets (rules, skills, scripts, workflows) are NOT handled here —
# kit-sync.sh mirrors those. Run kit-scaffold.sh first, then kit-sync.sh.
#
# --check regenerates into a temp dir and exits 1 if any committed file differs,
# so CI catches a hand-edited generated file.

set -euo pipefail

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'
BOLD=$'\033[1m'; NC=$'\033[0m'

SRC="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SRC/.." && pwd)"
MANIFEST="$SRC/kits.manifest"
TEMPLATE="$SRC/templates/kit-init.sh.template"

[ -f "$MANIFEST" ] || { printf 'kit-scaffold: missing %s\n' "$MANIFEST" >&2; exit 2; }
[ -f "$TEMPLATE" ] || { printf 'kit-scaffold: missing %s\n' "$TEMPLATE" >&2; exit 2; }

CHECK=0; ONLY=()
for arg in "$@"; do
    case "$arg" in
        --check) CHECK=1 ;;
        -*) printf 'kit-scaffold: unknown flag %s\n' "$arg" >&2; exit 2 ;;
        *) ONLY+=("$arg") ;;
    esac
done

# Emit the command-generation block for a kit, given its command format.
# Each block converts the shared skills/*/SKILL.md into that agent's command format.
emit_commands_block() {
    local cmdfmt="$1" cmddir="$2"
    case "$cmdfmt" in
        none)
            cat <<'BLOCK'
printf '%sSkills...%s\n' "$BOLD" "$NC"
printf '  %snote%s this agent has no slash-command format; the skills are\n' "$BLUE" "$NC"
printf '       described as workflows inside the anchor file instead.\n\n'
BLOCK
            ;;
        toml)
            cat <<BLOCK
printf '%sGenerating slash commands...%s\n' "\$BOLD" "\$NC"
mkdir -p "\$TARGET/$cmddir"
for skill_dir in "\$KIT_DIR/skills"/*/; do
    [ -d "\$skill_dir" ] || continue
    name="\$(basename "\$skill_dir")"
    src="\$skill_dir/SKILL.md"
    [ -f "\$src" ] || continue
    tmp="\$(mktemp)"; subst_copy "\$src" "\$tmp"
    # Read the description AFTER substitution, or tokens leak into the TOML.
    desc="\$(sed -n 's/^description: *//p' "\$tmp" | head -1)"
    # Strip YAML frontmatter; the body becomes the command prompt.
    body="\$(sed '1{/^---\$/!q;}; 1,/^---\$/d' "\$tmp")"
    {
        printf 'description = "%s"\n\n' "\$(printf '%s' "\$desc" | sed 's/"/\\\\"/g')"
        printf 'prompt = """\n%s\n"""\n' "\$body"
    } > "\$TARGET/$cmddir/\${name}.toml"
    rm -f "\$tmp"
    printf '  %sok%s $cmddir/%s.toml\n' "\$GREEN" "\$NC" "\$name"
done
printf '\n'
BLOCK
            ;;
        mdc|md)
            local ext="md"; [ "$cmdfmt" = "mdc" ] && ext="mdc"
            cat <<BLOCK
printf '%sGenerating commands...%s\n' "\$BOLD" "\$NC"
mkdir -p "\$TARGET/$cmddir"
for skill_dir in "\$KIT_DIR/skills"/*/; do
    [ -d "\$skill_dir" ] || continue
    name="\$(basename "\$skill_dir")"
    [ -f "\$skill_dir/SKILL.md" ] || continue
    subst_copy "\$skill_dir/SKILL.md" "\$TARGET/$cmddir/\${name}.$ext"
    printf '  %sok%s $cmddir/%s.$ext\n' "\$GREEN" "\$NC" "\$name"
done
printf '\n'
BLOCK
            ;;
        instructions)
            cat <<BLOCK
printf '%sGenerating scoped instructions...%s\n' "\$BOLD" "\$NC"
mkdir -p "\$TARGET/$cmddir"
for skill_dir in "\$KIT_DIR/skills"/*/; do
    [ -d "\$skill_dir" ] || continue
    name="\$(basename "\$skill_dir")"
    [ -f "\$skill_dir/SKILL.md" ] || continue
    out="\$TARGET/$cmddir/\${name}.instructions.md"
    tmp="\$(mktemp)"; subst_copy "\$skill_dir/SKILL.md" "\$tmp"
    { printf -- '---\napplyTo: "**"\n---\n\n'; sed '1{/^---\$/!q;}; 1,/^---\$/d' "\$tmp"; } > "\$out"
    rm -f "\$tmp"
    printf '  %sok%s $cmddir/%s.instructions.md\n' "\$GREEN" "\$NC" "\$name"
done
printf '\n'
BLOCK
            ;;
    esac
}

emit_plan_hook_block() {
    case "$1" in
        none)
            cat <<'BLOCK'
printf '%sPlan-mode hook...%s\n' "$BOLD" "$NC"
printf '  %snote%s this agent exposes no UserPromptSubmit hook; the context\n' "$BLUE" "$NC"
printf '       script is available but not auto-registered.\n\n'
BLOCK
            ;;
        *) printf 'bash "$KIT_DIR/scripts/install-plan-hook.sh" "$TARGET"\n' ;;
    esac
}

generate_kit() {
    local kit="$1" label="$2" tooldir="$3" anchor="$4" rules="$5" \
          cmddir="$6" cmdfmt="$7" planhook="$8" note="$9"
    local prefix="${kit%-kit}"
    local outdir="$ROOT/$kit"
    [ "$CHECK" -eq 1 ] && outdir="$(mktemp -d)/$kit"
    mkdir -p "$outdir"

    # Where per-project scaffolding lives. Agents with no tool dir fall back to .agents/.
    local basedir="$tooldir"
    [ "$basedir" = "-" ] && basedir=".agents"
    # install-workflows.sh resolves the CI yaml as ../workflows relative to the
    # scripts dir, so the kit's staging dir is always <basedir>/workflows. If the
    # agent itself owns <basedir>/workflows (Windsurf does), nest the kit's own
    # scaffolding one level deeper so the CI yaml cannot be mistaken for one of
    # the agent's workflows.
    if [ "$cmddir" = "$basedir/workflows" ]; then
        basedir="$basedir/kit"
    fi

    local anchor_template
    case "$anchor" in
        GEMINI.md)      anchor_template="GEMINI.md.template" ;;
        CONVENTIONS.md) anchor_template="CONVENTIONS.md.template" ;;
        .github/copilot-instructions.md) anchor_template="COPILOT.md.template" ;;
        *)              anchor_template="AGENTS.md.template" ;;
    esac

    local cmdnote="no slash-command format for this agent"
    [ "$cmdfmt" != "none" ] && cmdnote="$cmddir/  ($cmdfmt commands generated from the shared skills)"

    local mk_tooldir="" mk_cmddir=""
    [ "$tooldir" != "-" ] && mk_tooldir="mkdir -p \"\$TARGET/$tooldir\""
    [ "$cmddir" != "-" ] && mk_cmddir="mkdir -p \"\$TARGET/$cmddir\""

    local cmd_block hook_block extra_anchor=""
    cmd_block="$(emit_commands_block "$cmdfmt" "$cmddir")"
    hook_block="$(emit_plan_hook_block "$planhook")"

    # Zed loads .rules ahead of AGENTS.md, so write both from the same source.
    if [ "$kit" = "zed-kit" ]; then
        extra_anchor='printf '"'"'%sWriting AGENTS.md alongside .rules...%s\n'"'"' "$BOLD" "$NC"
cp "$TARGET/@@ANCHOR@@" "$TARGET/AGENTS.md"
printf '"'"'  %sok%s AGENTS.md (mirror of .rules -- Zed reads .rules first)\n\n'"'"' "$GREEN" "$NC"'
        extra_anchor="${extra_anchor//@@ANCHOR@@/$anchor}"
    fi

    python3 - "$TEMPLATE" "$outdir/${prefix}-init.sh" \
        "$prefix" "$label" "$anchor" "$rules" "$basedir" "$anchor_template" \
        "$cmdnote" "$note" "$mk_tooldir" "$mk_cmddir" \
        "$cmd_block" "$hook_block" "$extra_anchor" <<'PY'
import sys
(tpl, out, prefix, label, anchor, rules, basedir, anchor_tpl,
 cmdnote, note, mk_tooldir, mk_cmddir, cmd_block, hook_block, extra_anchor) = sys.argv[1:16]
s = open(tpl).read()
for k, v in {
    "@@PREFIX@@": prefix, "@@LABEL@@": label, "@@ANCHOR@@": anchor, "@@RULES@@": rules,
    "@@SCRIPTSDIR@@": basedir + "/scripts",
    "@@WORKFLOWSDIR@@": basedir + "/workflows",
    "@@TEMPLATESDIR@@": basedir + "/templates",
    "@@ANCHORTEMPLATE@@": anchor_tpl, "@@CMDNOTE@@": cmdnote, "@@NOTE@@": note,
    "@@MKDIR_TOOLDIR@@": mk_tooldir, "@@MKDIR_CMDDIR@@": mk_cmddir,
    "@@EMIT_COMMANDS@@": cmd_block, "@@PLAN_HOOK@@": hook_block,
    "@@EXTRA_ANCHOR@@": extra_anchor,
}.items():
    s = s.replace(k, v)
assert "@@" not in s, "unsubstituted @@TOKEN@@ remains: " + \
    s[s.index("@@"):s.index("@@")+40]
open(out, "w").write(s)
PY
    # Each kit needs its own _subst.sh: the path tokens differ per agent, and
    # kit-sync.sh treats _subst.sh as kit-owned so it is never mirrored.
    mkdir -p "$outdir/scripts"
    local skills_dir="$cmddir" skills_intro
    if [ "$cmdfmt" = "none" ]; then
        skills_dir="$basedir/skills"
        skills_intro="This agent has no slash-command format, so the skills below are workflows to follow manually rather than invokable commands. Same names and behavior across agents:"
    else
        # No backticks: this string is interpolated into a double-quoted sed
        # expression, where a backtick would be command substitution.
        skills_intro="The skills install to $cmddir/ as $cmdfmt commands. Same names and behavior across agents:"
    fi
    cat > "$outdir/scripts/_subst.sh" <<SUBST
#!/usr/bin/env bash
# Template substitution for ${prefix}-init.sh.
#
# GENERATED FILE — do not edit by hand.
# Regenerate: bash agent-kit/kit-scaffold.sh
#
# Sourced, never executed. Callers must have TARGET, PROJECT_NAME and MEMORY_ROOT set.
# Path tokens are fixed for this kit because it only ever emits ${label} layout.

subst_copy() {
    local src="\$1"
    local dst="\$2"
    : "\${TARGET:?subst_copy: TARGET is not set}"
    : "\${PROJECT_NAME:?subst_copy: PROJECT_NAME is not set}"
    : "\${MEMORY_ROOT:?subst_copy: MEMORY_ROOT is not set}"
    local memory_hint="~\${MEMORY_ROOT#"\$HOME"}"
    sed -e "s|{{PROJECT_ROOT}}|\${TARGET}|g" \\
        -e "s|{{PROJECT_NAME}}|\${PROJECT_NAME}|g" \\
        -e "s|{{MEMORY_ROOT}}|\${MEMORY_ROOT}|g" \\
        -e "s|{{MEMORY_DIR_HINT}}|\${memory_hint}|g" \\
        -e "s|{{AGENT_TARGET}}|${prefix}|g" \\
        -e "s|{{ANCHOR_FILE}}|${anchor}|g" \\
        -e "s|{{RULES_PATH}}|${rules}|g" \\
        -e "s|{{SKILLS_DIR}}|${skills_dir}|g" \\
        -e "s|{{SKILLS_INTRO}}|${skills_intro}|g" \\
        -e "s|{{TEMPLATES_DIR}}|${basedir}/templates|g" \\
        "\$src" > "\$dst"
}
SUBST
    bash -n "$outdir/scripts/_subst.sh"

    # README.md and BOOTSTRAP.md are generated once and then hand-editable:
    # regenerating never clobbers prose someone has since written.
    if [ ! -f "$ROOT/$kit/README.md" ] || [ "$CHECK" -eq 1 ]; then
        local cmdline="This agent has no slash-command format. The seven skills ship as documented workflows inside \`$anchor\`, not as invokable commands."
        if [ "$cmdfmt" != "none" ]; then
            cmdline="The seven skills are installed as \`$cmdfmt\` commands in \`$cmddir/\`: \`/x-implement\`, \`/x-check\`, \`/x-rules\`, \`/x-prompt\`, \`/x-check-file\`, \`/x-add-rule\`, \`/x-audit\`."
        fi
        cat > "$outdir/README.md" <<README
# ${label} kit

Installs the shared **skills + rules + memory + hooks** system into any project,
in the layout ${label} actually reads.

> \`\$KIT\` is your clone of this repo — e.g. \`export KIT=~/ai-agent-kit\`.
> See the [root README](../README.md#install).

## Quick start

\`\`\`bash
cd /path/to/your/project
bash \$KIT/$kit/${prefix}-init.sh .
\`\`\`

Then finish the conversational phases by referencing \`@\$KIT/$kit/BOOTSTRAP.md\`
in ${label}.

## What it writes

| Path | What it is |
|---|---|
| \`$anchor\` | The file ${label} reads automatically. Rules index + memory clone. |
| \`$rules\` | Universal rule baseline plus auto-detected stack modules. |
| \`$basedir/scripts/\` | Pre-commit scanner, hook + workflow installers, memory cloner. |
| \`$basedir/workflows/x-check.yml\` | GitHub Actions check, staged into \`.github/\` by \`install-hooks.sh\`. |

## Commands

$cmdline

## Caveat

$note

## Keeping in step

This kit's shared assets are mirrored from \`agent-kit\`, and \`${prefix}-init.sh\`
is generated. Do not hand-edit either:

\`\`\`bash
bash \$KIT/agent-kit/kit-scaffold.sh   # regenerate installers
bash \$KIT/agent-kit/kit-sync.sh       # mirror rules/skills/scripts
bash \$KIT/agent-kit/kit-sync.sh --check   # CI gate
\`\`\`
README
        cat > "$outdir/BOOTSTRAP.md" <<BOOTSTRAP
# BOOTSTRAP — set up a project with the ${label} kit

Reference this file in ${label} from the project you want to bootstrap:

\`\`\`
@\$KIT/$kit/BOOTSTRAP.md please bootstrap this project
\`\`\`

Or run the mechanical installer first, then return here for the
conversational phases:

\`\`\`bash
bash \$KIT/$kit/${prefix}-init.sh .
\`\`\`

---

## Instructions for the agent (read this entire file first)

You are bootstrapping a project with the ${label} kit. Multi-phase. Do not skip
phases. Do not answer questions on the user's behalf. Be senior-engineer-level
deliberate.

### Phase 0 — Confirm
Run \`pwd\`. State what you are about to do and ask the user to confirm the
working directory. **Wait for explicit confirmation before any file operation.**

### Phase 1 — Discover
\`ls -la\`. Detect the stack(s) actually present — do not assume, and ask if
unsure. Identify every repo in the workspace.

### Phase 2 — Context
Ask the user the project-context questions **one at a time**: what the project
is, who uses it, what is in flight, what must never break, deploy targets,
third-party services.

### Phase 3 — Audit
For each detected repo, run the audit in \`$basedir/templates/audit-prompt.md\`
over every source file, line by line. Use background agents where the tool
supports them. Write findings under \`audits/\`.

### Phase 4 — Rules
Review \`$rules\`. Append project-specific rules discovered in Phase 3, using
the existing ID scheme and the Why/Detect/Fix template.

### Phase 5 — Memory
Author the project memory files, then re-run the memory clone so \`$anchor\`
carries them verbatim:

\`\`\`bash
bash $basedir/scripts/clone-memory.sh $anchor <memory-dir>
\`\`\`

### Phase 6 — Hooks and CI
\`\`\`bash
bash $basedir/scripts/install-hooks.sh all
bash $basedir/scripts/install-workflows.sh all
\`\`\`

---

## Constraints

- **Do not commit anything.**
- **Do not modify source code.** Only \`$basedir/\`, \`$anchor\`, \`audits/\`
  and the memory folder.
- $note
BOOTSTRAP
    fi

    chmod +x "$outdir/${prefix}-init.sh"
    bash -n "$outdir/${prefix}-init.sh"

    if [ "$CHECK" -eq 1 ]; then
        if ! cmp -s "$outdir/${prefix}-init.sh" "$ROOT/$kit/${prefix}-init.sh" || \
           ! cmp -s "$outdir/scripts/_subst.sh" "$ROOT/$kit/scripts/_subst.sh"; then
            printf '  %sdrift%s %s/%s-init.sh (regenerate: bash agent-kit/kit-scaffold.sh)\n' \
                "$YELLOW" "$NC" "$kit" "$prefix"
            return 1
        fi
        printf '  %sok%s %s\n' "$GREEN" "$NC" "$kit"
        return 0
    fi
    printf '  %sok%s %s/%s-init.sh\n' "$GREEN" "$NC" "$kit" "$prefix"
    return 0
}

printf '%skit-scaffold: generating from %s%s\n\n' "$BOLD" "$(basename "$MANIFEST")" "$NC"
failed=0
while IFS='|' read -r kit label tooldir anchor rules cmddir cmdfmt planhook note; do
    case "$kit" in ''|\#*) continue ;; esac
    if [ "${#ONLY[@]}" -gt 0 ]; then
        skip=1; for k in "${ONLY[@]}"; do [ "$k" = "$kit" ] && skip=0; done
        [ "$skip" -eq 1 ] && continue
    fi
    generate_kit "$kit" "$label" "$tooldir" "$anchor" "$rules" \
                 "$cmddir" "$cmdfmt" "$planhook" "$note" || failed=$((failed+1))
done < "$MANIFEST"

printf '\n'
if [ "$CHECK" -eq 1 ]; then
    [ "$failed" -eq 0 ] && { printf '%s%sall generated files current%s\n' "$GREEN" "$BOLD" "$NC"; exit 0; }
    printf '%s%s%s kit(s) out of date%s\n' "$RED" "$BOLD" "$failed" "$NC" >&2; exit 1
fi
printf '%s%sgenerated %s kit(s)%s\n' "$GREEN" "$BOLD" "$(grep -vc '^#' "$MANIFEST")" "$NC"
