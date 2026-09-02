# Ubuntu Workshop tutorial examples

These fixtures follow the four-part [Ubuntu Workshop tutorial](https://ubuntu.com/workshop/docs/tutorial/)
and keep the reusable entrypoint at the repository root:

```bash
./workshop-automated-installer.sh --help
```

The examples are intentionally definition-first. They are safe to inspect and
test statically, but they do not install snaps, initialize LXD, launch a
Workshop, download model data, or publish an SDK by themselves.

## Part 1: Get started

Install or refresh the LXD and Workshop prerequisites explicitly, then create a
project from the checked-in definition:

```bash
./workshop-automated-installer.sh install
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project \
  --workshop dev \
  --base ubuntu@24.04 \
  --sdks ollama/cpu/stable \
  init
```

Use the wrapper for project lifecycle and execution operations:

```bash
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project --workshop dev list
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project --workshop dev launch
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project --workshop dev pull-model tinyllama
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project --workshop dev ollama run tinyllama
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project --workshop dev ollama list
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project --workshop dev run -- pull tinyllama
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project --workshop dev shell
```

The lifecycle commands are explicit. Stop, refresh, restore, remove, and model
operations should be selected by the operator for the intended project.

## Part 2: Work with interfaces

The project definition demonstrates the Jupyter SDK, the `jupyter:venv` to
`uv:venv` connection, and a loopback-only system tunnel. Inspect and modify
connections with native Workshop passthrough so the current CLI options
remain available:

```bash
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project \
  native connections
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project \
  native disconnect dev/ollama:models
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project \
  native remount dev/ollama:models "$HOME/.ollama/models"
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project \
  native connect dev/ollama:models :mount
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project \
  native refresh
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project \
  native connections --all
```

Review the generated Workshop definition and adapt the connection or tunnel
endpoint to the local environment before exposing anything beyond
`127.0.0.1:8989`. Host mounts, GPU access, storage, and network exposure are
operator decisions.

## Part 3: Sketch SDKs

Sketch and eject an in-project SDK through the wrapper, then review the
generated files before using them:

```bash
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project \
  sketch-sdk --eject --name console
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project sketches
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project sketch-stash
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-python-project sketch-restore
```

The checked-in `console` SDK at
`.workshop/console/` is the reviewable result of this workflow. Removing a
sketch is destructive and requires the wrapper's explicit confirmation:

```bash
./workshop-automated-installer.sh --yes \
  --project-dir examples/tutorial/ollama-python-project native sketch-sdk --remove
```

## Part 4: Craft SDKs

Install SDKcraft explicitly and run its project commands from the SDK source
tree. The root wrapper preserves SDKcraft's arguments and changes only the
working-directory boundary. Initialize a new source directory when starting a
fresh SDK; the checked-in `ollama-sdk/` tree is already initialized and edited:

```bash
./workshop-automated-installer.sh sdkcraft-install
mkdir -p /tmp/ollama-sdk
./workshop-automated-installer.sh \
  --project-dir /tmp/ollama-sdk sdkcraft init
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft clean
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft try
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft test
./workshop-automated-installer.sh sdkcraft-refresh
```

The source tree contains `sdkcraft.yaml`, the Ollama user service, and hooks
for base setup, project setup, and health reporting. `try` and `test` are live
operator workflows and may build or run local artifacts; generated output is
not part of this repository.

SDK Store operations are also explicit operator actions. Authenticate and
publish only after reviewing the definition, test results, artifact contents,
and target channel:

```bash
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft login
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft register ollama
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft upload \
  ./ollama_amd64_ubuntu@24.04.sdk --release latest/beta
```

These commands require an interactive, authenticated environment. No
credentials, access tokens, packed `.sdk` files, or publication state belong in
the fixture tree.

## Static checks

Run the non-mutating checks from the repository root:

```bash
bash tests/test-tutorial-fixtures.sh
./workshop-automated-installer.sh ci
```

For a command preview, add `--dry-run` or `--plan` before the command. Static
checks never invoke the live snap, LXD, Workshop, SDK Store, or SDKcraft
publication paths.
