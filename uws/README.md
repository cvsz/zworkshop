# Workshop automated installer

`workshop-automated-installer.sh` is an executable Bash wrapper for Ubuntu
Workshop. It installs the LXD prerequisite and Workshop snap, bootstraps a
project, and routes the documented Workshop, interface, SDK, and sketch
operations through one command.

The wrapper uses the native Workshop CLI for stateful operations. It does not
run `lxd init`, choose storage or networking, or remove host data implicitly.

## Install and bootstrap

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

`init` refuses to overwrite an existing `.workshop/<name>.yaml` definition and
adds `.workshop.lock` to `.gitignore` only when it is not already present.
The Ollama `pull` action is added only when Ollama is selected; disable it with
`--no-ollama-action`.

## Commands

Global options must appear before the command. With no command, the script
performs `install`.

| Area | Commands |
| --- | --- |
| Setup | `install`, `init`, `bootstrap` |
| Lifecycle | `launch`, `refresh`, `start`, `stop`, `restore`, `remove` |
| Status | `list`, `status`, `info`, `actions`, `changes`, `tasks`, `warnings`, `okay` |
| Execution | `exec`, `shell`, `run`, `ollama`, `pull-model` |
| Interfaces | `connections`, `connect`, `disconnect`, `remount` |
| SDKs | `sdk`, `sdk-find`, `sdk-info`, `sdk-list`, `sdkcraft` |
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
./workshop-automated-installer.sh --project-dir ./project sketch-sdk
./workshop-automated-installer.sh --project-dir ./project native launch dev --wait-on-error
```

For native Workshop flags that need to appear before a separator, use
`native`; the wrapper's `exec` and `run` commands intentionally treat all
remaining arguments as the command or action payload.

Multiple `--workshop NAME` options are passed to native commands that support
multiple targets, such as `launch`, `refresh`, `stop`, `restore`, and `remove`.
Use `native` when native argument ordering needs to be controlled exactly.

## Configuration and automation

The following environment variables are supported:

```text
UWS_PROJECT_DIR UWS_WORKSHOP_NAME UWS_BASE UWS_SDKS UWS_MODEL
UWS_LXD_CHANNEL UWS_SNAP_BIN UWS_USE_GIT UWS_OLLAMA_ACTION UWS_JSON_OUTPUT
```

An optional config file uses the same key names as simple `KEY=VALUE` lines:

```bash
./workshop-automated-installer.sh \
  --config ./workshop.env \
  --project-dir ./project \
  bootstrap
```

Config files are parsed as data and are never sourced or executed.

Use JSON envelopes for status and diagnostics in automation:

```bash
./workshop-automated-installer.sh --json --project-dir ./project status
./workshop-automated-installer.sh --json --project-dir ./project doctor
```

Generate completion code with `completion bash`, `completion zsh`,
`completion fish`, or `completion powershell`. Run the non-mutating local CI
checks with:

```bash
bash ci/workshop-smoke.sh
```

For GitHub Actions, copy `ci/github-actions-workshop-smoke.yml` to
`.github/workflows/workshop-smoke.yml` in the repository containing `uws`.

## Safety boundaries

- `--dry-run` and `--plan` do not install snaps or create project files.
- `remove` and `sketch-remove` require `--yes` in non-interactive use.
- Existing workshop definitions are never overwritten.
- Bootstrap does not download a model unless `--model` is supplied.
- Host mounts, GPU, networking, and interface changes require explicit
  commands.
- Tests use fake commands and temporary directories; they do not mutate the
  host's snap or LXD state.
