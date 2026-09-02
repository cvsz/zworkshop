# Release

## Versioning

Use Semantic Versioning for releases from this template. The supported tag form
is exact `vMAJOR.MINOR.PATCH`; prerelease, build-metadata, branch-name, and
floating tags are not release inputs.

## Release checklist

1. Run `make ci`, `make workshop-smoke`, and the release workflow contract.
2. Update `CHANGELOG.md` and confirm compatibility notes.
3. Inspect the staged diff and confirm no credentials, runtime state, or
   generated artifacts are included.
4. Create a GPG-signed commit and push it to `main`.
5. Wait for CI, Workshop smoke, and CodeQL on the exact commit SHA.
6. Push an exact `vMAJOR.MINOR.PATCH` tag whose target is already on `main`.
7. Verify the published GitHub Release, tag target, generated notes, and
   rollback communication.

## Tag-driven GitHub release workflow

`.github/workflows/release.yml` listens only for pushed tags matching the
broad `v*.*.*` trigger pattern, then fails closed unless the tag is exactly
`^v[0-9]+\.[0-9]+\.[0-9]+$`. The validation job checks the tag type, tag
target, `main` ancestry, and `make ci` with `contents: read`.

Only the dependent publication job receives `contents: write`. It uses the
GitHub-provided token and runs `gh release create` with `--verify-tag` and
`--generate-notes`. The workflow does not create or push tags, publish
packages, or perform SDK Store operations. There is no automatic artifact
upload; package and artifact publication require a separately designed
workflow.

## Workshop artifact gate

Before publishing a change to the root Workshop automation, run:

```bash
make workshop-test
make workshop-smoke
bash tests/test-tutorial-fixtures.sh
bash tests/test-release-workflow.sh
```

Confirm that the smoke checks use only temporary fake commands, that no
`.workshop.lock` runtime file, packed `.sdk` artifact, model cache, or
credential is staged, and that any live snap/LXD/SDKcraft operation was
performed separately with explicit operator approval. Review the tutorial
fixture changes under `examples/tutorial/` and keep `docs/tutorial.md` aligned
with the four upstream tutorial parts.

## GitHub publication

Synchronize with `origin/main` before creating a release commit. Use the local
GPG agent for signing, verify the commit with `git verify-commit`, and confirm
that the pushed SHA matches both `origin/main` and the GitHub commit
verification result. Do not place passphrases or tokens in commands, files, or
release notes.

The repository's validation workflows currently use `actions/checkout@v7`,
`github/codeql-action@v4`, and `actions/dependency-review-action@v5`. Confirm
hosted CI and security workflows are green for the exact release commit before
tagging or publishing artifacts. A green fixture test is static evidence only;
it does not replace live Workshop, SDKcraft, LXD, or SDK Store validation.

After the hosted checks are green, push the exact version tag from the
validated commit:

```bash
git tag -a vMAJOR.MINOR.PATCH -m "Release vMAJOR.MINOR.PATCH" <validated-sha>
git push origin vMAJOR.MINOR.PATCH
```

The tag push starts validation. The publication job creates a published
GitHub Release only after validation succeeds; it does not create or move the
tag. Verify the release page and tag target before communicating the release.

## Rollback

The workflow creates a published GitHub Release, so deleting a draft is not a
rollback path. If the source is wrong, publish a new signed fix commit, wait
for its checks, and use a new version tag. If the release must be made
unavailable, restrict or remove the GitHub Release deliberately and record
the reason, affected tag, and operational communication. Revert migrations
safely according to the generated project's runbook. Artifact or package
revocation remains a separate operational procedure because this workflow has
no automatic artifact upload.
