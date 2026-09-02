# GitHub Release Workflow Design

**Status:** Approved design; written specification ready for review (2026-09-02)

## Goal

Add a conservative, tag-driven GitHub release workflow for `zworkshop` that
re-runs the repository validation gate before creating a GitHub Release, uses
least-privilege permissions, and never publishes generated artifacts or SDK
Store content automatically.

## Context

The repository already has signed commits, a published `v0.1.0` release, CI,
Workshop wrapper smoke, CodeQL, release guidance, and a clean `main` branch.
There is currently no release workflow. Future releases should be created from
an explicitly pushed version tag after local review and GPG-signed commit
publication.

## Scope

### Included

- `.github/workflows/release.yml`, triggered only by pushed tags matching the
  exact `vMAJOR.MINOR.PATCH` form.
- A validation job that checks the tag format, confirms the tag target is
  reachable from `main`, and runs `make ci` with repository read permission.
- A dependent publication job with `contents: write` permission that uses the
  GitHub-provided `gh` CLI, `--verify-tag`, and generated release notes.
- No automatic artifact upload, SDK Store login, SDK registration, SDK upload,
  channel promotion, or tag creation.
- `tests/test-release-workflow.sh`, a dependency-light static contract for
  triggers, permissions, validation, publication flags, and forbidden
  operations.
- Documentation and CI updates covering the new workflow, test, release
  procedure, rollback boundary, and status.

### Excluded

- Creating or pushing a version tag automatically.
- Publishing a new release during this implementation.
- Building or attaching `.sdk`, container, package, or other generated
  artifacts.
- Importing a GPG private key into GitHub Actions or claiming that the workflow
  verifies local GPG signatures. Commit signing remains a developer-side gate;
  the workflow verifies tag ancestry and repository checks.
- Releasing from pull requests, arbitrary branches, or unreviewed workflow
  dispatch input.

## Architecture

The workflow is a two-stage pipeline:

```text
push vMAJOR.MINOR.PATCH tag
          |
          v
validate (contents: read)
  - checkout@v7 with full history
  - validate tag syntax and tag target
  - fetch and verify ancestry from origin/main
  - make ci
          |
          v
publish (contents: write)
  - gh release create TAG
  - --verify-tag --generate-notes
  - no artifact arguments
```

The publication job runs only after validation succeeds. It receives
`GH_TOKEN: ${{ github.token }}` through the job environment and passes the tag
as a shell-quoted argument. The workflow relies on the existing GitHub-hosted
`gh` installation and does not add a third-party release action.

## Exact workflow contract

The implementation must preserve these values:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: read

jobs:
  validate:
    permissions:
      contents: read
    # checkout@v7, tag validation, origin/main ancestry, make ci

  publish:
    needs: validate
    permissions:
      contents: write
    # gh release create "$GITHUB_REF_NAME" --verify-tag --generate-notes
```

The validation shell must reject anything that does not match
`^v[0-9]+\.[0-9]+\.[0-9]+$`, verify that `GITHUB_REF_TYPE` is `tag`, verify
that the tag points at `GITHUB_SHA`, fetch `origin/main`, and require:

```bash
git merge-base --is-ancestor "$GITHUB_SHA" refs/remotes/origin/main
```

The publication shell must fail if the release already exists or if `gh
release create` fails. It must not use `--latest=false`, `--draft`, or a
fallback that hides a failed release operation; normal GitHub Release behavior
remains visible to the operator.

## Test contract

`tests/test-release-workflow.sh` must pass without GitHub credentials or
network access. It must assert that the workflow contains:

- the `push` tag trigger and `v*.*.*` pattern;
- `actions/checkout@v7`, `make ci`, `needs: validate`, and separate read/write
  permissions;
- `gh release create`, `--verify-tag`, `--generate-notes`, and
  `GH_TOKEN: ${{ github.token }}`;
- no artifact upload action, SDK Store command, private-key material, or
  `pull_request_target` trigger.

The existing documentation contract, root layout test, `make workshop-test`,
`make ci`, and focused Workshop smoke workflow must include the new static
test and workflow paths. YAML parsing must include `.github/workflows/release.yml`.

## Documentation and operations

Update `docs/release.md` with this procedure:

1. Run the local validation matrix and inspect the staged diff.
2. Create a GPG-signed commit on `main` or an approved release branch.
3. Push the commit and wait for CI, Workshop smoke, and CodeQL.
4. Push an exact `vMAJOR.MINOR.PATCH` tag to the validated commit.
5. Let the release workflow create the GitHub Release and generated notes.
6. Verify the release page, tag target, checks, and rollback instructions.

Document that deleting a draft is not the rollback path because the workflow
creates a published release; rollback means marking the release unavailable or
reverting the source in a follow-up signed commit according to repository
policy. Any artifact or package publication remains a separately designed
workflow.

Update the README structure and status, `CHANGELOG.md`, `ROADMAP.md`,
`IMPLEMENTATION-CHECKLIST.md`, `SECURITY.md`, `CONTRIBUTING.md`, the pull
request template, and documentation contracts so the workflow's permissions,
tag policy, and no-artifact boundary stay visible.

## Acceptance criteria

- A future `vMAJOR.MINOR.PATCH` tag is the only automatic trigger.
- Validation fails closed on malformed tags, tag/commit mismatch, tags outside
  `main`, or failed `make ci`.
- Publication cannot run when validation fails and has only `contents: write`.
- No credentials, private keys, generated artifacts, SDK Store operations, or
  tag pushes are part of the workflow.
- The static workflow test and all existing local gates pass.
- The implementation is committed with the configured GPG identity, pushed to
  `origin/main`, and verified by hosted CI, Workshop smoke, and CodeQL.

## Risks and mitigations

- **Accidental release:** exact SemVer tag matching, ancestry validation, and
  no workflow dispatch keep publication explicit.
- **Excess permissions:** only the dependent publication job receives
  `contents: write`; validation remains read-only.
- **Supply-chain drift:** use the already-reviewed checkout major and built-in
  `gh` instead of a new third-party release action.
- **Misleading release confidence:** `make ci` and hosted checks validate the
  repository; they do not validate live Workshop, SDKcraft, or package
  artifacts.
- **Rollback ambiguity:** document release visibility and source-revert
  procedures separately from future artifact publishing.
