# zworkshop

A production-ready, reusable GitHub repository template with a root-native Ubuntu Workshop automation workflow and consistent engineering, security, documentation, automation, and release practices.

[![CI](https://github.com/cvsz/zworkshop/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/cvsz/zworkshop/actions/workflows/ci.yml)
[![Workshop wrapper smoke](https://github.com/cvsz/zworkshop/actions/workflows/workshop-smoke.yml/badge.svg?branch=main)](https://github.com/cvsz/zworkshop/actions/workflows/workshop-smoke.yml)
[![CodeQL](https://github.com/cvsz/zworkshop/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/cvsz/zworkshop/actions/workflows/codeql.yml)
[![Release workflow](https://github.com/cvsz/zworkshop/actions/workflows/release.yml/badge.svg)](https://github.com/cvsz/zworkshop/actions/workflows/release.yml)
[![Latest release](https://img.shields.io/github/v/release/cvsz/zworkshop?display_name=tag)](https://github.com/cvsz/zworkshop/releases)

## Included

- Issue and pull request templates
- CODEOWNERS and repository contribution guidance
- Security and conduct policies
- CI workflow baseline
- CodeQL security scanning
- Dependency Review for pull requests
- Dependabot configuration
- Tag-driven GitHub release workflow, release documentation, and changelog structure
- Conventional commit / PR guidance
- EditorConfig, Git attributes, and Git ignore baseline
- Community health files
- Documentation structure
- Complete Ubuntu Workshop tutorial guide and definition-first fixtures
- Changelog and roadmap templates
- Implementation checklist
- Architecture Decision Record (ADR) template
- Environment example
- Docker baseline
- Makefile task entrypoints
- Root-level Ubuntu Workshop installer, test harness, smoke checks, and CI workflow

## Start from this template

1. Use this repository as a GitHub template repository.
2. Create a new repository from the template.
3. Replace placeholder project metadata.
4. Review and customize `.github/CODEOWNERS`, `SECURITY.md`, CI matrices, and release settings.
5. Use `./workshop-automated-installer.sh --help` for the built-in Workshop workflow, then add language/framework-specific workflows only when the project needs them.

## Repository structure

```text
.github/
  ISSUE_TEMPLATE/
  workflows/
    ci.yml
    codeql.yml
    dependency-review.yml
    release.yml
    workshop-smoke.yml
  CODEOWNERS
  PULL_REQUEST_TEMPLATE.md
  dependabot.yml
docs/
  adr/
  architecture.md
  development.md
  release.md
  tutorial.md
examples/
  tutorial/
    README.md
    ollama-python-project/
    ollama-sdk/
ci/
  workshop-smoke.sh
tests/
  test-documentation-contract.sh
  test-release-workflow.sh
  test-root-workshop-layout.sh
  test-tutorial-fixtures.sh
  test-workshop-automated-installer.sh
.env.example
.editorconfig
.gitattributes
.gitignore
CHANGELOG.md
CODE_OF_CONDUCT.md
Dockerfile
IMPLEMENTATION-CHECKLIST.md
LICENSE
Makefile
README.md
ROADMAP.md
SECURITY.md
workshop-automated-installer.sh
```

## Ubuntu Workshop automation

`workshop-automated-installer.sh` is the repository-root Bash wrapper for the
Ubuntu Workshop workflow. It installs or refreshes the LXD prerequisite and
Workshop snap, initializes projects, routes Workshop lifecycle, execution,
interface, SDK, and sketch operations through one command, and provides
explicit SDKcraft installation and refresh commands.

The wrapper follows the current [Ubuntu Workshop tutorial](https://ubuntu.com/workshop/docs/tutorial/part-1-get-started/): LXD `6/stable`, classic Workshop installation, `workshop init NAME --sdks ... --base ...`, `workshop exec NAME -- ...`, and `workshop run NAME -- ...`. Its default base is `ubuntu@24.04`; pass `--base ubuntu@22.04` when following the tutorial's initial example exactly.

The wrapper delegates stateful operations to the native Workshop CLI and runs
SDKcraft passthrough commands from the selected `--project-dir`. It does not
run `lxd init`, select storage or networking, overwrite an existing
`.workshop/<name>.yaml`, or remove host data implicitly. Read the complete
[tutorial integration guide](docs/tutorial.md) and inspect the
[definition-first fixtures](examples/tutorial/) for the four tutorial parts.

### Install and bootstrap

Preview the installation without changing the host:

```bash
./workshop-automated-installer.sh --dry-run install
```

Install or refresh LXD on `6/stable` and Workshop in classic confinement:

```bash
./workshop-automated-installer.sh install
```

Create a project, initialize Git, create the `dev` definition, launch it, and
pull an Ollama model:

```bash
./workshop-automated-installer.sh \
  --project-dir "$PWD/ollama-project" \
  --workshop dev \
  --base ubuntu@24.04 \
  --sdks ollama/cpu/stable \
  --model tinyllama \
  bootstrap
```

`init` refuses to overwrite an existing definition and adds `.workshop.lock`
to the project `.gitignore` only when it is not already present. The Ollama
`pull` action is added only when Ollama is selected; disable it with
`--no-ollama-action`.

### Command surface

Global options must appear before the command. With no command, the wrapper
performs `install`.

| Area | Commands |
| --- | --- |
| Setup | `install`, `init`, `bootstrap` |
| Lifecycle | `launch`, `refresh`, `start`, `stop`, `restore`, `remove` |
| Status | `list`, `status`, `info`, `actions`, `changes`, `tasks`, `warnings`, `okay` |
| Execution | `exec`, `shell`, `run`, `ollama`, `pull-model` |
| Interfaces | `connections`, `connect`, `disconnect`, `remount` |
| SDKs | `sdk`, `sdk-find`, `sdk-info`, `sdk-list`, `sdkcraft`, `sdkcraft-install`, `sdkcraft-refresh` |
| Sketches | `sketch-sdk`, `sketches`, `sketch-stash`, `sketch-restore`, `sketch-remove`, `sketch-eject` |
| Integration | `doctor`, `completion`, `ci` |
| Passthrough | `native`, `workshop`, `workshopctl`, `version` |

Examples:

```bash
./workshop-automated-installer.sh --project-dir ./project status
./workshop-automated-installer.sh --project-dir ./project --workshop dev info
./workshop-automated-installer.sh --project-dir ./project --workshop dev exec -- ls /project
./workshop-automated-installer.sh --project-dir ./project --workshop dev run -- pull tinyllama
./workshop-automated-installer.sh --project-dir ./project --workshop dev pull-model mistral
./workshop-automated-installer.sh --project-dir ./project connections --all
./workshop-automated-installer.sh --project-dir ./project connect dev/ollama:models :mount
./workshop-automated-installer.sh --project-dir ./project sdk-find ollama
./workshop-automated-installer.sh sdkcraft-install
./workshop-automated-installer.sh --project-dir ./sdk-source sdkcraft test
./workshop-automated-installer.sh --project-dir ./project sketch-sdk
./workshop-automated-installer.sh --project-dir ./project native launch dev --wait-on-error
```

Use `native` when native Workshop flags need exact positional ordering. Repeat
`--workshop NAME` for native commands that support multiple workshop targets.

### Configuration and automation

Supported environment variables are:

```text
UWS_PROJECT_DIR UWS_WORKSHOP_NAME UWS_BASE UWS_SDKS UWS_MODEL
UWS_LXD_CHANNEL UWS_SNAP_BIN UWS_USE_GIT UWS_OLLAMA_ACTION UWS_JSON_OUTPUT
```

An optional configuration file uses allow-listed `KEY=VALUE` lines and is
parsed as data, never sourced or executed:

```bash
./workshop-automated-installer.sh \
  --config ./workshop.env \
  --project-dir ./project \
  bootstrap
```

Query and diagnostic commands can emit JSON envelopes:

```bash
./workshop-automated-installer.sh --json --project-dir ./project status
./workshop-automated-installer.sh --json --project-dir ./project doctor
```

Generate Bash, Zsh, Fish, or PowerShell completion with `completion SHELL`.
Run the repository's non-mutating checks with:

```bash
bash ci/workshop-smoke.sh
```

### Releases

The repository's [release workflow](.github/workflows/release.yml) listens
only for an explicitly pushed exact `vMAJOR.MINOR.PATCH` tag. It validates the
tag target and `main` ancestry, runs `make ci`, and then creates a GitHub
Release with generated notes. It does not create tags, upload artifacts,
publish packages, or use long-lived repository secrets. See
[`docs/release.md`](docs/release.md) for the signed-commit, tag, verification,
and rollback procedure.

### Safety boundaries

- `--dry-run` and `--plan` do not install snaps or create project files.
- `remove` and `sketch-remove` require `--yes` in non-interactive use.
- Existing Workshop definitions are never overwritten.
- Bootstrap does not download a model unless `--model` is supplied.
- Host mounts, GPU, networking, and interface changes require explicit commands.
- SDKcraft login, registration, upload, and release promotion remain explicit
  operator actions; `install` never installs SDKcraft implicitly.
- Tutorial fixtures contain no credentials, `.workshop.lock`, model cache, or
  packed `.sdk` artifact, and CI validates them without live Workshop effects.
- Tests use fake commands and temporary directories; they do not mutate the host's snap or LXD state.

## Principles

- Secure by default
- Least privilege for GitHub Actions
- Reproducible automation
- Small, reviewable pull requests
- Documentation as part of delivery
- No weakening of security gates to make CI green
- Explicit release and rollback practices

## License

MIT. See `LICENSE`.
