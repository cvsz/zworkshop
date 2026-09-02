#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
FIXTURE_DIR="$ROOT_DIR/examples/tutorial"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_file_contains() {
    local needle=$1
    local file=$2
    local description=$3

    grep -Fq -- "$needle" "$file" \
        || fail "$description: missing $needle in $file"
}

[[ -d "$FIXTURE_DIR" ]] || fail "missing tutorial fixture directory: $FIXTURE_DIR"

required_files=(
    "$FIXTURE_DIR/README.md"
    "$FIXTURE_DIR/ollama-python-project/.workshop/dev.yaml"
    "$FIXTURE_DIR/ollama-python-project/.workshop/console/sdk.yaml"
    "$FIXTURE_DIR/ollama-python-project/.workshop/console/hooks/setup-project"
    "$FIXTURE_DIR/ollama-sdk/sdkcraft.yaml"
    "$FIXTURE_DIR/ollama-sdk/ollama.service"
    "$FIXTURE_DIR/ollama-sdk/hooks/setup-base"
    "$FIXTURE_DIR/ollama-sdk/hooks/setup-project"
    "$FIXTURE_DIR/ollama-sdk/hooks/check-health"
    "$FIXTURE_DIR/ollama-sdk/tests/README.md"
)

for file in "${required_files[@]}"; do
    [[ -f "$file" ]] || fail "missing tutorial fixture file: ${file#"$ROOT_DIR/"}"
done

workshop_definition="${required_files[1]}"
sdkcraft_definition="${required_files[4]}"

for needle in ollama uv jupyter project-console system connections 'interface: tunnel' \
    'endpoint: 127.0.0.1:8989' 'jupyter:venv' 'uv:venv' 'pull:'; do
    assert_file_contains "$needle" "$workshop_definition" "Workshop tutorial definition"
done

for needle in 'name:' 'platforms:' 'parts:' 'plugs:' 'slots:'; do
    assert_file_contains "$needle" "$sdkcraft_definition" "SDKcraft tutorial definition"
done

for hook in \
    "$FIXTURE_DIR/ollama-python-project/.workshop/console/hooks/setup-project" \
    "$FIXTURE_DIR/ollama-sdk/hooks/setup-base" \
    "$FIXTURE_DIR/ollama-sdk/hooks/setup-project" \
    "$FIXTURE_DIR/ollama-sdk/hooks/check-health"; do
    [[ -x "$hook" ]] || fail "tutorial hook is not executable: ${hook#"$ROOT_DIR/"}"
done

static_files=(
    "$workshop_definition"
    "$FIXTURE_DIR/ollama-python-project/.workshop/console/sdk.yaml"
    "$sdkcraft_definition"
    "$FIXTURE_DIR/ollama-python-project/.workshop/console/hooks/setup-project"
    "$FIXTURE_DIR/ollama-sdk/hooks/setup-base"
    "$FIXTURE_DIR/ollama-sdk/hooks/setup-project"
    "$FIXTURE_DIR/ollama-sdk/hooks/check-health"
)

if rg -n -e 'BEGIN [A-Z0-9 ]+PRIVATE KEY|(^|[[:space:]])(password|token|secret)[[:space:]]*=' \
    "${static_files[@]}"; then
    fail "tutorial fixture contains credential material"
fi

if rg -n -e '(^|[[:space:]])lxd[[:space:]]+init|(^|[[:space:]])sdkcraft[[:space:]]+(login|register|upload)' \
    "${static_files[@]}"; then
    fail "tutorial fixture definitions or hooks contain live-only operations"
fi

if find "$FIXTURE_DIR" -type f -name '*.sdk' -print -quit | grep -q .; then
    fail "tutorial fixture contains a packed .sdk artifact"
fi

if find "$FIXTURE_DIR" -type f -name '.workshop.lock' -print -quit | grep -q .; then
    fail "tutorial fixture contains runtime lock state"
fi

if find "$FIXTURE_DIR" -type f \( -name '*.pem' -o -name '*.key' -o -name 'id_rsa' \
    -o -name 'id_ed25519' \) -print -quit | grep -q .; then
    fail "tutorial fixture contains a private-key file"
fi

assert_file_contains './workshop-automated-installer.sh sdkcraft-install' \
    "$FIXTURE_DIR/README.md" "tutorial README SDKcraft installation example"
assert_file_contains 'sdkcraft init' "$FIXTURE_DIR/README.md" \
    "tutorial README SDKcraft init example"
assert_file_contains 'sdkcraft clean' "$FIXTURE_DIR/README.md" \
    "tutorial README SDKcraft clean example"
assert_file_contains 'sdkcraft try' "$FIXTURE_DIR/README.md" \
    "tutorial README SDKcraft try example"
assert_file_contains 'sdkcraft test' "$FIXTURE_DIR/README.md" \
    "tutorial README SDKcraft test example"
assert_file_contains 'sdkcraft login' "$FIXTURE_DIR/README.md" \
    "tutorial README SDKcraft login boundary"
assert_file_contains 'sdkcraft register' "$FIXTURE_DIR/README.md" \
    "tutorial README SDKcraft register boundary"
assert_file_contains 'sdkcraft upload' "$FIXTURE_DIR/README.md" \
    "tutorial README SDKcraft upload boundary"

printf 'tutorial fixtures PASS\n'
