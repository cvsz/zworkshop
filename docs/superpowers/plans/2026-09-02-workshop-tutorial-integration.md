# Ubuntu Workshop Tutorial Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Make zworkshop cover the complete four-part Ubuntu Workshop tutorial with a reusable root wrapper, checked-in tutorial fixtures, deterministic tests, and synchronized project/GitHub documentation.

**Architecture:** Preserve workshop-automated-installer.sh as the single dependency-free Bash entrypoint. Add explicit SDKcraft snap installation/refresh commands and execute SDKcraft passthrough commands from --project-dir; keep SDK Store queries machine-level. Store definition-first tutorial examples under examples/tutorial/, validate them statically, and run all checks through the existing non-mutating CI smoke path.

**Tech Stack:** Bash 5+, snap, LXD, Ubuntu Workshop CLI, SDK/SDKcraft CLIs, YAML definition files, ShellCheck, GitHub Actions, and temporary-directory fake-command tests.

## Global Constraints

- LXD and Workshop installation remain explicit; never run lxd init automatically.
- Add explicit sdkcraft-install and sdkcraft-refresh; keep sdkcraft as passthrough for init, clean, try, test, login, register, and upload.
- --project-dir is the working directory for Workshop and SDKcraft commands; SDK Store queries remain machine-level commands.
- Keep --dry-run, --plan, --yes, existing-definition protection, and .workshop.lock safety behavior intact.
- Tutorial fixtures are definition-first; do not commit credentials, model caches, packed .sdk artifacts, or runtime lock/state files.
- Tests and CI must not install snaps, initialize LXD, launch a workshop, contact the SDK Store, or publish an SDK.
- Host mounts, GPU access, tunnel exposure, storage selection, network configuration, and SDK Store publication remain explicit operator actions.
- Preserve unrelated repository changes and stage only files belonging to this integration.
- Use the configured GPG agent and signing identity for commits; never expose passphrases or tokens.

---

### Task 1: Lock the SDKcraft command surface with failing tests

Files:
- Modify: tests/test-workshop-automated-installer.sh
- Test target: workshop-automated-installer.sh

Interfaces:
- The existing fake snap records installation and refresh state.
- The fake sdkcraft records its current working directory and exact arguments.
- The assertions prove the new command names and project-directory boundary.

- [x] Step 1: Extend the fake snap state and SDKcraft recorder

Update the fake snap executable so snap list sdkcraft reflects a state file and snap install/refresh records SDKcraft operations. Update the fake sdkcraft executable to append cwd and arguments to UWS_TEST_LOG.

- [x] Step 2: Add the failing SDKcraft tests

Add these assertions after the existing install/refresh checks:

~~~bash
bash "$INSTALLER" sdkcraft-install >/dev/null || fail "SDKcraft install failed"
assert_file_contains "snap install --classic sdkcraft" "$log_file" "SDKcraft install"

bash "$INSTALLER" sdkcraft-refresh >/dev/null || fail "SDKcraft refresh failed"
assert_file_contains "snap refresh sdkcraft" "$log_file" "SDKcraft refresh"

sdkcraft_project="$test_root/sdkcraft-project"
mkdir -p "$sdkcraft_project"
bash "$INSTALLER" --project-dir "$sdkcraft_project" sdkcraft init >/dev/null \
    || fail "project SDKcraft dispatch failed"
assert_file_contains "sdkcraft cwd=$sdkcraft_project init" "$log_file" \
    "SDKcraft project working directory"
~~~

- [x] Step 3: Run the focused test and verify the expected red failure

Run:

~~~bash
bash tests/test-workshop-automated-installer.sh
~~~

Expected: FAIL because the current dispatch does not define sdkcraft-install or sdkcraft-refresh and SDKcraft is not run from the selected project directory.

### Task 2: Add the tutorial fixture contract as a failing test

Files:
- Create: tests/test-tutorial-fixtures.sh
- Test target: examples/tutorial/

Interfaces:
- The test consumes repository-relative tutorial fixture paths.
- The test produces a dependency-free static safety and structure check.

- [x] Step 1: Write the failing fixture test

Create an executable Bash test requiring:

~~~text
examples/tutorial/README.md
examples/tutorial/ollama-python-project/.workshop/dev.yaml
examples/tutorial/ollama-python-project/.workshop/console/sdk.yaml
examples/tutorial/ollama-python-project/.workshop/console/hooks/setup-project
examples/tutorial/ollama-sdk/sdkcraft.yaml
examples/tutorial/ollama-sdk/ollama.service
examples/tutorial/ollama-sdk/hooks/setup-base
examples/tutorial/ollama-sdk/hooks/setup-project
examples/tutorial/ollama-sdk/hooks/check-health
examples/tutorial/ollama-sdk/tests/README.md
~~~

