#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
WORKFLOW="$ROOT_DIR/.github/workflows/release.yml"
MAKEFILE="$ROOT_DIR/Makefile"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local needle=$1
    grep -Fq -- "$needle" "$WORKFLOW" \
        || fail "release workflow is missing: $needle"
}

assert_not_contains() {
    local needle=$1
    if grep -Fq -- "$needle" "$WORKFLOW"; then
        fail "release workflow contains forbidden content: $needle"
    fi
}

assert_make_contains() {
    local needle=$1
    grep -Fq -- "$needle" "$MAKEFILE" \
        || fail "Makefile is missing release gate: $needle"
}

assert_top_level_read_permissions() {
    local actual
    actual="$(awk '
        /^permissions:$/ { in_top_level=1; next }
        in_top_level && /^concurrency:$/ { exit }
        in_top_level { print }
    ' "$WORKFLOW")"
    [[ "$actual" == "  contents: read" ]] \
        || fail "workflow-level permissions must be contents: read"
}

assert_job_permission() {
    local job=$1
    local expected=$2
    local actual
    actual="$(awk -v job="$job" '
        $0 == "  " job ":" { in_job=1; next }
        in_job && $0 ~ /^  [^ ]/ { exit }
        in_job && $0 == "    permissions:" { in_permissions=1; next }
        in_permissions && $0 ~ /^      contents: / { print; exit }
    ' "$WORKFLOW")"
    [[ "$actual" == "      contents: $expected" ]] \
        || fail "\${job} must have contents: \${expected}"
}

[[ -f "$WORKFLOW" ]] || fail "missing release workflow: $WORKFLOW"

assert_contains 'name: Release'
assert_contains 'push:'
assert_contains 'tags:'
assert_contains "- 'v*.*.*'"
assert_contains 'actions/checkout@v7'
assert_contains 'fetch-depth: 0'
assert_contains 'GITHUB_REF_TYPE'
assert_contains 'GITHUB_REF_NAME'
assert_contains 'GITHUB_SHA'
assert_contains 'git merge-base --is-ancestor'
assert_contains 'refs/remotes/origin/main'
assert_contains 'make ci'
assert_contains 'needs: validate'
assert_contains 'contents: read'
assert_contains 'contents: write'
assert_contains 'gh release create'
assert_contains '--verify-tag'
assert_contains '--generate-notes'
assert_contains "GH_TOKEN: \${{ github.token }}"
assert_contains "GH_REPO: \${{ github.repository }}"
assert_top_level_read_permissions
assert_job_permission validate read
assert_job_permission publish write

write_jobs="$(awk '
    /^  [a-zA-Z0-9_-]+:$/ { job=$1; sub(/:$/, "", job) }
    /^      contents: write$/ { print job }
' "$WORKFLOW")"
[[ "$write_jobs" == "publish" ]] \
    || fail "only publish may have contents: write"
assert_make_contains 'tests/test-release-workflow.sh'

assert_not_contains 'workflow_dispatch'
assert_not_contains 'pull_request_target'
assert_not_contains 'actions/upload-artifact'
assert_not_contains 'sdkcraft login'
assert_not_contains 'sdkcraft register'
assert_not_contains 'sdkcraft upload'
assert_not_contains 'git push'
assert_not_contains 'git tag'
assert_not_contains '--draft'
assert_not_contains '--latest=false'
assert_not_contains 'BEGIN PRIVATE KEY'

printf 'release workflow contract PASS\n'
