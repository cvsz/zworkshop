# Contributing

Thanks for contributing to zworkshop and projects created from this template.

## Development workflow

1. Fork or create a feature branch from `main`.
2. Keep changes focused and reviewable.
3. Add or update tests for behavior changes.
4. Run the repository's formatting, linting, test, build, and security checks.
5. Update documentation and `CHANGELOG.md` when relevant.
6. Open a pull request and complete the checklist.

## Ubuntu Workshop validation

Changes to the root Workshop automation must keep the non-mutating gates green:

```bash
make workshop-test
make workshop-smoke
```

Use `./workshop-automated-installer.sh --dry-run ...` when reviewing installer
arguments. Do not use the test harness to install snaps, initialize LXD, or
create runtime state in the repository. For the complete tutorial integration,
also review `docs/tutorial.md` and run the static fixture contract:

```bash
bash tests/test-tutorial-fixtures.sh
```

SDKcraft `try` and `test` are live operator workflows and may create build
artifacts or LXD containers. SDK Store `login`, `register`, and `upload` must
remain explicit and must never be added to CI.

## Branch naming

Use concise prefixes such as `feat/`, `fix/`, `docs/`, `chore/`, `refactor/`, `test/`, or `security/`.

## Commit guidance

Prefer Conventional Commits, for example:

- `feat: add project scaffolding`
- `fix: handle empty configuration`
- `security: harden token validation`
- `docs: update deployment guide`

Use the repository's configured GPG agent for signed commits when signing is
required. Never put passphrases, tokens, or private keys in commits, issues, or
pull requests.

## Pull requests

Pull requests should explain the problem, implementation, testing, security impact, compatibility impact, and rollback plan where applicable. Do not bypass quality or security checks to make a pull request green.

## Security

Do not report exploitable vulnerabilities in public issues. Follow `SECURITY.md`.
