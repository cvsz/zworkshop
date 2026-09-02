# Architecture

Document the system context, major components, trust boundaries, data flows, external dependencies, persistence model, deployment model, scaling assumptions, failure modes, and security boundaries for the generated project.

## Required sections

- System context
- Components and responsibilities
- Data/storage model
- External integrations
- Authentication and authorization
- Trust boundaries
- Deployment topology
- Observability
- Availability and recovery
- Security considerations
- Known constraints

Record material decisions as ADRs under `docs/adr/`.

## Implemented Workshop automation baseline

### System context

The repository root contains a Bash operator wrapper,
`workshop-automated-installer.sh`, for the Ubuntu Workshop development
workflow. It manages only explicit local setup and delegates workshop state to
the native Workshop CLI, with LXD as the low-level runtime.

### Components and responsibilities

- `workshop-automated-installer.sh` parses options/configuration, enforces
  dry-run and destructive-operation boundaries, routes commands, and provides
  explicit SDKcraft snap installation/refresh operations.
- `tests/` uses fake `snap`, `lxd`, `workshop`, SDK, and privilege commands in
  temporary directories to test forwarding and safety behavior.
- `tests/test-documentation-contract.sh` checks that project and GitHub
  documentation stay aligned with the root layout and supported action
  versions.
- `tests/test-tutorial-fixtures.sh` validates the definition-first tutorial
  tree, executable hooks, required YAML structure, and the absence of runtime
  artifacts or live-only operations.
- `examples/tutorial/` contains the final Workshop definition, an ejected
  in-project console SDK, and an SDKcraft Ollama source tree. It is source
  material for an operator workflow, not a prebuilt or published artifact.
- `ci/workshop-smoke.sh` and `.github/workflows/workshop-smoke.yml` run the
  non-mutating repository gates; `.github/workflows/ci.yml` includes the same
  smoke gate in the baseline workflow.
- `.workshop/` is the version-controlled definition area for a user project;
  `.workshop.lock` is runtime state and is ignored.

### Trust boundaries and known constraints

The wrapper does not choose LXD storage/network configuration, run `lxd init`,
or silently enable host interfaces. `sdkcraft-install` and
`sdkcraft-refresh` are separate explicit snap operations; the default
`install` command never installs SDKcraft. `sdkcraft` passthrough commands run
from `--project-dir`, while SDK Store discovery remains machine-level.
Native Workshop, snap, SDKcraft, and Git operations remain external
operator-controlled effects. The test and CI paths do not prove live Ubuntu,
snap, LXD, GPU, Jupyter, Ollama, or Workshop compatibility; those require an
approved host-level validation run.

## Tutorial integration topology

The tutorial flow has one controlled local boundary and two source trees:

```text
operator
  |
  +-- workshop-automated-installer.sh
  |     +-- LXD/Workshop snap operations (explicit)
  |     +-- project-aware Workshop and SDKcraft commands
  |     +-- machine-level SDK Store queries
  |
  +-- examples/tutorial/ollama-python-project/.workshop/
  |     +-- dev.yaml
  |     +-- console/sdk.yaml and hooks/setup-project
  |
  +-- examples/tutorial/ollama-sdk/
        +-- sdkcraft.yaml, service, and lifecycle hooks
        +-- tests/README.md (live test location, no generated artifacts)
```

The Workshop definition coordinates Ollama, `uv`, Jupyter, the loopback
Jupyter tunnel, and the shared `jupyter:venv` to `uv:venv` connection. The
Ollama SDK's model mount, GPU plug, and API tunnel slot remain subject to
Workshop interface policy and explicit host-side decisions. SDKcraft `try`,
`test`, `login`, `register`, and `upload` are never executed by repository CI.
