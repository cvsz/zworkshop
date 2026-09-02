# Release

## Versioning

Use an explicit versioning policy. Semantic Versioning is recommended for reusable software unless the project has a better-defined scheme.

## Release checklist

1. Ensure required CI and security checks pass.
2. Update `CHANGELOG.md`.
3. Confirm migrations and compatibility notes.
4. Verify deployment and rollback procedures.
5. Create and push the release tag according to project policy.
6. Publish artifacts only from trusted workflows.
7. Verify the release after publication.

## Workshop artifact gate

Before publishing a change to the root Workshop automation, run:

```bash
make workshop-test
make workshop-smoke
```

Confirm that the smoke checks use only temporary fake commands, that no
`.workshop.lock` runtime file is staged, and that any live snap/LXD operation
was performed separately with explicit operator approval.

## GitHub publication

Synchronize with `origin/main` before creating a release commit. Use the local
GPG agent for signing, verify the commit with `git verify-commit`, and confirm
that the pushed SHA matches both `origin/main` and the GitHub commit
verification result. Do not place passphrases or tokens in commands, files, or
release notes.

The repository's validation workflows currently use `actions/checkout@v7`,
`github/codeql-action@v4`, and `actions/dependency-review-action@v5`. Confirm
hosted CI and security workflows are green for the exact release commit before
tagging or publishing artifacts.

## Rollback

Document how to restore the last known-good version, revert migrations safely, invalidate compromised artifacts, and communicate operational impact.