The test must assert that the Workshop definition contains ollama, uv, jupyter, project-console, system, connections, a tunnel endpoint, and a pull action. It must assert that sdkcraft.yaml contains name, platforms, parts, plugs, and slots; all three hooks are executable; and no fixture definition or hook contains credentials, packed .sdk files, .workshop.lock, lxd init, sdkcraft login, sdkcraft register, or sdkcraft upload commands. The README may document those explicitly operator-run publication commands. End with tutorial fixtures PASS.

- [x] Step 2: Run the test to verify it fails correctly

Run:

~~~bash
bash tests/test-tutorial-fixtures.sh
~~~

Expected: FAIL with a missing-fixture message because examples/tutorial/ does not yet exist.

### Task 3: Implement SDKcraft installation and project routing

Files:
- Modify: workshop-automated-installer.sh
- Test: tests/test-workshop-automated-installer.sh

Interfaces:
- Adds sdkcraft-install and sdkcraft-refresh.
- Makes sdkcraft ... execute in PROJECT_DIR, preserving exact arguments.
- Keeps dry-run output in the existing plan format and JSON/error conventions.

- [x] Step 1: Add SDKcraft snap install/refresh helpers

Implement install_or_refresh_sdkcraft, cmd_sdkcraft_install, and cmd_sdkcraft_refresh beside the existing snap helpers. Use the configured privilege prefix and snap command, install with --classic, refresh without --classic, reject positional arguments, and use run_command for dry-run.

- [x] Step 2: Add a project-aware tool runner

Implement run_project_tool with the same dry-run, executable resolution, and JSON envelope behavior as run_tool, but execute with cd PROJECT_DIR. Use it for sdkcraft only; leave sdk, workshopctl, and version queries machine-level.

- [x] Step 3: Update the command surface

Add sdkcraft-install and sdkcraft-refresh to usage, Bash/Zsh/Fish/PowerShell completion, and dispatch. Keep install limited to LXD and Workshop so SDKcraft is never installed unexpectedly.

- [x] Step 4: Include the fixture test in CI smoke

Add tests/test-tutorial-fixtures.sh to cmd_ci syntax/ShellCheck lists and execute it after the documentation/layout checks.

- [x] Step 5: Run the focused test and verify green

Run:

~~~bash
bash tests/test-workshop-automated-installer.sh
~~~

Expected: PASS, including exact snap operations and SDKcraft working-directory assertions.

### Task 4: Add checked-in tutorial fixtures

Files:
- Create: examples/tutorial/README.md
- Create: examples/tutorial/ollama-python-project/.workshop/dev.yaml
- Create: examples/tutorial/ollama-python-project/.workshop/console/sdk.yaml
- Create: examples/tutorial/ollama-python-project/.workshop/console/hooks/setup-project
- Create: examples/tutorial/ollama-sdk/sdkcraft.yaml
- Create: examples/tutorial/ollama-sdk/ollama.service
- Create: examples/tutorial/ollama-sdk/hooks/setup-base
- Create: examples/tutorial/ollama-sdk/hooks/setup-project
- Create: examples/tutorial/ollama-sdk/hooks/check-health
- Create: examples/tutorial/ollama-sdk/tests/README.md
- Test: tests/test-tutorial-fixtures.sh

Interfaces:
- The final Workshop fixture is a copyable definition using Ollama, uv, Jupyter, a system tunnel plug, a jupyter:venv to uv:venv connection, and a model pull action.
- The console fixture is an in-project SDK under .workshop/console/.
- The SDKcraft fixture is a source tree only; try, test, and publication remain explicit operator commands.

- [x] Step 1: Add the final Workshop definition

Create dev.yaml with valid YAML equivalent to:

~~~yaml
name: dev
base: ubuntu@24.04
sdks:
  - name: ollama
    channel: vulkan/stable
  - name: uv
  - name: jupyter
  - name: project-console
  - name: system
    plugs:
      jupyter:
        interface: tunnel
        endpoint: 127.0.0.1:8989
connections:
  - plug: jupyter:venv
    slot: uv:venv
actions:
  pull: ollama pull "$@"
~~~

- [x] Step 2: Add the in-project console SDK

Create sdk.yaml with name: console. Create the executable hooks/setup-project containing:

~~~bash
#!/usr/bin/env bash
set -Eeuo pipefail
source /var/lib/workshop/sdk/jupyter/venv/bin/activate
pip install jupyter-console
~~~

- [x] Step 3: Add the SDKcraft source definition and hooks

Create sdkcraft.yaml with the tutorial Ollama metadata, Ubuntu 22.04 and 24.04 amd64 platforms, ollama and user-service dump parts, a models mount plug, gpu plug, and ollama-server tunnel slot. Add ollama.service, executable setup-base, setup-project, and check-health hooks. The health hook must use sudo -u workshop --login ollama list, report failures with workshopctl set-health error, and report success with workshopctl set-health okay.

- [x] Step 4: Document the fixture lifecycle and boundaries

Write examples/tutorial/README.md with exact wrapper examples for sdkcraft-install, sdkcraft init, sdkcraft clean, sdkcraft try, sdkcraft test, sdkcraft login, sdkcraft register, and sdkcraft upload. Mark login, register, upload, live Workshop commands, and host interfaces as explicit operator actions. Include no credentials or generated artifacts.

