# GitHub Release Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a tag-driven GitHub Release workflow that validates the exact tagged `main` commit with `make ci` before creating a generated-notes release without uploading artifacts.

**Architecture:** Keep validation and publication in separate GitHub Actions jobs. The read-only validation job checks the tag type, exact SemVer format, tag target, main ancestry, and the repository gate; the dependent publication job alone receives `contents: write` and invokes the GitHub-provided `gh` CLI. Add a static Bash contract and route it through every existing non-mutating local and hosted smoke gate.

**Tech Stack:** GitHub Actions YAML, `actions/checkout@v7`, Bash, Make, GitHub CLI, ShellCheck, PyYAML, GPG-signed Git commits, and existing CI/workflow tests.

## Global Constraints

- Trigger only on pushed tags matching `vMAJOR.MINOR.PATCH`; do not add `workflow_dispatch`, pull-request, branch, or automatic tag triggers.
- Validation uses `contents: read`; publication uses `needs: validate` and `contents: write` only.
- Validate `GITHUB_REF_TYPE`, `GITHUB_REF_NAME`, `GITHUB_SHA`, exact tag target, and `git merge-base --is-ancestor "$GITHUB_SHA" refs/remotes/origin/main` before publication.
- Publish with `gh release create`, `--verify-tag`, and `--generate-notes`; do not upload artifacts, create tags, push tags, log in to SDK Store, or use a third-party release action.
- Keep the existing `v0.1.0` release unchanged and do not publish a release during this implementation.
- Preserve the repository's fake-command and temporary-directory boundary; workflow tests must not need GitHub credentials or network access.
- Update project/GitHub documentation, checklist, roadmap, changelog, and workflow contracts together.
- Preserve unrelated changes and use the configured GPG agent and identity for every commit.

---

### Task 1: Lock the release workflow contract with a failing test

**Files:**
- Create: `tests/test-release-workflow.sh`
- Test target: `.github/workflows/release.yml`

**Interfaces:**
- Consumes the repository-relative release workflow path.
- Produces a dependency-light static contract that runs without GitHub access.

- [ ] **Step 1: Write the failing static contract**

Create an executable Bash test with the following content:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
WORKFLOW="$ROOT_DIR/.github/workflows/release.yml"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local needle=$1
    grep -Fq -- "$needle" "$WORKFLOW" \
        || fail "release workflow is missing: $needle"
}

assert_not_contains() {
    local needle=$1
    if grep -Fq -- "$needle" "$WORKFLOW"; then
        fail "release workflow contains forbidden content: $needle"
    fi
}

[[ -f "$WORKFLOW" ]] || fail "missing release workflow: $WORKFLOW"

assert_contains 'name: Release'
assert_contains 'push:'
assert_contains 'tags:'
assert_contains "- 'v*.*.*'"
assert_contains 'actions/checkout@v7'
assert_contains 'fetch-depth: 0'
assert_contains 'GITHUB_REF_TYPE'
assert_contains 'GITHUB_REF_NAME'
assert_contains 'GITHUB_SHA'
assert_contains 'git merge-base --is-ancestor'
assert_contains 'refs/remotes/origin/main'
assert_contains 'make ci'
assert_contains 'needs: validate'
assert_contains 'contents: read'
assert_contains 'contents: write'
assert_contains 'gh release create'
assert_contains '--verify-tag'
assert_contains '--generate-notes'
assert_contains 'GH_TOKEN: ${{ github.token }}'
assert_contains 'GH_REPO: ${{ github.repository }}'

assert_not_contains 'workflow_dispatch'
assert_not_contains 'pull_request_target'
assert_not_contains 'actions/upload-artifact'
assert_not_contains 'sdkcraft login'
assert_not_contains 'sdkcraft register'
assert_not_contains 'sdkcraft upload'
assert_not_contains 'git push'
assert_not_contains 'git tag'
assert_not_contains '--draft'
assert_not_contains '--latest=false'
assert_not_contains 'BEGIN PRIVATE KEY'

