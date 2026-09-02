#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
INSTALLER="$ROOT_DIR/workshop-automated-installer.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local expected=$1
    local actual=$2
    local label=$3
    grep -Fq -- "$expected" <<<"$actual" || fail "$label (missing: $expected)"
}

assert_file_contains() {
    local expected=$1
    local file=$2
    local label=$3
    grep -Fq -- "$expected" "$file" || fail "$label (missing: $expected)"
}

[[ -f "$INSTALLER" ]] || fail "installer is missing"
bash -n "$INSTALLER" || fail "installer has invalid Bash syntax"

help_output="$(bash "$INSTALLER" --help)"
assert_contains "bootstrap" "$help_output" "help lists bootstrap"
assert_contains "completion" "$help_output" "help lists completion"
assert_contains "sdkcraft-install" "$help_output" "help lists SDKcraft installation"
assert_contains "sdkcraft-refresh" "$help_output" "help lists SDKcraft refresh"

dry_project="$(mktemp -d)"
dry_output="$(bash "$INSTALLER" --dry-run --project-dir "$dry_project" init 2>&1)"
assert_contains "Dry run complete" "$dry_output" "dry-run completes"
[[ ! -e "$dry_project/.workshop" ]] || fail "dry-run created a workshop directory"
rm -rf "$dry_project"

bootstrap_output="$(bash "$INSTALLER" --dry-run --project-dir /tmp/uws-bootstrap-test --workshop dev --model tinyllama bootstrap 2>&1)"
assert_contains "workshop launch dev" "$bootstrap_output" "bootstrap launch"
assert_contains "ollama pull tinyllama" "$bootstrap_output" "bootstrap model pull"

test_root="$(mktemp -d)"
fake_bin="$test_root/bin"
fake_state="$test_root/state"
project_dir="$test_root/project"
log_file="$test_root/commands.log"
mkdir -p "$fake_bin" "$fake_state" "$project_dir"

cleanup() {
    rm -rf "$test_root"
}
trap cleanup EXIT

cat >"$fake_bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "${1:-}" == "-v" ]]; then
    exit 0
fi
exec "$@"
EOF

cat >"$fake_bin/snap" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
log_file="${UWS_TEST_LOG:?}"
state_dir="${UWS_TEST_STATE:?}"
printf 'snap %s\n' "$*" >>"$log_file"
case "${1:-}" in
    list)
        [[ -e "$state_dir/${2:?}" ]] || exit 1
        printf 'Name Version Rev Tracking Publisher Notes\n'
        printf '%s 0.0 1 latest/stable - -\n' "$2"
        ;;
    install|refresh)
        touch "$state_dir/${@: -1}"
        ;;
    start)
        ;;
    services)
        printf 'Service Startup Current Notes\n'
        printf 'lxd.daemon enabled active -\n'
        ;;
    *)
        exit 2
        ;;
esac
EOF

cat >"$fake_bin/lxd" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "${1:-}" == "--version" ]] || exit 2
printf '6.9\n'
EOF

cat >"$fake_bin/workshop" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
log_file="${UWS_TEST_LOG:?}"
printf 'workshop %s\n' "$*" >>"$log_file"
case "${1:-}" in
    --version)
        printf 'workshop 0.2.0\n'
        ;;
    init)
        name="${2:?}"
        base='ubuntu@24.04'
        sdks='ollama/cpu/stable'
        while (($# > 0)); do
            case "$1" in
                --base) base="$2"; shift ;;
                --sdks) sdks="$2"; shift ;;
            esac
            shift
        done
        mkdir -p .workshop
        {
            printf 'name: %s\n' "$name"
            printf 'base: %s\n' "$base"
            printf 'sdks:\n'
            printf ' - name: %s\n' "${sdks%%/*}"
            printf '   channel: %s\n' "${sdks#*/}"
        } >".workshop/${name}.yaml"
        ;;
    list)
        printf 'WORKSHOP STATUS NOTES\ndev Ready -\n'
        ;;
    info)
        printf 'name: %s\nstatus: ready\n' "${2:-dev}"
        ;;
    actions)
        printf 'pull: ollama pull "$@"\n'
        ;;
    exec|run|shell|launch|refresh|start|stop|restore|remove|connections|connect|disconnect|remount|sketch-sdk|sketches|changes|tasks|warnings|okay)
        printf 'workshop-ok %s\n' "$1"
        ;;
    *)
        exit 2
        ;;
esac
EOF

cat >"$fake_bin/sdk" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'sdk %s\n' "$*" >>"${UWS_TEST_LOG:?}"
printf 'sdk-ok\n'
EOF

cat >"$fake_bin/sdkcraft" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'sdkcraft cwd=%s %s\n' "$PWD" "$*" >>"${UWS_TEST_LOG:?}"
printf 'sdkcraft-ok\n'
EOF

cat >"$fake_bin/workshopctl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'workshopctl %s\n' "$*" >>"${UWS_TEST_LOG:?}"
printf 'workshopctl-ok\n'
EOF