- [x] Step 5: Run the fixture test and verify green

Run:

~~~bash
bash tests/test-tutorial-fixtures.sh
~~~

Expected: tutorial fixtures PASS.

### Task 5: Integrate tutorial documentation and CI

Files:
- Create: docs/tutorial.md
- Modify: README.md
- Modify: docs/architecture.md
- Modify: docs/development.md
- Modify: docs/release.md
- Modify: SECURITY.md
- Modify: CHANGELOG.md
- Modify: ROADMAP.md
- Modify: IMPLEMENTATION-CHECKLIST.md
- Modify: .github/workflows/ci.yml
- Modify: .github/workflows/workshop-smoke.yml
- Modify: tests/test-documentation-contract.sh

Interfaces:
- Documentation maps all four tutorial parts to wrapper commands and fixture paths.
- Baseline and focused GitHub workflows require and execute fixture validation without live host effects.

- [x] Step 1: Write the tutorial runbook

Create docs/tutorial.md with four sections matching the Ubuntu tutorial: lifecycle/execution/restore/changes/tasks; connections/remounts/tunnel/uv wiring; sketch/stash/restore/eject/remove; and SDKcraft init/try/test/publish/use. Each section must show the exact wrapper command, the equivalent native command where helpful, the fixture path, and a warning for live or credentialed operations.

- [x] Step 2: Update project documentation

Add the tutorial runbook and examples/tutorial/ to README structure and usage. Update architecture components/data boundaries, development commands, release gates, security constraints, checklist completion items, roadmap baseline, and the Unreleased changelog entry. Keep the published 0.1.0 section unchanged except for adding the new Unreleased integration entry.

- [x] Step 3: Update GitHub workflow required files and paths

Require tests/test-tutorial-fixtures.sh, docs/tutorial.md, and the complete fixture tree in .github/workflows/ci.yml. Add examples/** and docs/tutorial.md to the focused Workshop workflow path filters. Keep checkout@v7, CodeQL v4, and dependency-review v5 unchanged.

- [x] Step 4: Extend the documentation contract

Require docs/tutorial.md, examples/tutorial/README.md, and the tutorial fixture test. Assert README links the tutorial runbook and fixture tree, the runbook names all four parts, and project/GitHub docs contain no stale ztemplate or obsolete root-layout references.

- [x] Step 5: Run documentation and CI checks

Run:

~~~bash
bash tests/test-documentation-contract.sh
bash tests/test-root-workshop-layout.sh
make test
~~~

Expected: all checks exit 0.

### Task 6: Full verification and signed publication

Files:
- Verify all changed files and repository state.

Interfaces:
- Consumes the completed wrapper, fixtures, docs, and workflows.
- Produces a clean GPG-signed commit pushed to origin/main with exact local and remote SHA plus hosted CI/security evidence.

- [x] Step 1: Run the complete local matrix

Run:

~~~bash
bash -n workshop-automated-installer.sh tests/test-workshop-automated-installer.sh tests/test-root-workshop-layout.sh tests/test-documentation-contract.sh tests/test-tutorial-fixtures.sh ci/workshop-smoke.sh
shellcheck --shell=bash workshop-automated-installer.sh tests/test-workshop-automated-installer.sh tests/test-root-workshop-layout.sh tests/test-documentation-contract.sh tests/test-tutorial-fixtures.sh ci/workshop-smoke.sh
python3 - <<'PY'
import glob
import yaml
for path in sorted(glob.glob('.github/**/*.[y]ml', recursive=True)):
    with open(path, encoding='utf-8') as handle:
        yaml.safe_load(handle)
    print(f'ok {path}')
PY
make ci
bash ci/workshop-smoke.sh
git diff --check
~~~

Verify no uws/, .ci-dry-run, .workshop.lock, .workshop/, packed SDK, credential, or secret-bearing artifact exists in the repository.

- [ ] Step 2: Inspect and stage only the integration

Run git status --short, git diff --stat, and git diff --cached --name-status after staging only the files listed in this plan. Run git diff --cached --check before committing.

- [ ] Step 3: Create and verify the signed commit

Fetch first, confirm origin/main has not advanced unexpectedly, then create a GPG-signed Conventional Commit with the configured identity and run:

~~~bash
git verify-commit HEAD
git status --short --branch
~~~

- [ ] Step 4: Push and verify remote state

Push only a fast-forward to origin/main, then verify git rev-parse HEAD, git rev-parse origin/main, git ls-remote origin refs/heads/main, and the GitHub commit verification API. If the remote advances, preserve its commits and rebase the local integration commit with GPG signing before pushing.

- [ ] Step 5: Verify hosted checks for the exact SHA

Monitor the CI, Workshop wrapper smoke, and CodeQL push runs for the final SHA with gh run watch --exit-status. Query all three final run conclusions and retain their URLs in the completion report. Do not claim completion with a failed or unverified hosted run.
