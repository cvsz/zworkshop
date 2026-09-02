# Implementation Checklist

Use this checklist after creating a repository from `zworkshop`.

## Repository identity

- [ ] Replace `zworkshop` references with the real project name.
- [ ] Replace template descriptions and badges.
- [ ] Confirm license ownership and year.
- [ ] Configure repository topics, description, homepage, and template status.

## Ownership and governance

- [ ] Update `.github/CODEOWNERS`.
- [ ] Review `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md`.
- [ ] Configure branch protection or repository rulesets.
- [ ] Require pull request review where appropriate.
- [ ] Require passing status checks before merge.

## Ubuntu Workshop baseline

- [x] Root `workshop-automated-installer.sh` is executable and documented.
- [x] Root fake-backend tests and non-mutating smoke checks are available.
- [x] `.workshop.lock` is ignored while `.workshop/` definitions remain trackable.
- [x] Workshop smoke workflow is integrated into GitHub Actions.
- [x] GitHub Actions use current checkout, CodeQL, and dependency-review majors.
- [ ] Validate live Workshop bootstrap separately on an approved Ubuntu/snap host.

## Security

- [ ] Review `SECURITY.md` and configure private vulnerability reporting.
- [ ] Enable Dependabot alerts and security updates.
- [ ] Review CodeQL language detection/support for the actual stack.
- [ ] Keep dependency review enabled for pull requests where supported.
- [ ] Configure secret scanning and push protection where available.
- [ ] Add stack-specific SAST, container, IaC, and SBOM checks as needed.
- [ ] Confirm Actions permissions follow least privilege.

## Development

- [ ] Select the language/runtime and package manager.
- [ ] Add formatter and linter configuration.
- [ ] Add unit, integration, and end-to-end tests as appropriate.
- [ ] Replace remaining placeholder Makefile targets with real commands.
- [x] Run `make workshop-test` and `make workshop-smoke` for Workshop changes.
- [ ] Replace or remove the placeholder Dockerfile.
- [ ] Populate `.env.example` with safe non-secret keys only.

## CI/CD

- [ ] Customize CI for the selected stack.
- [x] Keep the root Workshop smoke workflow enabled.
- [ ] Pin runtime versions and define supported-version matrices.
- [ ] Add build and package validation.
- [ ] Add artifact retention settings where needed.
- [ ] Configure environments, approvals, and deployment protections.
- [ ] Verify workflows from forks do not receive unsafe credentials.

## Release

- [ ] Decide on Semantic Versioning or another explicit versioning policy.
- [ ] Configure changelog and release-note generation.
- [ ] Configure package/container publishing only when needed.
- [ ] Add provenance, signing, and attestations for production artifacts where appropriate.
- [ ] Document rollback procedures.

## Documentation

- [ ] Complete `docs/architecture.md`.
- [ ] Complete `docs/development.md`.
- [ ] Complete `docs/release.md`.
- [x] Document Workshop development and release gates.
- [ ] Add ADRs for material architectural decisions.
- [ ] Document operational ownership and support expectations.

## Final verification

- [ ] Fresh clone works with documented bootstrap steps.
- [x] Root layout and fake-backend Workshop checks pass locally.
- [ ] CI passes on `main` and pull requests.
- [ ] No secrets or private information are committed.
- [ ] Security checks are enabled and passing.
- [ ] A release can be created and rolled back according to documentation.