chmod 0755 "$fake_bin"/*
export PATH="$fake_bin:/usr/bin:/bin"
export UWS_TEST_LOG="$log_file"
export UWS_TEST_STATE="$fake_state"

bash "$INSTALLER" install >/dev/null || fail "fresh install path failed"
assert_file_contains "snap install --channel=6/stable lxd" "$log_file" "fresh LXD install"
assert_file_contains "snap install --classic workshop" "$log_file" "fresh Workshop install"
if grep -Fq 'sdkcraft' "$log_file"; then
    fail "install unexpectedly touched SDKcraft"
fi

bash "$INSTALLER" install >/dev/null || fail "refresh path failed"
assert_file_contains "snap refresh --channel=6/stable lxd" "$log_file" "existing LXD refresh"
assert_file_contains "snap refresh workshop" "$log_file" "existing Workshop refresh"

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
sdkcraft_plan="$(bash "$INSTALLER" --dry-run --project-dir "$sdkcraft_project" sdkcraft try 2>&1)"
assert_contains "(cd -- $sdkcraft_project && sdkcraft try)" "$sdkcraft_plan" \
    "SDKcraft dry-run project plan"

bash "$INSTALLER" \
    --project-dir "$project_dir" \
    --workshop dev \
    --base ubuntu@24.04 \
    --sdks ollama/cpu/stable \
    init >/dev/null || fail "init path failed"
[[ -f "$project_dir/.workshop/dev.yaml" ]] || fail "init did not create definition"
[[ -d "$project_dir/.git" ]] || fail "init did not initialize Git"
assert_file_contains '.workshop.lock' "$project_dir/.gitignore" "init gitignore entry"
assert_file_contains 'actions:' "$project_dir/.workshop/dev.yaml" "init Ollama action"

config_file="$test_root/workshop.conf"
config_project="$test_root/config-project"
printf '%s\n' \
    "UWS_PROJECT_DIR=$config_project" \
    'UWS_WORKSHOP_NAME=configured' \
    'UWS_USE_GIT=0' >"$config_file"
config_output="$(bash "$INSTALLER" --config "$config_file" --dry-run init 2>&1)"
assert_contains 'workshop init configured' "$config_output" "config workshop name"
if grep -Fq -- 'git init' <<<"$config_output"; then
    fail "UWS_USE_GIT=0 still planned git init"
fi

bash "$INSTALLER" --project-dir "$project_dir" --workshop dev pull-model mistral >/dev/null \
    || fail "pull-model dispatch failed"
assert_file_contains 'workshop exec dev -- ollama pull mistral' "$log_file" "model pull forwarding"

if bash "$INSTALLER" --project-dir "$project_dir" --workshop dev init >/dev/null 2>&1; then
    fail "init overwrote an existing definition"
fi

bash "$INSTALLER" \
    --project-dir "$project_dir" \
    --workshop dev \
    --json info >"$test_root/info.json" || fail "JSON info failed"
assert_file_contains '"exit_code":0' "$test_root/info.json" "JSON exit code"
assert_file_contains '"output":' "$test_root/info.json" "JSON output field"

bash "$INSTALLER" --project-dir "$project_dir" --workshop dev refresh --wait-on-error >/dev/null \
    || fail "refresh dispatch failed"
assert_file_contains 'workshop refresh dev --wait-on-error' "$log_file" "refresh argument forwarding"

bash "$INSTALLER" --project-dir "$project_dir" connect dev/ollama:gpu :gpu >/dev/null \
    || fail "connect dispatch failed"
assert_file_contains 'workshop connect dev/ollama:gpu :gpu' "$log_file" "connect forwarding"

bash "$INSTALLER" sdk find ollama >/dev/null || fail "SDK dispatch failed"
assert_file_contains 'sdk find ollama' "$log_file" "SDK forwarding"

bash "$INSTALLER" workshopctl status >/dev/null || fail "workshopctl dispatch failed"
assert_file_contains 'workshopctl status' "$log_file" "workshopctl forwarding"

if bash "$INSTALLER" --project-dir "$project_dir" --workshop dev remove >/dev/null 2>&1; then
    fail "remove ran without confirmation"
fi
bash "$INSTALLER" --yes --project-dir "$project_dir" --workshop dev remove >/dev/null \
    || fail "confirmed remove failed"

completion_output="$(bash "$INSTALLER" completion bash)"
assert_contains 'complete -F' "$completion_output" "Bash completion"
assert_contains 'sdkcraft-install' "$completion_output" "Bash SDKcraft completion"
assert_contains 'sdkcraft-refresh' "$completion_output" "Bash SDKcraft refresh completion"

completion_output="$(bash "$INSTALLER" completion zsh)"
assert_contains 'sdkcraft-install' "$completion_output" "Zsh SDKcraft completion"
assert_contains 'sdkcraft-refresh' "$completion_output" "Zsh SDKcraft refresh completion"

completion_output="$(bash "$INSTALLER" completion fish)"
assert_contains 'sdkcraft-install' "$completion_output" "Fish SDKcraft completion"
assert_contains 'sdkcraft-refresh' "$completion_output" "Fish SDKcraft refresh completion"

completion_output="$(bash "$INSTALLER" completion powershell)"
assert_contains 'sdkcraft-install' "$completion_output" "PowerShell SDKcraft completion"
assert_contains 'sdkcraft-refresh' "$completion_output" "PowerShell SDKcraft refresh completion"

doctor_output="$(bash "$INSTALLER" --json --project-dir "$project_dir" doctor)"
assert_contains '"command":"doctor"' "$doctor_output" "JSON doctor command"

printf 'PASS\n'
