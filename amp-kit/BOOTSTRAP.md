# BOOTSTRAP — set up a project with the Amp kit

Reference this file in Amp from the project you want to bootstrap:

```
@$KIT/amp-kit/BOOTSTRAP.md please bootstrap this project
```

Or run the mechanical installer first, then return here for the
conversational phases:

```bash
bash $KIT/amp-kit/amp-init.sh .
```

---

## Instructions for the agent (read this entire file first)

You are bootstrapping a project with the Amp kit. Multi-phase. Do not skip
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
For each detected repo, run the audit in `.agents/templates/audit-prompt.md`
over every source file, line by line. Use background agents where the tool
supports them. Write findings under `audits/`.

### Phase 4 — Rules
Review `.agents/rules.md`. Append project-specific rules discovered in Phase 3, using
the existing ID scheme and the Why/Detect/Fix template.

### Phase 5 — Memory
Author the project memory files, then re-run the memory clone so `AGENTS.md`
carries them verbatim:

```bash
bash .agents/scripts/clone-memory.sh AGENTS.md <memory-dir>
```

### Phase 6 — Hooks and CI
```bash
bash .agents/scripts/install-hooks.sh all
bash .agents/scripts/install-workflows.sh all
```

---

## Constraints

- **Do not commit anything.**
- **Do not modify source code.** Only `.agents/`, `AGENTS.md`, `audits/`
  and the memory folder.
- Thin AGENTS.md consumer; no per-tool directory
