# BOOTSTRAP — set up a project with the GitHub Copilot kit

Reference this file in GitHub Copilot from the project you want to bootstrap:

```
@$KIT/copilot-kit/BOOTSTRAP.md please bootstrap this project
```

Or run the mechanical installer first, then return here for the
conversational phases:

```bash
bash $KIT/copilot-kit/copilot-init.sh .
```

---

## Instructions for the agent (read this entire file first)

You are bootstrapping a project with the GitHub Copilot kit. Multi-phase. Do not skip
phases. Do not answer questions on the user's behalf. Be senior-engineer-level
deliberate.

### Phase 0 — Confirm
Run `pwd`. State what you are about to do and ask the user to confirm the
working directory. **Wait for explicit confirmation before any file operation.**

### Phase 1 — Discover
`ls -la`. Detect the stack(s) actually present — do not assume, and ask if
unsure. Identify every repo in the workspace.

### Phase 2 — Context
Ask the user the project-context questions **one at a time**: what the project
is, who uses it, what is in flight, what must never break, deploy targets,
third-party services.

### Phase 3 — Audit
For each detected repo, run the audit in `.github/templates/audit-prompt.md`
over every source file, line by line. Use background agents where the tool
supports them. Write findings under `audits/`.

### Phase 4 — Rules
Review `.github/copilot-instructions.md`. Append project-specific rules discovered in Phase 3, using
the existing ID scheme and the Why/Detect/Fix template.

### Phase 5 — Memory
Author the project memory files, then re-run the memory clone so `.github/copilot-instructions.md`
carries them verbatim:

```bash
bash .github/scripts/clone-memory.sh .github/copilot-instructions.md <memory-dir>
```

### Phase 6 — Hooks and CI
```bash
bash .github/scripts/install-hooks.sh all
bash .github/scripts/install-workflows.sh all
```

---

## Constraints

- **Do not commit anything.**
- **Do not modify source code.** Only `.github/`, `.github/copilot-instructions.md`, `audits/`
  and the memory folder.
- Scoped rules use .instructions.md with applyTo frontmatter globs
