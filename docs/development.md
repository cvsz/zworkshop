# Development

## Local setup

1. Clone the `zworkshop` repository or a repository generated from it.
2. Copy `.env.example` to `.env` and populate local-only values.
3. Install the selected runtime and dependencies.
4. Replace the remaining placeholder `Makefile` targets with real project commands.
5. Run formatting, linting, tests, build, and security checks before opening a pull request.

## Ubuntu Workshop checks

The repository-root `workshop-automated-installer.sh` wraps the documented
Ubuntu Workshop lifecycle without automatically running `lxd init` or changing
host storage and networking. Use dry-run mode while reviewing commands:

```bash
./workshop-automated-installer.sh --dry-run bootstrap
```

Run the fake-backend test harness and the complete non-mutating smoke check:

```bash
make workshop-test
make workshop-smoke
```

`make test` includes the root layout, documentation contract, and fake-backend
Workshop tests. `make ci` also runs the repository's placeholder format/build/
security gates until a generated project replaces them with stack-specific
commands.

The tests use temporary fake `snap`, `lxd`, `workshop`, SDK, and privilege
commands. They do not install snaps, start LXD, or create a real Workshop
definition in this repository.

## Quality expectations

- Keep changes small and reviewable.
- Add tests for behavior changes.
- Prefer deterministic and reproducible tooling.
- Do not commit secrets or local credentials.
- Do not weaken security or CI gates to obtain a passing build.

## Documentation

Update architecture, development, release, and ADR documentation when behavior or operational assumptions change.
