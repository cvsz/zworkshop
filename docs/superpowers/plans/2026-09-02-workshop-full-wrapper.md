# Workshop Full Wrapper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `workshop-automated-installer.sh` into a safe, configurable wrapper for installation, bootstrap, Workshop lifecycle, interfaces, SDKs, sketches, diagnostics, JSON output, completion, and CI smoke checks.

**Architecture:** Keep one Bash entrypoint with explicit subcommand dispatch. Installation and filesystem setup are implemented locally; Workshop, SDK, SDKcraft, and workshopctl state remains owned by their native CLIs. Query commands optionally capture native output into a JSON envelope, while mutating and interactive commands retain human-readable output and explicit safety gates.

**Tech Stack:** Bash 5+, snap, LXD, Ubuntu Workshop CLI, SDK/SDKcraft CLIs, ShellCheck, temporary-directory shell test harness.

## Global Constraints

- LXD channel is `6/stable`.
- Workshop is installed with snap classic confinement.
- Default project directory is the current working directory.
- Default workshop is `dev`, base is `ubuntu@24.04`, and SDKs are `ollama/cpu/stable`.
- Do not run `lxd init` automatically.
- Do not overwrite existing `.workshop/<name>.yaml` files.
- Require `--yes` or interactive confirmation for Workshop removal and sketch deletion.
- Parse config files as allow-listed `KEY=VALUE` pairs; never source them.
- Tests must use fake executables and temporary directories; do not mutate host snap/LXD state.

---

### Task 1: Add failing behavior tests

**Files:**
- Create: `tests/test-workshop-automated-installer.sh`
- Test target: `workshop-automated-installer.sh`

**Interfaces:**
- Consumes the entrypoint path and temporary fake command directory.
- Produces executable assertions for install/refresh selection, init, dispatch,
  JSON, dry-run, and safety behavior.

- [ ] **Step 1: Write the failing test**

  Add a shell test that first asserts the new `init`, `bootstrap`, `doctor`,
  `completion`, `sdk`, and `native` command behaviors against fake commands.

- [ ] **Step 2: Run the test to verify it fails**

  Run `bash tests/test-workshop-automated-installer.sh` from the repository root.

  Expected: FAIL because the existing install-only script does not implement
  the new command surface.

### Task 2: Implement the full wrapper

**Files:**
- Modify: `workshop-automated-installer.sh`

**Interfaces:**
- Global options: `--project-dir`, `--workshop`, `--base`, `--sdks`,
  `--model`, `--config`, `--no-git`, `--yes`, `--dry-run`, `--plan`, and
  `--json`.
- Commands: `install`, `init`, `bootstrap`, lifecycle/query commands,
  `exec`, `shell`, `run`, `ollama`, interface commands, SDK/sketch commands,
  `native`, `doctor`, `completion`, and `ci`.

- [ ] **Step 1: Implement configuration and argument parsing**

  Apply environment defaults, parse an optional allow-listed config file, then
  let command-line options override config values. Preserve no-argument
  backward compatibility by treating no command as `install`.

- [ ] **Step 2: Implement project bootstrap**

  Add `init` and `bootstrap`; create the project directory when needed, refuse
  an existing definition, optionally run `git init`, call `workshop init`, add
  `.workshop.lock` idempotently to `.gitignore`, and optionally add the
  documented Ollama `pull` action when Ollama is selected.

- [ ] **Step 3: Implement native command routing**

  Route lifecycle, execution, interface, sketch, SDK, SDKcraft, and raw native
  commands through the selected project directory. Preserve exact positional
  arguments and support repeated `--workshop` targets where native Workshop
  accepts multiple names.

- [ ] **Step 4: Implement safety and observability**

  Add destructive-command confirmation, JSON envelopes for query commands,
  `doctor`, completion output for Bash/Zsh/Fish/PowerShell, and a non-mutating
  `ci` smoke command.

- [ ] **Step 5: Run the failing test and make it pass**

  Run `bash tests/test-workshop-automated-installer.sh` and fix only the
  implementation until it reports `PASS`.

### Task 3: Document and expose CI usage

**Files:**
- Modify: `README.md`
- Modify: `ci/workshop-smoke.sh`
- Modify: `.github/workflows/workshop-smoke.yml`

**Interfaces:**
- README documents the global options, defaults, safety boundaries, and native
  command examples.
- `ci/workshop-smoke.sh` invokes the local test harness and static checks with
  no live installation.
- `.github/workflows/workshop-smoke.yml` is the repository's root-native smoke
  workflow.

- [ ] **Step 1: Write the smoke script and README examples**

  Keep CI checks non-mutating by default; require an explicit environment
  variable before any future live Workshop job is added.

- [ ] **Step 2: Run the smoke script**

  Run `bash ci/workshop-smoke.sh` from the repository root.

  Expected: syntax, ShellCheck when installed, help, dry-run, and fake-command
  tests pass.

### Task 4: Final verification

**Files:**
- Verify: `workshop-automated-installer.sh`, `tests/test-workshop-automated-installer.sh`, `ci/workshop-smoke.sh`, `README.md`

- [ ] **Step 1: Run full local verification**

  Run `bash ci/workshop-smoke.sh` and `shellcheck --shell=bash workshop-automated-installer.sh tests/test-workshop-automated-installer.sh ci/workshop-smoke.sh` when ShellCheck is available.

- [ ] **Step 2: Inspect final scope**

  Confirm the entrypoint is executable, no real snap installation was invoked,
  and no command path automatically runs `lxd init`, removes data, or writes
  outside the repository and test temporary directories.
