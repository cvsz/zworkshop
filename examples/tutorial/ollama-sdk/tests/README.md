# Ollama SDK test notes

This directory intentionally contains documentation only. The source fixture
is suitable for an operator to run through SDKcraft's live test workflow:

```bash
./workshop-automated-installer.sh \
  --project-dir examples/tutorial/ollama-sdk sdkcraft test
```

The test environment must provide the required SDKcraft tooling and any
explicit host capabilities selected by the operator. Review the packed
contents, service behavior, health hook, model mount, GPU plug, and tunnel
slot before trying or publishing the SDK. Do not commit generated `.sdk`
artifacts, credentials, model caches, or runtime state.
