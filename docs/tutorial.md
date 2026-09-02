# Ubuntu Workshop tutorial integration

This repository maps the current four-part [Ubuntu Workshop tutorial](https://ubuntu.com/workshop/docs/tutorial/)
to one root wrapper and reviewable examples. The wrapper keeps the tutorial's
native command arguments intact while making project-directory selection,
installation, dry-run, and destructive-operation boundaries explicit.

| Tutorial part | Repository entrypoint | Checked-in material |
| --- | --- | --- |
| [Get started](https://ubuntu.com/workshop/docs/tutorial/part-1-get-started/) | `install`, `init`, lifecycle, execution, actions, changes, and tasks | `examples/tutorial/ollama-python-project/.workshop/dev.yaml` |
| [Work with interfaces](https://ubuntu.com/workshop/docs/tutorial/part-2-work-with-interfaces/) | `connections`, `connect`, `disconnect`, `remount`, and `native` | the final `dev.yaml` interface layout |
| [Sketch SDKs](https://ubuntu.com/workshop/docs/tutorial/part-3-sketch-sdks/) | `sketch-sdk`, `sketches`, `sketch-stash`, `sketch-restore`, `sketch-remove`, and `sketch-eject` | `.workshop/console/` in the Python project |
| [Craft SDKs](https://ubuntu.com/workshop/docs/tutorial/part-4-craft-sdks/) | `sdkcraft-install`, `sdkcraft-refresh`, and project-aware `sdkcraft` passthrough | `examples/tutorial/ollama-sdk/` |

## Boundary and prerequisites

The wrapper is a Bash operator entrypoint. It installs or refreshes only the
LXD and Workshop snaps for `install`; SDKcraft installation is a separate
explicit command. It never runs `lxd init`, selects host storage or networking,
connects a GPU or mount implicitly, or logs in to or publishes to the SDK
Store. Live Workshop and SDKcraft commands require an approved snap-enabled
host and operator intent.

Use a dry run while reviewing a command:

```bash
./workshop-automated-installer.sh --dry-run install
./workshop-automated-installer.sh --dry-run \
  --project-dir ./my-project --workshop dev bootstrap
```

Tests and CI use fake commands and temporary directories. They do not install
snaps, initialize LXD, launch a workshop, download models, contact the SDK
Store, build SDK artifacts, or publish an SDK.

## Part 1: Get started

The tutorial uses LXD 6 and a classic Workshop snap. The wrapper makes the
same prerequisite operations repeatable:

```bash
./workshop-automated-installer.sh install
```

SDK Store discovery remains a machine-level query and is passed through
unchanged:

```bash
./workshop-automated-installer.sh sdk-find ollama
./workshop-automated-installer.sh sdk-info ollama
```

Create the project and definition. `init` creates the directory if necessary,
initializes Git by default, refuses to overwrite an existing definition, and
adds `.workshop.lock` to `.gitignore`:

```bash
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project \
  --workshop dev \
  --base ubuntu@22.04 \
  --sdks ollama/cpu/stable \
  init
```

The checked-in final definition uses Ubuntu 24.04, the Vulkan Ollama channel,
`uv`, Jupyter, an in-project console SDK, a loopback tunnel, shared Python
environment wiring, and a reusable model action. Copy it into a new project
when you want the final state without running the earlier scaffold steps:

```bash
cp -R examples/tutorial/ollama-python-project ./ollama-python-project-final
```

Use these wrapper commands for the lifecycle covered in the tutorial:

```bash
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final --workshop dev list
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final --workshop dev launch
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final --workshop dev info
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final sdk-list
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final --workshop dev stop
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final --workshop dev start
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final --workshop dev refresh
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final --workshop dev restore
```

Run commands, open a shell, and invoke the reusable `pull` action:

```bash
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final --workshop dev ollama run tinyllama
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final --workshop dev ollama list
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final --workshop dev shell
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final --workshop dev run -- pull tinyllama
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final --workshop dev pull-model tinyllama
```

Track atomic changes and their tasks with the wrapper's query commands:

```bash
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final changes
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final tasks
```

Runtime `.workshop.lock` state must stay in the project directory and out of
version control. The definition and `.workshop/` SDK sources are the
reviewable, shareable files.

## Part 2: Work with interfaces

The final project definition at
`examples/tutorial/ollama-python-project/.workshop/dev.yaml` includes:

- `ollama`, `uv`, `jupyter`, and `project-console` SDKs;
- the `system:jupyter` tunnel plug at `127.0.0.1:8989`;
- a top-level `jupyter:venv` to `uv:venv` connection; and
- the Ollama SDK's model mount, GPU plug, and API tunnel slot.

Inspect and manage connections through the wrapper:

```bash
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final native connections
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final native connections --all
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final native disconnect dev/ollama:models
mkdir -p "$HOME/.ollama/models"
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final native remount \
  dev/ollama:models "$HOME/.ollama/models"
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final native connect dev/ollama:models :mount
```

The mount, GPU, and tunnel examples affect host resources. Review the target
path and endpoint before applying them. To add or change SDKs and interfaces,
edit `.workshop/dev.yaml`, then apply the definition explicitly:

```bash
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final native refresh
```

The fixture keeps the Jupyter tunnel loopback-only. It does not grant a public
listener or select a host mount automatically.

## Part 3: Sketch SDKs

Sketch SDKs are local experiments and do not require SDK Store publication.
The native `workshop sketch-sdk` flow is available as a root-wrapper command:

```bash
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final sketch-sdk
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final sketch-sdk --stash
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final sketch-sdk --restore
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final sketches
```

When the sketch is ready to keep, eject it as an in-project SDK and add the
`project-` entry to the definition:

```bash
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final sketch-sdk --eject --name console
# Add: - name: project-console to .workshop/dev.yaml
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final refresh
```

The checked-in result is:

```text
examples/tutorial/ollama-python-project/.workshop/console/sdk.yaml
examples/tutorial/ollama-python-project/.workshop/console/hooks/setup-project
```

To remove a sketch permanently, use the wrapper's explicit confirmation:

```bash
./workshop-automated-installer.sh --yes \
  --project-dir ./ollama-python-project-final native sketch-sdk --remove
./workshop-automated-installer.sh --yes \
  --project-dir ./ollama-python-project-final native remove
```

## Part 4: Craft SDKs

SDKcraft is installed separately from the Workshop wrapper's default install:

```bash
./workshop-automated-installer.sh sdkcraft-install
./workshop-automated-installer.sh sdkcraft-refresh
```

Start a new SDK source tree and initialize it from that directory. The
checked-in `ollama-sdk` tree is already initialized and contains the edited
definition shown by the tutorial:

```bash
mkdir -p /tmp/ollama-sdk
./workshop-automated-installer.sh \
  --project-dir /tmp/ollama-sdk sdkcraft init
```

The checked-in source tree contains metadata for Ubuntu 22.04 and 24.04
amd64, Ollama and service parts, a models mount plug, a GPU plug, an Ollama
API tunnel slot, and lifecycle hooks:

```text
examples/tutorial/ollama-sdk/sdkcraft.yaml
examples/tutorial/ollama-sdk/ollama.service
examples/tutorial/ollama-sdk/hooks/setup-base
examples/tutorial/ollama-sdk/hooks/setup-project
examples/tutorial/ollama-sdk/hooks/check-health
```

Run SDKcraft commands from the selected source directory. The wrapper does
not reinterpret or reorder their arguments:

```bash
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft clean
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft try
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft test
```

Before trying a locally built SDK in a Workshop, use the SDKcraft-produced
`try-ollama` SDK name in a reviewed Workshop definition and launch with the
diagnostic flags described by the tutorial:

```bash
./workshop-automated-installer.sh \
  --project-dir ./ollama-python-project-final native launch \
  --verbose --wait-on-error
```

`try` and `test` can create packed artifacts, provision LXD containers, and
run lifecycle hooks. Those effects are intentionally excluded from repository
CI.

### SDK Store publication

Publication is never automatic. After review and a successful live test, run
these commands interactively with an authenticated SDK Store session:

```bash
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft login
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft register ollama
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft upload \
  ./ollama_amd64_ubuntu@24.04.sdk --release latest/beta
```

Never put credentials, tokens, packed `.sdk` files, model caches, or Store
state in the repository.

## Validation

Run the complete non-mutating local gate:

```bash
bash tests/test-tutorial-fixtures.sh
make workshop-test
make workshop-smoke
```

The fixture test validates file presence, executable hooks, YAML key structure,
operator-only command boundaries, and absence of credentials and generated
runtime artifacts. `make ci` and the GitHub workflows include the same smoke
path. Passing these checks does not prove live snap, LXD, Workshop, GPU,
Jupyter, Ollama, Craft Parts, or SDK Store compatibility; use a separately
approved host validation for that evidence.
