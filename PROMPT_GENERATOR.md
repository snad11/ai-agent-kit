# CODEBASE WORK PROMPT

**Version:** 3.0
**Applies to:** any language, framework, or project type
**Consumed by:** `/x-implement` Phase 0, `/x-prompt`, or pasted directly into an agent

This file tells an agent how to turn a messy request into a scoped, verifiable plan before it
writes any code. It is agent-facing. Humans do not fill anything in here - they invoke
`/x-implement <task>` (or `PG <task>` for plan-only) and this framework runs behind it.

---

## Your agency

Decide these yourself. Do not ask:

- Which files to read, which searches to run, which existing helper to reuse
- Naming, file placement, and structure that match the conventions already in the repo
- Whether a change needs a test, and where that test goes
- The order of implementation steps
- Anything the repo, the request, or the execution context already answers

Ask before proceeding only when:

- Two readings of the request lead to materially different work, and the repo does not settle it
- The task collides with a rule in the project's rules file (see STEP 5)
- Implementation requires touching a file outside the agreed scope
- Proceeding on a wrong assumption would be unsafe or destroy data

**Maximum 3 questions.** If you have more than 3, the request is too vague to score - say so and
ask for detail, rather than firing a questionnaire.

## Detect before you ask

Prefer detection over questions. If an answer is already clear from the user's request, the repo,
or the execution context, do NOT ask. Proceed and state the assumption in your summary.

| Instead of asking | Detect it |
|---|---|
| "Which framework is this?" | Manifest files - see Appendix A |
| "What test runner do you use?" | `package.json` scripts, `phpunit.xml`, `pytest.ini`, `pubspec.yaml` |
| "Where should this component go?" | The directory holding the nearest sibling component |
| "What naming convention?" | Read 3 existing files in the same directory |
| "Which version of X?" | The lockfile or manifest. Never guess a version number |
| "Do you want tests?" | Yes. Asking for a feature is asking for a working, tested feature |
| "Should I follow SOLID / handle errors / consider security?" | Always yes - these are defaults, not options |
| "Is this multilingual?" | `l10n.yaml`, `messages/`, `locales/`, `lang/<locale>/`, an i18n dep |

A question you could have answered with one `grep` costs the user a round trip. Run the `grep`.

---

## STEP 1: INTELLIGENT PARSING

Categorize the request into four buckets. Every request produces all four, even when the user
only wrote one sentence - the missing buckets get filled from detection and defaults.

### INSTRUCTIONS (what to do)

- Action verbs: add, change, optimize, implement, fix, update, create, remove
- Feature requests: "I want X", "we need Y", "should have Z"
- Tasks: "make responsive", "add validation", "improve performance"

### CONSTRAINTS (how to do it / what NOT to do)

- Restrictions: "don't use", "avoid", "no hardcoding", "must use"
- Standards: "follow SOLID", "use TypeScript", "DRY"
- Limits: "under 2 seconds", "less than 100 lines", "max 200ms"
- Technology choices: "use Redis", "only native features"

**Always-infer defaults.** Apply these even when the user never mentions them:

- **Performance / Web Vitals** - for ANY frontend, UI, page, component, or loading-state work,
  performance is a default constraint. Design for LCP (never hide the largest element behind
  `opacity:0`), FCP (loading states show a real contentful element, not bare gray skeletons),
  INP (keep interaction handlers light - debounce, memoize, defer), CLS (reserve space, dimension
  images) and TTFB (static/ISR, cache server data) from the start. Code-split heavy or
  feature-flagged-off dependencies instead of importing them into the shared/root bundle, and
  verify the production bundle before deploy. Do it right while implementing. Never
  "build it, then fix performance later."
- **Security** - OWASP Top 10 and ISO 27001 awareness on every auth, authorization, data-mutation,
  secret, and PII path.
- **User-safe errors** - no raw server, SQL, stack, or third-party error text in a production UI.
- **Accessibility** - semantic markup, labels, focus order, contrast.
- **Tests** - new behavior ships with a test.

### EXPECTATIONS (what should happen)

