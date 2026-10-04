# BOOTSTRAP — set up a project with the Windsurf kit

Reference this file in Windsurf from the project you want to bootstrap:

```
@$KIT/windsurf-kit/BOOTSTRAP.md please bootstrap this project
```

Or run the mechanical installer first, then return here for the
conversational phases:

```bash
bash $KIT/windsurf-kit/windsurf-init.sh .
```

---

## Instructions for the agent (read this entire file first)

You are bootstrapping a project with the Windsurf kit. Multi-phase. Do not skip
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
For each detected repo, run the audit in `.windsurf/kit/templates/audit-prompt.md`
over every source file, line by line. Use background agents where the tool
supports them. Write findings under `audits/`.

### Phase 4 — Rules
Review `.windsurf/rules/project-rules.md`. Append project-specific rules discovered in Phase 3, using
the existing ID scheme and the Why/Detect/Fix template.

### Phase 5 — Memory
Author the project memory files, then re-run the memory clone so `AGENTS.md`
carries them verbatim:

```bash
bash .windsurf/kit/scripts/clone-memory.sh AGENTS.md <memory-dir>
```

### Phase 6 — Hooks and CI
```bash
bash .windsurf/kit/scripts/install-hooks.sh all
bash .windsurf/kit/scripts/install-workflows.sh all
```

---

## Constraints

- **Do not commit anything.**
- **Do not modify source code.** Only `.windsurf/kit/`, `AGENTS.md`, `audits/`
  and the memory folder.
- Current builds prefer .devin/rules/ which takes precedence over .windsurf/
- **Keep tracking ids out of the repos (Q-18, Q-17).** Nothing the bootstrap writes, and nothing written in the project afterwards, cites an epic/story id, an audit finding number, a rule id in parentheses, a spec section tag or a person's name: comments say what the code does or guards against. Commit subjects are Conventional Commits with no story id. The installed `pre-commit` and `commit-msg` hooks and CI enforce both.
- **Start every change from a usage story (W-07, Q-19, Q-20, D-07).** The agent writes how the user will use the change before coding, changes only what that story needs, and lists each API field with the client that reads it, reusing existing columns. `/x-implement` Phase 0 and Phase 2 enforce this; reviewers check it.

