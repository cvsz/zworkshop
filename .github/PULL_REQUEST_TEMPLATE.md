## Summary

Describe what changed and why.

## Validation

- [ ] Tests added or updated where needed.
- [ ] Formatting/linting completed.
- [ ] Build completed where applicable.
- [ ] Security impact reviewed.
- [ ] Documentation updated where needed.
- [ ] `make workshop-test` completed for Workshop or repository-layout changes.
- [ ] `make workshop-smoke` completed without live snap/LXD mutation.
- [ ] `bash tests/test-tutorial-fixtures.sh` completed for tutorial or SDKcraft changes.
- [ ] `bash tests/test-release-workflow.sh` completed for release workflow or CI changes.
  The contract covers `.github/workflows/release.yml` trigger and permission boundaries.

## Compatibility / risk

Describe compatibility impact, migration requirements, security considerations, and operational risk.

## Rollback

Describe how this change can be reverted or mitigated if it causes problems.

## Checklist

- [ ] This pull request is focused and reviewable.
- [ ] No credentials, tokens, private keys, or sensitive data are included.
- [ ] No `.workshop.lock`, model cache, packed `.sdk` artifact, or SDK Store state is included.
- [ ] Security/quality gates were not weakened or bypassed.
- [ ] `CHANGELOG.md` was updated for user-visible changes where appropriate.
- [ ] Root project and affected `.github` documentation were updated together.
- [ ] Release changes preserve the exact `vMAJOR.MINOR.PATCH` tag boundary, no automatic tag push, and no automatic artifact upload.
- [ ] Commits are GPG-signed when required by repository policy.