printf 'release workflow contract PASS\n'
```

- [ ] **Step 2: Run the test to verify the expected red failure**

Run:

```bash
chmod 0755 tests/test-release-workflow.sh
bash tests/test-release-workflow.sh
```

Expected result: failure with `missing release workflow`, because the workflow has not been created yet.

### Task 2: Implement the two-stage tag release workflow

**Files:**
- Create: `.github/workflows/release.yml`
- Test: `tests/test-release-workflow.sh`

**Interfaces:**
- Consumes pushed `vMAJOR.MINOR.PATCH` tags and the existing `make ci` target.
- Produces a GitHub Release only after the read-only validation job succeeds.

- [ ] **Step 1: Add the exact workflow definition**

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: read

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

jobs:
  validate:
    name: Validate release tag
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          fetch-depth: 0

      - name: Validate tag and ancestry
        shell: bash
        run: |
          set -Eeuo pipefail
          [[ "${GITHUB_REF_TYPE:-}" == "tag" ]]
          tag="${GITHUB_REF_NAME:-}"
          tag_sha="${GITHUB_SHA:-}"
          [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
          [[ -n "$tag_sha" ]]
          [[ "$(git rev-parse "${tag}^{commit}")" == "$tag_sha" ]]
          git fetch --no-tags origin main:refs/remotes/origin/main
          git merge-base --is-ancestor "$tag_sha" refs/remotes/origin/main

      - name: Run repository gate
        shell: bash
        run: make ci

  publish:
    name: Publish GitHub release
    needs: validate
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Create GitHub release
        shell: bash
        env:
          GH_TOKEN: ${{ github.token }}
          GH_REPO: ${{ github.repository }}
          TAG: ${{ github.ref_name }}
        run: |
          set -Eeuo pipefail
          gh release create "$TAG" \
            --repo "$GH_REPO" \
            --verify-tag \
            --generate-notes \
            --title "$TAG"
```

The publication job intentionally has no checkout step and no artifact
arguments. `gh release create` must return nonzero if a release already exists
or the API rejects the operation.

The contract must also assert that the workflow-level permission is exactly
`contents: read`, that `validate` is read-only, that `publish` is write-capable,
that no other job has `contents: write`, and that
`tests/test-release-workflow.sh` is included in the Makefile release gate.

- [ ] **Step 2: Run the focused contract to verify green**

Run:

```bash
bash tests/test-release-workflow.sh
```

Expected result: `release workflow contract PASS`.

### Task 3: Integrate the release contract into repository gates