- Success criteria: "should load in X", "user sees Y"
- Test scenarios: "when user does X, expect Y"
- Performance targets, UX requirements

When the user states no criteria, derive them from the action verb: "fix bug X" means bug X no
longer reproduces, and a test proves it.

### CONTEXT CLUES (background)

- Tech mentions: "the login page", "dashboard", "using Laravel"
- Current state: "already have X", "currently using Y"
- Which repo, screen, endpoint, or module is affected

---

## STEP 2: ASK ONLY WHAT DETECTION CANNOT ANSWER

Score the parsed request on four axes before deciding whether to ask anything.

| Axis | 3 (clear) | 2 (mostly clear) | 1 (ambiguous) | 0 (unknown) |
|---|---|---|---|---|
| **Scope** | Specific files or functions named, OR detection resolves them unambiguously | Feature plus repo identified | Feature named but spans repos | "fix the thing" |
| **Constraints** | Explicitly listed | Some listed, rest inferable from the rules file | None given, all from defaults | Request contradicts a rule |
| **Success** | Explicit acceptance criteria | Implied by the action verb | Vague ("make it better") | Subjective, no measurable signal |
| **Prior art** | Confirmed by search | Likely exists, easy to find | Unclear whether it exists | Cannot tell without a long search |

**An axis scores 3 when detection can answer it, even if the user never said it.** Run the search
first, then score. Scoring an axis low because the user did not spell something out, when one
`grep` would have settled it, is the most common failure of this step.

Decision:

- All four at 2 or above -> **ask nothing**, go to STEP 3
- One axis at 1 -> **one** question, about that axis
- Two or more at 1, or any at 0 -> **two or three** questions, then stop and wait
- Any axis at 0 AND the request contradicts a hard rule -> refuse, cite the rule, propose an
  alternative reading

Every question names its unknown and offers concrete options. Never ask
"anything to add or modify?" - that is not a question, it is a stall.

---

## STEP 3: CODEBASE ANALYSIS

Detect the project type from Appendix A, then extract only what the task needs:

1. **Language and framework**, with versions from the manifest or lockfile
2. **Architecture** - MVC, microservices, monolith, serverless; key directories; entry points
3. **Dependencies and tooling** - package manager, build tool, linter, formatter, type checker
4. **Data layer** - database, ORM, cache, client-side state management
5. **Configuration** - env files, config modules, environment-specific overrides
6. **Testing** - framework, test locations, how the suite is invoked, which env it loads
7. **Styling and UI library** (frontend)
8. **API shape** - REST, GraphQL, tRPC, gRPC; the response envelope already in use
9. **Authentication** - method and token storage
10. **i18n** - whether the project is multilingual, and which locale files exist

Then read three to five existing files near the work to pick up naming conventions, file
organization, import style, error handling, async patterns, and comment density. Match what is
there. Do not import a style the repo does not use.

**Reuse before create.** Search for an existing helper, component, or service that already does
this, or most of it. A new abstraction is justified only after the search comes back empty.

---

## STEP 4: FINAL STRUCTURED OUTPUT

```markdown
## CONTEXT
**Project type:** [detected]
**Stack:** [languages, frameworks, versions]
**Architecture:** [pattern]
**Relevant files:** [paths this task touches]
**Prior art found:** [existing code being reused, with paths]

## INSTRUCTIONS
**Must have:** [...]
**Should have:** [...]
**Deferred:** [explicitly out of this change]

## CONSTRAINTS
**Stated:** [from the user]
**Inferred:** [from the rules file and the defaults, each with its rule ID]
**Do NOT:** [anti-patterns specific to this task]

## EXPECTATIONS
**When [action], then [result]:** [...]
**Tests:** [which files, which cases, which command and env flag]
**Performance targets:** [if frontend or a hot path]

## PLAN
1. [concrete step, with file path]
2. [concrete step, with file path]

## OUT OF SCOPE
- [files and refactors this change will not touch]
```

---

## STEP 5: RULE COLLISION CHECK

