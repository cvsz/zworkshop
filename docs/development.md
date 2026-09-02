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

`make workshop-test` includes the root layout, documentation contract, tutorial
fixture contract, release workflow contract, and fake-backend Workshop tests.
`make ci` also runs the repository's placeholder format/build/security gates
until a generated project replaces them with stack-specific commands.

The tests use temporary fake `snap`, `lxd`, `workshop`, SDK, SDKcraft, and
privilege commands. They do not install snaps, start LXD, create a real
Workshop, query the SDK Store, build an SDK, or publish anything.

## Tutorial fixtures

The complete tutorial map is in [`docs/tutorial.md`](tutorial.md). The
definition-first examples are under [`examples/tutorial/`](../examples/tutorial/)
and are checked by `tests/test-tutorial-fixtures.sh`:

```bash
bash tests/test-tutorial-fixtures.sh
```

The wrapper's SDKcraft boundary is intentionally explicit:

```bash
./workshop-automated-installer.sh sdkcraft-install
./workshop-automated-installer.sh sdkcraft-refresh
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft clean
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft try
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft test
```

The first two commands affect the host's SDKcraft snap. The project commands
may create build output, LXD containers, or runtime state and therefore belong
to an approved operator environment, not CI. `sdkcraft login`, `register`, and
`upload` are documented but never run automatically.

## Quality expectations

- Keep changes small and reviewable.
- Add tests for behavior changes.
- Prefer deterministic and reproducible tooling.
- Do not commit secrets or local credentials.
- Do not weaken security or CI gates to obtain a passing build.

## Documentation

Update architecture, development, release, and ADR documentation when behavior or operational assumptions change.

The release workflow contract is static and credential-free:

```bash
bash tests/test-release-workflow.sh
```

It checks the exact tag trigger, validation gate, least-privilege permissions,
generated-notes command, and no-artifact boundary without contacting GitHub.
