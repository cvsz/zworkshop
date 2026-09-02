# Ubuntu Workshop Tutorial Integration Design

**Status:** Implementation complete; local verification passed; hosted verification pending (2026-09-02)

## Goal

Make `zworkshop` cover the complete four-part Ubuntu Workshop tutorial with a
reusable root wrapper, checked-in tutorial fixtures, deterministic tests, and
project/GitHub documentation. The implementation covers the tutorial workflow
without silently performing host-level or SDK Store operations.

The source material is the current Ubuntu Workshop tutorial:

- [Part 1: Get started](https://ubuntu.com/workshop/docs/tutorial/part-1-get-started/)
- [Part 2: Work with interfaces](https://ubuntu.com/workshop/docs/tutorial/part-2-work-with-interfaces/)
- [Part 3: Sketch SDKs](https://ubuntu.com/workshop/docs/tutorial/part-3-sketch-sdks/)
- [Part 4: Craft SDKs](https://ubuntu.com/workshop/docs/tutorial/part-4-craft-sdks/)

## Scope

### Included

- Wrapper support for every tutorial command category: LXD and Workshop
  installation, SDK discovery, project initialization, Workshop lifecycle,
  execution, reusable actions, changes/tasks, interfaces, sketch operations,
  in-project SDKs, SDKcraft installation, SDKcraft build/test/publish
  passthrough, diagnostics, completion, JSON output, and dry-run planning.
- Explicit `sdkcraft-install` and `sdkcraft-refresh` commands. The existing
  `sdkcraft` command remains a passthrough for `init`, `clean`, `try`, `test`,
  `login`, `register`, and `upload`.
- Project-directory execution for SDKcraft so commands operate on the SDK
  source tree selected by `--project-dir`.
- A checked-in `examples/tutorial/` fixture set containing a final Workshop
  definition using Ollama, Jupyter, `uv`, tunnel wiring, mount persistence,
  connections, and a reusable model action; an in-project sketch SDK; and an
  SDKcraft Ollama definition with service and lifecycle hooks.
- `docs/tutorial.md`, README examples, architecture and security boundaries,
  development/release instructions, changelog, roadmap, and GitHub workflow
  coverage that point to the fixture set and exact wrapper commands.
- Static fixture validation and fake-command coverage for CI. Tests use
  temporary directories and never install snaps, initialize LXD, launch a
  workshop, contact the SDK Store, or publish an SDK.

### Excluded

- Automatic `lxd init`, storage selection, network configuration, GPU access,
  host mount changes, or tunnel exposure.
- Automatic `sdkcraft login`, SDK registration, artifact upload, or release
  promotion. These remain explicit operator commands and require the operator's
  credentials and approval.
- Claiming live Ubuntu, LXD, Workshop, GPU, Jupyter, Ollama, Craft Parts, or
  SDK Store compatibility from static tests alone.
- Copying private credentials, model caches, generated SDK artifacts, or
  `.workshop.lock` into the repository.

## Architecture

### Root wrapper

`workshop-automated-installer.sh` remains the single dependency-free Bash
entrypoint. Existing lifecycle, query, execution, interface, sketch, and
diagnostic routing is preserved. The implementation adds snap installation and
refresh helpers for SDKcraft and a project-aware tool runner for SDKcraft
commands. Dry-run and plan modes render the exact command without executing it.

The command surface is:

```text
install sdkcraft-install sdkcraft-refresh
init bootstrap
launch refresh start stop restore remove
list status info actions changes tasks warnings okay
exec shell run ollama pull-model
connections connect disconnect remount
sdk sdk-find sdk-info sdk-list
sketch-sdk sketches sketch-stash sketch-restore sketch-remove sketch-eject
sdkcraft native workshop workshopctl version
doctor completion ci
```

`--project-dir` is the working directory for Workshop and SDKcraft commands;
SDK Store queries remain machine-level commands. `--yes` is required for
destructive removal operations in non-interactive sessions. Existing Workshop
definitions are never overwritten.

### Tutorial fixtures

The fixture tree is definition-first and safe to inspect:

```text
examples/tutorial/
  README.md
  ollama-python-project/
    .workshop/dev.yaml
    .workshop/console/sdk.yaml
    .workshop/console/hooks/setup-project
  ollama-sdk/
    sdkcraft.yaml
    ollama.service
    hooks/setup-base
    hooks/setup-project
    hooks/check-health
    tests/README.md
```

The Workshop fixture demonstrates the final state reached across Parts 1–3:
the `ollama`, `uv`, and `jupyter` SDKs, the `system` tunnel plug, the
`jupyter:venv` to `uv:venv` connection, the persistent Ollama models mount,
and a `pull` action. The `console` directory represents the Part 3 ejected
in-project SDK. The SDKcraft fixture represents Part 4's metadata, parts,
service, plugs, slots, hooks, and test location without building or uploading
artifacts.

### Validation flow

`tests/test-tutorial-fixtures.sh` verifies required files, executable hooks,
definition keys, tutorial command examples, absence of credentials/artifacts,
and forbidden live-mutation commands. `ci/workshop-smoke.sh` runs this check
through the existing root CI command. The GitHub workflows continue to use
fake commands and temporary directories only.

## Data and trust boundaries

- `.workshop/*.yaml` and `.workshop/<sdk>/` are project definitions intended
  for version control.
- `.workshop.lock`, SDK Store credentials, model caches, packed `.sdk` files,
  and LXD state are runtime or operator data and are not fixtures.
- Snap installation, LXD daemon control, native Workshop state changes, host
  interfaces, and SDK Store publication are external effects behind explicit
  commands.
- The fixture test boundary is local filesystem content and fake executables;
  it does not establish runtime compatibility.

## Acceptance criteria

- The wrapper help and completion output list the complete tutorial command
  categories, including SDKcraft installation and passthrough.
- `sdkcraft` commands run from `--project-dir`, while
  `sdkcraft-install`/`sdkcraft-refresh` use the configured snap path and
  privilege boundary.
- All fixture files are present, safe, documented, and validated in local and
  GitHub smoke checks.
- README and `docs/tutorial.md` map each tutorial part to exact project
  commands and fixture paths.
- `bash -n`, ShellCheck, `make test`, `make ci`, YAML parsing, and the focused
  smoke workflow pass without live snap/LXD mutation.
- The implementation is committed with the configured GPG identity and
  pushed only after local and hosted validation succeeds.

## Risks and mitigations

- **Tutorial drift:** Keep the source URLs and captured command forms in the
  docs, add version-sensitive notes, and avoid hard-coding runtime output.
- **Accidental host mutation:** Keep live installs explicit, make dry-run
  output testable, and ensure CI uses fakes and temporary paths.
- **Credential leakage:** Never add login material or packed SDK artifacts to
  fixtures; document publish commands without tokens.
- **Fixture misuse:** Label definitions as examples and require an operator to
  copy/customize them before launching a real Workshop.