Files:
- Modify: `workshop-automated-installer.sh`
- Modify: `Makefile`
- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/workshop-smoke.yml`
- Modify: `tests/test-documentation-contract.sh`
- Modify: `tests/test-root-workshop-layout.sh`

- [ ] **Step 1: Extend the local shell-file inventory**

Add `tests/test-release-workflow.sh` to the shell-file list in
`workshop-automated-installer.sh` and to the `workshop-test` target in
`Makefile`. Run it after the tutorial fixture contract so both the wrapper
and the normal Make-based CI path validate the release workflow.

- [ ] **Step 2: Extend CI required-file assertions**

Add `.github/workflows/release.yml` and `tests/test-release-workflow.sh` to the
required repository files checked by `.github/workflows/ci.yml`.

- [ ] **Step 3: Extend the Workshop smoke path filters**

Add the same workflow and contract test to both the `push` and
`pull_request` path lists in `.github/workflows/workshop-smoke.yml` while
retaining the existing broad `.github/**` coverage.

- [ ] **Step 4: Extend documentation and layout contracts**

Require the release workflow and its test from the documentation contract, and
include them in the root layout contract's checked files. Assert the documented
tag format, workflow location, and release command so the project documents
cannot drift away from the executable contract.

- [ ] **Step 5: Run the focused repository contracts**

Run:

```bash
bash tests/test-release-workflow.sh
bash tests/test-root-workshop-layout.sh
bash tests/test-documentation-contract.sh
bash workshop-automated-installer.sh ci
```

Expected result: all focused contracts pass, including the release contract.

### Task 4: Update project and GitHub-facing release documentation

Files:
- Modify: `README.md`
- Modify: `docs/release.md`
- Modify: `CONTRIBUTING.md`
- Modify: `.github/PULL_REQUEST_TEMPLATE.md`
- Modify: `ABOUT.md`
- Modify: `SECURITY.md`
- Modify: `CHANGELOG.md`
- Modify: `ROADMAP.md`
- Modify: `IMPLEMENTATION-CHECKLIST.md`
- Modify: `docs/superpowers/specs/2026-09-02-release-workflow-design.md`

- [ ] **Step 1: Document the operator-facing release path**

Document that a release is made by pushing a signed exact `vMAJOR.MINOR.PATCH`
tag whose target is already on `main`. Explain that validation runs
read-only repository gates first, then the publish job creates a GitHub release
with generated notes and no uploaded artifacts. State that the workflow does
not create tags, publish packages, or use long-lived repository secrets.

- [ ] **Step 2: Align contributor and security guidance**

Add the release workflow contract to contributor validation instructions, the
pull-request checklist, and the security trust-boundary documentation. Clarify
that the publish job alone has `contents: write` and that release failures must
be repaired by a new tag or a deliberate GitHub release correction rather than
by automatic tag mutation.

- [ ] **Step 3: Mark only implemented roadmap/checklist items**

Mark the tag-driven release workflow, semantic-version tag policy, generated
release notes, and rollback documentation complete. Leave package publishing,
artifact provenance, and other intentionally out-of-scope capabilities
unchecked.

- [ ] **Step 4: Record the implementation status in the approved spec**

Change the spec status to implemented only after the workflow and local gates
are in place. Reserve the completion-evidence section for the final signed
commit, pushed branch, GitHub verification, and hosted run URLs.

- [ ] **Step 5: Run documentation and formatting checks**

Run:

```bash
bash tests/test-documentation-contract.sh
git diff --check
```

Expected result: documentation contracts pass and Git reports no whitespace
errors.

### Task 5: Verify the complete local release implementation

Files:
- Test: `tests/test-release-workflow.sh`
- Test: `tests/test-root-workshop-layout.sh`
- Test: `tests/test-documentation-contract.sh`
- Test: `tests/test-tutorial-fixtures.sh`
- Test: `tests/test-workshop-automated-installer.sh`
- Test: `ci/workshop-smoke.sh`
- Test: `Makefile`

- [ ] **Step 1: Run the full project gate**

Run:

```bash
make ci
```

Expected result: lint, all Workshop tests, build, and security checks pass.

- [ ] **Step 2: Run the wrapper smoke gate**

Run:

```bash
make workshop-smoke
```

Expected result: the wrapper's end-to-end smoke path passes with the release
workflow present.

- [ ] **Step 3: Review the complete diff and repository state**

Run:

```bash
git diff --check
git diff --stat
git status --short
```

Confirm that only the release workflow, its contract, integration gates, and
related project/GitHub documents are changed. Do not stage user configuration,
credentials, private keys, or unrelated work.

### Task 6: Commit, push, and verify the hosted result

Files:
- Commit the implementation files from Tasks 1–5.
- Update the approved spec with completion evidence after the implementation
  commit and hosted verification.

- [ ] **Step 1: Synchronize before committing**

Run:

```bash
git fetch origin main
git status --short --branch
git rev-parse HEAD origin/main
```

If `main` advanced, integrate it with a non-destructive fast-forward or
rebase before staging. Preserve unrelated changes.

- [ ] **Step 2: Create the signed implementation commit**

Stage only the planned files, inspect the staged diff, and run:

```bash
git diff --cached --check
git commit --gpg-sign=220A4C8CCC7D2D50 -m "feat: add tag-driven GitHub releases"
```

Verify the local commit signature with `git log --show-signature -1` and
`git show --format=fuller --stat HEAD`.

- [ ] **Step 3: Push and verify the exact remote commit**

Run:

```bash
git push origin main
git fetch origin main
git rev-parse HEAD origin/main
git ls-remote origin refs/heads/main
```

Confirm local `HEAD`, `origin/main`, and the remote branch SHA are identical.

- [ ] **Step 4: Verify GitHub signature and required hosted checks**

Using the configured `gh` session without the invalid `GITHUB_TOKEN`
environment override, query the pushed commit and runs:

```bash
env -u GITHUB_TOKEN gh api "repos/cvsz/zworkshop/commits/<SHA>" --jq '{sha: .sha, verified: .commit.verification.verified, reason: .commit.verification.reason, html_url: .html_url}'
env -u GITHUB_TOKEN gh run list --commit <SHA> --limit 20 --json name,workflowName,status,conclusion,url,headSha,event,databaseId
```

Wait on each relevant run with `gh run watch <RUN_ID> --exit-status` and
confirm CI, Workshop smoke, and CodeQL succeed for the exact SHA. Confirm the
release workflow did not run on the branch push and that no new release or tag
was created by this implementation commit.

- [ ] **Step 5: Record final evidence in the spec and commit it**

Append the final commit SHA, signature result, remote SHA equality, local gate
results, hosted run URLs, and the no-release-side-effect check to the approved
spec. Change its status to `Implemented and verified`, then create a second
signed documentation commit, push it, and repeat exact-SHA signature and hosted
run verification for that evidence commit.