Before writing code, walk the parsed Instructions and Constraints against the project's rules file
(`.claude/rules.md`, `.agents/rules.md`, or the project's equivalent). Name every rule that
constrains the work, with a one-line reason, in the output from STEP 4.

Hard-blocked requests stop here. Cite the rule, explain what it forbids, and propose the nearest
thing you can build instead.

---

## Constraints - Do NOT

- **Do NOT refactor unrelated code.** Touching a file does not license cleaning it.
- **Do NOT widen scope silently.** If the work needs a file outside the agreed scope, stop and
  re-negotiate before editing it.
- **Do NOT add dependencies** that were not asked for. Reach for what the project already has.
- **Do NOT invent version numbers.** Read them from the lockfile or manifest. If a version cannot
  be resolved from the repo, say so rather than guessing.
- **Do NOT run destructive commands** - `migrate:fresh`, `db:wipe`, `prisma migrate reset`,
  `drop database` - outside a verified testing environment, even when a test seems to need it.
- **Do NOT run a test suite without confirming which env file loads and which database it names.**
  A bare `php artisan test` / `pnpm test` / `pytest` loads the development env, and a
  refresh-database suite drops every table in it.
- **Do NOT commit or push** unless the user asked.
- **Do NOT report work as done when it is not.** If a step was skipped or a test failed, say so,
  with the output.
- **Do NOT narrate the code in comments.** Comments carry the WHY the code cannot say.
- **Do NOT paste raw server, SQL, or stack-trace text into a user-facing surface.**

## Required outcomes

Every item is observable. A run is not finished until each is true or explicitly waived with a
stated reason.

- [ ] The parsed request was restated back, and the user's intent survived the restatement
- [ ] Every axis in STEP 2 scored 2 or higher, or a question was asked about the one that did not
- [ ] Fewer than four questions were asked, and none had an answer already in the repo
- [ ] Existing code was searched before any new helper or component was written
- [ ] Every file changed is named in the report, with what changed and why
- [ ] Every rule that applies was listed, and the diff satisfies each one
- [ ] New behavior has a matching test file, or the waiver reason is stated
- [ ] Tests were run with an explicit testing env flag, and the report names the env and database
- [ ] No file gained an inline comment that paraphrases the line beneath it
- [ ] No file gained an em dash, smart quote, ellipsis character, or zero-width character
- [ ] Frontend changes name the LCP element and confirm it paints without an entrance animation
- [ ] Nothing outside the agreed scope was modified

## Troubleshooting - symptom to root cause

| Symptom | Root cause | Fix |
|---|---|---|
| The change touched files nobody agreed to | Scope was never locked, or was widened mid-run | Re-read the STEP 4 output; revert out-of-scope edits; re-negotiate before touching them |
| The agent asked something answerable by `grep` | STEP 2 was scored before detection ran | Score axes only after Appendix A detection and a prior-art search |
| Four or more questions were asked | The request was too vague, but got a questionnaire instead of a callout | Stop, say the request needs detail, name what is missing |
| Tests were written but never run | No env flag was resolved, so the run was skipped silently | Resolve the testing env first; if none exists, report that and do not run |
| A test run wiped development data | The suite loaded the default env, which points at the dev database | Never run without naming the env file and database first |
| Project-specific rules vanished after a kit sync | The rules file had no sentinel, so the sync rebuilt it from the kit | Repair the sentinel before syncing; keep the in-project backup |
| The plan-mode hook did not fire | The hook is not registered in the agent's settings for this target | Re-run the plan-hook installer for the correct target |
| The report claims done, but the feature does not work | Completion was inferred from edits rather than verified | Run the code; report the actual output, including failures |
| A user saw a raw SQL or stack-trace string | A new error path shipped without env gating | Gate the detail on the environment; show a plain message in production |

---

## Appendix A - stack detection matrix

**Backend**

| Marker | Stack |
|---|---|
| `composer.json`, `artisan` | PHP - Laravel |
| `composer.json`, no `artisan` | PHP - Symfony, CodeIgniter, plain |
| `nest-cli.json` | Node - NestJS |
| `package.json` plus server entry | Node - Express, Fastify |
| `manage.py` | Python - Django |
| `fastapi` in `pyproject.toml` or `requirements*.txt` | Python - FastAPI |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `pom.xml`, `build.gradle` | Java - Spring Boot |
| `Gemfile` | Ruby - Rails, Sinatra |
| `mix.exs` | Elixir - Phoenix |

**Frontend**

| Marker | Stack |
|---|---|
| `next.config.*` | Next.js |
| `nuxt.config.*` | Nuxt (implies Vue) |
| `vite.config.*` plus a `react` dep, no Next | React on Vite |
| `vite.config.*` plus a `vue` dep, no Nuxt | Vue on Vite |
| `angular.json` | Angular |
| `svelte.config.js` | Svelte, SvelteKit |
| `astro.config.mjs` | Astro |

**Mobile and desktop**

| Marker | Stack |
|---|---|
| `pubspec.yaml` | Flutter |
| `metro.config.*`, `app.json` | React Native, Expo |
| `*.xcodeproj` plus Swift | iOS native |
| `build.gradle` plus Kotlin | Android native |
| `tauri.conf.json` | Tauri |
| `electron-builder.json` | Electron |
| `*.csproj` | .NET, WPF |

**i18n**

| Marker | Stack |
|---|---|
| `l10n.yaml`, `lib/l10n/*.arb` | Flutter |
| `next-intl`, `next-i18next`, `messages/`, `app/[locale]/` | Next.js |
| `@nuxtjs/i18n`, `vue-i18n`, `locales/*.json` | Nuxt, Vue |
| `lang/<locale>/` | Laravel |
| `locale/*/LC_MESSAGES/*.po` | Django |

---

## Appendix B - worked examples

**Messy paragraph**

> I want to add user authentication, use JWT, store them in httpOnly cookies, hash passwords with
> bcrypt, add rate limiting, use Redis for sessions, write tests, and make sure it works with our
> existing user model. Oh and add 2FA later maybe but not now.

```
INSTRUCTIONS: JWT auth; bcrypt hashing; rate limiting on auth endpoints; Redis session store
CONSTRAINTS: httpOnly cookies, not localStorage; never store plaintext; integrate the existing
             user model; plus inferred - OWASP A07, lockout threshold, user-safe auth errors
EXPECTATIONS: brute force blocked; tokens not readable by JS; every auth flow tested
DEFERRED:     2FA
QUESTIONS:    none - lockout threshold and token TTL come from the rules file defaults
```

**Bullet points**

> dark mode for entire app / toggle in settings / remember user choice / smooth transitions /
> test on mobile / don't use libraries / localStorage for persistence

```
INSTRUCTIONS: theme system; settings toggle; persist preference
CONSTRAINTS: no external libraries; localStorage; CSS transitions; plus inferred - no flash of
             wrong theme on load, respect prefers-color-scheme as the initial value
EXPECTATIONS: preference survives reload; transitions do not cause layout shift (CLS)
QUESTIONS:    none - the existing theme tokens were found in the stylesheet
```

**Stream of consciousness**

> The dashboard loads way too slow, need to optimize it. Maybe virtualize the table? We're loading
> like 10k rows. Also cache the API response. Keep the filters working. Don't break anything, we
> have users on production. Add loading states.

```
INSTRUCTIONS: virtualize the table; cache the API response; add loading states
CONSTRAINTS: filters keep working; zero breaking changes; plus inferred - the loading state must
             contain a real contentful element (FCP), and reserve row height (CLS)
EXPECTATIONS: 10k rows scroll without jank; cache has a stated invalidation trigger
QUESTIONS:    1 - what invalidates the cached response, a TTL or a write?
              (Scope, success, and prior art all detected; only this one is unresolvable.)
```

---

**Version:** 3.0 - detect-first edition
**Changed from 2.0:** removed the fill-in-the-blank template (the entry point is `/x-implement`);
added agency and detect-before-asking rules; rewrote clarifying questions as a scored, capped
decision; added the Do NOT block, the Required outcomes checklist, and the troubleshooting table;
moved detection tables to Appendix A.