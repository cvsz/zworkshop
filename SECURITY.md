# Security Policy

Security is part of the default delivery baseline for repositories created from this template.

## Reporting a vulnerability

Do not disclose exploitable vulnerabilities in public issues, pull requests, discussions, or commit messages. Use GitHub's private vulnerability reporting/security advisory capability when enabled for the repository, or contact the repository owner through an agreed private channel.

Include affected versions or commits, reproduction details, impact, prerequisites, and suggested remediation when available.

## Supported versions

Each generated project should replace this section with its real support policy before its first production release.

## Security expectations

- Keep dependencies patched and review Dependabot alerts.
- Keep CodeQL and dependency-review workflows enabled when supported.
- Use least-privilege GitHub Actions permissions.
- Never commit credentials, tokens, private keys, production secrets, or sensitive personal data.
- Validate untrusted input and enforce authorization at trust boundaries.
- Prefer fail-closed behavior for security-sensitive paths.
- Preserve tenant and data isolation where applicable.
- Review third-party actions and pin or constrain them according to project policy.
- Do not disable security gates merely to obtain a passing build.

## Workshop trust boundary and safety model

The root Workshop wrapper is intentionally an operator-controlled boundary:

- Installation is limited to the LXD and Workshop snaps; `lxd init` is never
  run automatically, so storage and networking choices remain explicit.
- `--dry-run` and `--plan` do not install snaps, create projects, or invoke
  native Workshop state changes.
- Existing `.workshop/<name>.yaml` definitions are never overwritten, and
  `remove`/sketch deletion require `--yes` or interactive confirmation.
- `.workshop.lock` is runtime state and is ignored; `.workshop/` definitions
  may be reviewed and version-controlled. Do not commit runtime data,
  credentials, model caches, or private keys.
- GPU, mounts, networking, and other interfaces are exposed only through
  explicit commands. CI uses fake executables and temporary directories and
  does not mutate host snap/LXD state.
- `sdkcraft-install` and `sdkcraft-refresh` are explicit host operations;
  `install` does not install SDKcraft as a side effect. SDKcraft project
  commands run from the selected `--project-dir`, but `try` and `test` may
  build artifacts or provision LXD and must be run only on an approved host.
- SDK Store `login`, `register`, and `upload` are never automated. Do not put
  their credentials, tokens, packed `.sdk` files, model caches, or release
  state in `examples/tutorial/`.
- The tutorial fixture test scans definitions and hooks for credentials,
  runtime locks, packed artifacts, automatic `lxd init`, and publication
  commands. It is a repository-content check, not proof of runtime security.

The GitHub workflows use read-only repository permissions for validation and
security jobs. Third-party action versions are reviewed and currently use
`actions/checkout@v7`, `github/codeql-action@v4`, and
`actions/dependency-review-action@v5`.

## Incident handling

Projects generated from this template should document containment, remediation, validation, disclosure, and rollback procedures appropriate to their risk profile.
