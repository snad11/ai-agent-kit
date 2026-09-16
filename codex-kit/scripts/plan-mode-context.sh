#!/usr/bin/env bash
# Injects the {{PROJECT_NAME}} planning standard into context while in plan mode.
# Registered as a UserPromptSubmit hook; stdout (exit 0) is appended to context.
input=$(cat)
mode=$(printf '%s' "$input" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("permission_mode",""))' 2>/dev/null)
[ "$mode" = "plan" ] || exit 0
cat <<'EOF'
[{{PROJECT_NAME}} plan-mode standard - apply before producing ANY plan]
Plan as a senior architect / security engineer. Specifically:
- Run the /x-implement Phase 0 discipline: read CLAUDE.md, .claude/rules.md, and the
  relevant audits/ + memory, then lock a SCOPE CONTRACT (in-scope / out-of-scope /
  files touched / acceptance) - do not expand scope mid-plan.
- Apply SOLID + DRY without over-engineering; reuse before create (Q-11).
- Treat every auth / authZ / data-mutation / secret / PII path as highest-risk;
  bake in ISO 27001 / OWASP Top 10 awareness and user-safe error UX (S-13).
- Tests ship with new behavior: when the plan adds an endpoint, component, widget, or
  function, fold test scaffolding AND a test-run step into the plan, per the project's
  testing rules (W-02 tests-with-features, Q-10 testing env, and any stack rule such as
  M-FL-12 for Flutter widgets). Omit only for typo / pure-style / asset changes - and
  say so explicitly in the plan.
- Never plan a bare test-run step: any plan that runs tests, migrations, or seeders
  must fold in the W-05 test-env preflight (a testing env exists AND names a database
  distinct from the dev one), and must stop and ask when the repo has no testing env.
- Surface in the plan which .claude/rules.md rules the change must satisfy.
EOF
