# Workshop Full Wrapper Design

## Goal

Expand `workshop-automated-installer.sh` from an install-only helper into a
safe, idempotent command wrapper for the documented Ubuntu Workshop workflow.

## Scope

The wrapper will cover:

- LXD and Workshop installation/refresh on the documented snap channels.
- Project and workshop bootstrap with configurable project path, workshop
  name, Ubuntu base, SDK list, and optional Ollama model.
- Workshop lifecycle, execution, interface, change/task, and sketch commands.
- SDK, SDKcraft, and raw native CLI passthrough.
- Safe dry-run/plan output, configuration-file support, JSON command envelopes,
  diagnostics, shell completion output, local CI smoke checks, and the
  repository's root GitHub Actions workflow.

## Defaults

- LXD channel: `6/stable`.
- Workshop installation: snap classic confinement.
- Project directory: current working directory.
- Workshop name: `dev`.
- Base: `ubuntu@24.04`.
- SDKs: `ollama/cpu/stable`.
- Git initialization: enabled for `init` unless `--no-git` is supplied.
- Ollama model pull: opt-in only; no large model download occurs implicitly.

## Safety boundaries

- No automatic `lxd init`; storage/network choices remain operator-controlled.
- No overwrite of an existing `.workshop/<name>.yaml` definition.
- `remove` and sketch deletion require `--yes` or an interactive confirmation.
- `--dry-run`/`--plan` performs no installation, project creation, or native
  Workshop operation.
- Config files are parsed as allow-listed `KEY=VALUE` pairs and never sourced.
- Host mounts, GPU access, networking, and interface changes are only exposed
  through explicit commands and are never enabled by bootstrap.
- Tests use fake executables and temporary directories; they never call snap,
  LXD, or Workshop on the host.

## Command surface

The script keeps no separate state database and delegates state transitions to
native Workshop commands. It supports `install`, `init`, `bootstrap`, lifecycle
commands, execution commands, interface commands, SDK/sketch commands, raw
`native` passthrough, `doctor`, `completion`, and `ci`.

Query commands can emit a JSON envelope containing the command, project,
selected workshop, exit code, and captured native output. Human-readable mode
continues to stream native output directly.

## Testing

The repository-local shell test harness will verify syntax, help and dry-run
behavior, fresh install versus refresh selection, project initialization,
argument forwarding, destructive-command confirmation, JSON output, and CI
checks using fake `snap`, `lxd`, `workshop`, and `sudo` commands.
