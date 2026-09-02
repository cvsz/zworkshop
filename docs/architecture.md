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
  dry-run and destructive-operation boundaries, and routes commands.
- `tests/` uses fake `snap`, `lxd`, `workshop`, SDK, and privilege commands in
  temporary directories to test forwarding and safety behavior.
- `tests/test-documentation-contract.sh` checks that project and GitHub
  documentation stay aligned with the root layout and supported action
  versions.
- `ci/workshop-smoke.sh` and `.github/workflows/workshop-smoke.yml` run the
  non-mutating repository gates; `.github/workflows/ci.yml` includes the same
  smoke gate in the baseline workflow.
- `.workshop/` is the version-controlled definition area for a user project;
  `.workshop.lock` is runtime state and is ignored.

### Trust boundaries and known constraints

The wrapper does not choose LXD storage/network configuration, run `lxd init`,
or silently enable host interfaces. Native Workshop, snap, and Git operations
remain external operator-controlled effects. The test and CI paths do not prove
live Ubuntu, snap, LXD, GPU, or Workshop compatibility; those require an
approved host-level validation run.
