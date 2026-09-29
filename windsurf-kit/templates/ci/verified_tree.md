# Verify each unique code tree once

Rule W-06. A promotion flow (`development` -> `staging` -> `production`, or `dev` -> `staging`,
or `develop` -> `main`) runs the same verify job at every hop. The code does not change on a
merge, so the second and third runs re-prove what the first already proved, and a 20 minute
suite costs an hour to move one release through.

`verified_tree.sh` keys on the **git tree SHA**. The tree names the file contents, so it is
identical across a merge commit but different after any edit, including a lockfile, a tool
version file or the workflow itself. A verify job that passes uploads an artifact named
`verified-<salt>-<tree>`; a later job that finds that artifact skips its checks.

Three properties make this safe to rely on:

- **Artifacts are repo-wide.** Actions caches are branch-scoped, so a cache cannot carry the
  marker from one branch to the next. Do not substitute a cache for the artifact.
- **Unverified code always runs.** A direct push of new code to `staging` has a tree no run has
  ever marked, so it gets the full suite. The gate can only skip code that already passed.
- **Failure means run.** Any lookup error falls back to `verified=false`, so a bad token, a
  rate limit or an API change costs a redundant run rather than hiding a broken tree.

## Install

Copy `verified_tree.sh` into the repo at whatever path matches its layout (`tool/ci/`,
`.github/scripts/`, `scripts/ci/`) and make it executable. Then wire the workflow.

The workflow **must** grant `actions: read`, or the artifact lookup returns 403, the gate
fail-safes to `verified=false`, and the change silently saves nothing:

```yaml
permissions:
  contents: read
  actions: read
```

## Single-job verify workflow

```yaml
jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<pin>

      - id: gate
        name: Already verified?
        env:
          GH_TOKEN: ${{ github.token }}
        run: bash tool/ci/verified_tree.sh

      - if: steps.gate.outputs.verified != 'true'
        run: <install deps>
      - if: steps.gate.outputs.verified != 'true'
        run: <lint>
      - if: steps.gate.outputs.verified != 'true'
        run: <test>
      - if: steps.gate.outputs.verified != 'true'
        run: <build check>

      - name: Mark verified
        if: steps.gate.outputs.verified != 'true'
        run: echo "${{ github.sha }}" > verified.txt
      - if: steps.gate.outputs.verified != 'true'
        uses: actions/upload-artifact@<pin>
        with:
          name: ${{ steps.gate.outputs.marker }}
          path: verified.txt
          retention-days: 30
```

## Multi-job verify workflow

A step output is not visible to another job, and the marker must not be written until every
verify job has passed. Put the gate in its own job and read it through `needs`:

```yaml
jobs:
  gate:
    runs-on: ubuntu-latest
    outputs:
      verified: ${{ steps.gate.outputs.verified }}
      marker: ${{ steps.gate.outputs.marker }}
    steps:
      - uses: actions/checkout@<pin>
      - id: gate
        name: Already verified?
        env:
          GH_TOKEN: ${{ github.token }}
        run: bash tool/ci/verified_tree.sh

  lint:
    needs: gate
    if: needs.gate.outputs.verified != 'true'
    # ...unchanged...

  test:
    needs: [gate, lint]
    if: needs.gate.outputs.verified != 'true'
    # ...unchanged...

  mark-verified:
    needs: [gate, lint, test]
    if: ${{ success() && needs.gate.outputs.verified != 'true' }}
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ github.sha }}" > verified.txt
      - uses: actions/upload-artifact@<pin>
        with:
          name: ${{ needs.gate.outputs.marker }}
          path: verified.txt
          retention-days: 30
```

## What to gate and what to leave alone

| Gate it | Leave it running |
|---|---|
| Dependency install and toolchain setup that only serves the checks | Anything that produces or ships an artifact users receive |
| Lint, format check, static analysis, type check | Release builds, signing, store uploads, image pushes |
| Unit, integration and e2e tests | Deploys to any environment |
| Build checks whose only purpose is proving the build compiles | Steps whose result depends on more than the tree (see below) |

Two traps:

- **A job that consumes a skipped job's artifact must skip too.** If `build` uploads something
  `e2e` downloads, gating `build` alone leaves `e2e` to fail on a missing artifact.
- **A step whose `if:` reads an output of a gated step needs the gate in its own condition.**
  `if: steps.check.outputs.code != '0'` is true when the output is empty, so it fires on every
  skipped run. Add `&& steps.gate.outputs.verified != 'true'`, or gate the step outright.

## Verify the gate locally

```bash
GITHUB_REPOSITORY=<owner/repo> GITHUB_OUTPUT=/tmp/gate bash tool/ci/verified_tree.sh
cat /tmp/gate                  # tree=<40 hex>, marker=verified-v1-<tree>, verified=false
git rev-parse 'HEAD^{tree}'    # must match tree above

GH_TOKEN=invalid GITHUB_REPOSITORY=x/y GITHUB_OUTPUT=/tmp/gate2 bash tool/ci/verified_tree.sh
grep verified=false /tmp/gate2 # the fail-safe holds when the lookup fails
```

In CI, the first run after adding the gate always reports `verified=false` and runs everything:
the workflow edit changed the tree. The proof is the next hop on the same tree, which should log
`already passed verification; skipping it`, show the verify steps as skipped, and finish in
seconds. To force every tree to verify again, bump `salt` in the script.
