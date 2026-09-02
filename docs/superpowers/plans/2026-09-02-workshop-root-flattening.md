# Workshop Root Flattening Completion Record

**Status:** Complete (2026-09-02)

The Workshop automation was moved from the historical `uws/` source layout to
the repository root, all operational references were updated, and the result
was validated locally and in GitHub Actions. Historical `uws/` paths remain in
this record only to explain the migration; they are not current commands or
repository paths.

> Historical implementation plan retained for traceability. Completed steps use
> checkbox (`- [x]`) syntax.

**Goal:** Move the Ubuntu Workshop automation from `uws/` into the repository root, update every path and project integration, and align the documented workflow with the current Ubuntu Workshop tutorial.

**Architecture:** The repository root becomes the executable project surface: the installer lives at `workshop-automated-installer.sh`, its tests live in `tests/`, the local smoke entrypoint lives in `ci/`, and the GitHub workflow runs from `.github/workflows/`. Existing root documentation is preserved and receives a dedicated Workshop section rather than being overwritten. The installer remains dependency-free Bash and keeps all live snap/LXD mutations explicit.

**Tech Stack:** Bash, ShellCheck when available, GitHub Actions YAML, Git, Snap/LXD/Workshop CLI passthrough.

## Global Constraints

- Preserve the existing root project files and do not overwrite the root `README.md`.
- Remove the obsolete `uws/` directory after all files and references are migrated.
- Keep `.workshop.lock` ignored and keep `.workshop/` available for version-controlled definitions.
- Match the current Ubuntu Workshop command forms: `workshop init NAME --sdks ... --base ...`, `workshop exec NAME -- ...`, and `workshop run NAME -- ...`.
- Tests and CI must not install snaps, start LXD, or mutate a real Workshop project.
- Stage only files belonging to this root-flattening change; preserve unrelated worktree changes.

---

### Task 1: Lock the desired root layout with a regression test

**Files:**
- Create: `tests/test-root-workshop-layout.sh`

**Interfaces:**
- Consumes: repository root determined from the test file location.
- Produces: an executable layout check that fails while the old `uws/` tree remains.

- [x] **Step 1: Write the failing test**

Create a Bash test that requires these paths:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

for path in \
    workshop-automated-installer.sh \
    tests/test-workshop-automated-installer.sh \
    tests/test-root-workshop-layout.sh \
    ci/workshop-smoke.sh \
    .github/workflows/workshop-smoke.yml \
    docs/superpowers/specs/2026-09-02-workshop-full-wrapper-design.md \
    docs/superpowers/plans/2026-09-02-workshop-full-wrapper.md; do
    test -f "$ROOT_DIR/$path" || { echo "missing root path: $path" >&2; exit 1; }
done

test ! -e "$ROOT_DIR/uws"
test -x "$ROOT_DIR/workshop-automated-installer.sh"
test -x "$ROOT_DIR/tests/test-workshop-automated-installer.sh"
test -x "$ROOT_DIR/tests/test-root-workshop-layout.sh"
test -x "$ROOT_DIR/ci/workshop-smoke.sh"
grep -Fq "bash ci/workshop-smoke.sh" "$ROOT_DIR/.github/workflows/workshop-smoke.yml"
if grep -R -n -E '(^|[^[:alnum:]_])uws/' "$ROOT_DIR" --exclude-dir=.git; then
    echo 'obsolete uws/ path reference found' >&2
    exit 1
fi
echo 'root layout PASS'
```

- [x] **Step 2: Run the test to verify it fails**

Run: `bash tests/test-root-workshop-layout.sh`

Expected: FAIL because the installer and supporting files still exist under `uws/`.

### Task 2: Flatten the tracked files without overwriting root content

**Files:**
- Move: `uws/workshop-automated-installer.sh` -> `workshop-automated-installer.sh`
- Move: `uws/tests/test-workshop-automated-installer.sh` -> `tests/test-workshop-automated-installer.sh`
- Move: `uws/ci/workshop-smoke.sh` -> `ci/workshop-smoke.sh`
- Move: `uws/ci/github-actions-workshop-smoke.yml` -> `.github/workflows/workshop-smoke.yml`
- Move: `uws/docs/superpowers/specs/2026-09-02-workshop-full-wrapper-design.md` -> `docs/superpowers/specs/2026-09-02-workshop-full-wrapper-design.md`
- Move: `uws/docs/superpowers/plans/2026-09-02-workshop-full-wrapper.md` -> `docs/superpowers/plans/2026-09-02-workshop-full-wrapper.md`
- Modify: `README.md`
- Modify: `.gitignore`
- Delete: `uws/README.md`

**Interfaces:**
- Consumes: the existing seven-file `uws/` deliverable and the existing root README/CI tree.
- Produces: one root-native executable/test/CI/documentation layout with no `uws/` directory.

- [x] **Step 1: Move non-colliding files with Git-aware renames**

Create destination directories if absent, then run:

```bash
git mv uws/workshop-automated-installer.sh workshop-automated-installer.sh
git mv uws/tests/test-workshop-automated-installer.sh tests/test-workshop-automated-installer.sh
git mv uws/ci/workshop-smoke.sh ci/workshop-smoke.sh
git mv uws/ci/github-actions-workshop-smoke.yml .github/workflows/workshop-smoke.yml
git mv uws/docs/superpowers/specs/2026-09-02-workshop-full-wrapper-design.md docs/superpowers/specs/2026-09-02-workshop-full-wrapper-design.md
git mv uws/docs/superpowers/plans/2026-09-02-workshop-full-wrapper.md docs/superpowers/plans/2026-09-02-workshop-full-wrapper.md
```

- [x] **Step 2: Merge the installer guide into the existing README**

Add a `## Ubuntu Workshop automation` section to the root README containing installation, initialization, lifecycle, execution, SDK/sketch, diagnostics, CI, and safety examples from the old `uws/README.md`, with commands rooted at `./workshop-automated-installer.sh` and `bash ci/workshop-smoke.sh`. Delete `uws/README.md` after the content is merged.

- [x] **Step 3: Update repository ignores and remove obsolete paths**

Add `.workshop.lock` to the root `.gitignore`; leave `.workshop/` trackable. Remove any empty `uws/` directories after all renames.

### Task 3: Update source, tests, docs, and workflow references

**Files:**
- Modify: `workshop-automated-installer.sh`
- Modify: `tests/test-workshop-automated-installer.sh`
- Modify: `ci/workshop-smoke.sh`
- Modify: `.github/workflows/workshop-smoke.yml`
- Modify: `docs/superpowers/specs/2026-09-02-workshop-full-wrapper-design.md`
- Modify: `docs/superpowers/plans/2026-09-02-workshop-full-wrapper.md`
- Modify: `docs/development.md`
- Modify: `docs/release.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: root-native paths from Task 2 and current Ubuntu Workshop syntax.
- Produces: path-consistent local/CI entrypoints, current docs, and a recorded unreleased change.

- [x] **Step 1: Update the workflow and documentation paths**

Change workflow triggers from `uws/**` to the root installer, `tests/**`, `ci/**`, and the workflow itself. Run `bash ci/workshop-smoke.sh` from the repository root. Replace prose such as “repository containing the `uws` directory” with “this repository” and update every command path to its root location.

- [x] **Step 2: Integrate repository gates**

Keep the existing baseline workflow intact and add a root smoke step that runs `bash ci/workshop-smoke.sh`; the dedicated Workshop workflow remains independently runnable for focused feedback. Add Makefile targets:

```make
workshop-test:
	@bash tests/test-workshop-automated-installer.sh

workshop-smoke:
	@bash ci/workshop-smoke.sh
```

Make `test` invoke `workshop-test` while retaining the template’s other placeholder gates, and document the commands in `docs/development.md` and `docs/release.md`.

- [x] **Step 3: Record the release-facing change**

Add an `Unreleased` entry to `CHANGELOG.md` describing the root-native installer, fake-backend smoke coverage, safe dry-run behavior, and current Workshop command alignment.

- [x] **Step 4: Remove duplicate stale code only when path migration requires it**

Preserve installer behavior while correcting only path-sensitive references and any clearly stale `uws/` wording. Do not introduce live snap/LXD setup into tests or CI.

### Task 4: Run the red-green validation cycle and full repository checks

**Files:**
- Test: `tests/test-root-workshop-layout.sh`
- Test: `tests/test-workshop-automated-installer.sh`
- Test: `ci/workshop-smoke.sh`
- Verify: `.github/workflows/ci.yml`, `.github/workflows/workshop-smoke.yml`, `Makefile`

**Interfaces:**
- Consumes: the completed root-native layout and updated integrations.
- Produces: fresh local evidence that no stale `uws/` references or live-mutation paths remain.

- [x] **Step 1: Run the structural test before the flattening implementation**

The initial run must fail for the expected missing-root/stale-tree reason.

- [x] **Step 2: Run the structural test after implementation**

Run: `bash tests/test-root-workshop-layout.sh`

Expected: `root layout PASS` and exit 0.

- [x] **Step 3: Run the Workshop harness and syntax/lint checks**

Run:

```bash
bash tests/test-workshop-automated-installer.sh
bash ci/workshop-smoke.sh
bash -n workshop-automated-installer.sh tests/test-workshop-automated-installer.sh tests/test-root-workshop-layout.sh ci/workshop-smoke.sh
shellcheck --shell=bash workshop-automated-installer.sh tests/test-workshop-automated-installer.sh tests/test-root-workshop-layout.sh ci/workshop-smoke.sh
git diff --check
```

If ShellCheck is unavailable, retain the script’s existing warning behavior and report that limitation explicitly.

- [x] **Step 4: Run the repository Makefile and YAML gates**

Run: `make test` and the existing Ruby YAML validation command from `.github/workflows/ci.yml`:

```bash
ruby -e 'require "yaml"; Dir.glob(".github/**/*.{yml,yaml}").each { |f| YAML.load_file(f); puts "ok #{f}" }'
```

- [x] **Step 5: Inspect the final diff and verify no real runtime state changed**

Run `git status --short`, `git diff --stat`, and confirm the harness used temporary fake commands only. Check that no `.ci-dry-run`, `.workshop.lock`, or `.workshop/` runtime artifact was created in the repository.

### Task 5: Commit and publish the approved completed change

**Files:**
- Commit: all reviewed root-flattening files only.

**Interfaces:**
- Consumes: green local checks and a clean, reviewed staged set.
- Produces: a GPG-signed commit on `main`, pushed to `origin/main`, with local and remote SHAs verified.

- [x] **Step 1: Stage only the reviewed root migration**

Run `git add` for the explicitly listed changed files and inspect `git diff --cached --name-status` and `git diff --cached --check`.

- [x] **Step 2: Create and verify the signed commit**

Use the configured GPG agent and signing identity, then run `git verify-commit HEAD`; do not print or request any passphrase.

- [x] **Step 3: Push without bypassing repository rules**

Fetch first, push `HEAD` to `origin/main` only if the target remains current and direct push is permitted, then verify `git rev-parse HEAD`, `git rev-parse origin/main`, `git ls-remote origin refs/heads/main`, and the GitHub commit verification result.
