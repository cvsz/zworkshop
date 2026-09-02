#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local expected=$1
    local file=$2
    grep -Fq -- "$expected" "$ROOT_DIR/$file" \
        || fail "${file} is missing: ${expected}"
}

assert_not_contains() {
    local forbidden=$1
    shift
    local file
    for file in "$@"; do
        if grep -Fq -- "$forbidden" "$ROOT_DIR/$file"; then
            fail "${file} still contains: ${forbidden}"
        fi
    done
}

for file in \
    README.md \
    ABOUT.md \
    CONTRIBUTING.md \
    IMPLEMENTATION-CHECKLIST.md \
    ROADMAP.md \
    SECURITY.md \
    docs/architecture.md \
    docs/development.md \
    docs/release.md \
    docs/tutorial.md \
    examples/tutorial/README.md \
    .github/CODEOWNERS \
    .github/PULL_REQUEST_TEMPLATE.md \
    .github/ISSUE_TEMPLATE/config.yml \
    .github/ISSUE_TEMPLATE/feature_request.yml \
    .github/workflows/ci.yml \
    .github/workflows/codeql.yml \
    .github/workflows/dependency-review.yml \
    .github/workflows/release.yml \
    .github/workflows/workshop-smoke.yml \
    tests/test-tutorial-fixtures.sh \
    tests/test-release-workflow.sh; do
    test -f "$ROOT_DIR/$file" || fail "missing document: ${file}"
done

assert_contains '## Ubuntu Workshop automation' README.md
assert_contains 'Ubuntu Workshop' ABOUT.md
assert_contains 'zworkshop' IMPLEMENTATION-CHECKLIST.md
assert_contains 'Root Ubuntu Workshop automation' ROADMAP.md
assert_contains 'Workshop trust boundary' SECURITY.md
assert_contains 'workshop-automated-installer.sh' docs/architecture.md
assert_contains 'sdkcraft-install' README.md
assert_contains 'sdkcraft-refresh' README.md
assert_contains '[tutorial integration guide](docs/tutorial.md)' README.md
assert_contains '[definition-first fixtures](examples/tutorial/)' README.md
assert_contains 'examples/tutorial/' README.md
assert_contains 'Part 1: Get started' docs/tutorial.md
assert_contains 'Part 2: Work with interfaces' docs/tutorial.md
assert_contains 'Part 3: Sketch SDKs' docs/tutorial.md
assert_contains 'Part 4: Craft SDKs' docs/tutorial.md
assert_contains 'tests/test-tutorial-fixtures.sh' docs/development.md
assert_contains 'tests/test-release-workflow.sh' docs/development.md
assert_contains 'make workshop-test' CONTRIBUTING.md
assert_contains 'make workshop-smoke' .github/PULL_REQUEST_TEMPLATE.md
assert_contains 'https://github.com/cvsz/zworkshop/security' .github/ISSUE_TEMPLATE/config.yml
assert_contains 'workshop-smoke.yml' README.md
assert_contains '.github/workflows/release.yml' README.md
assert_contains 'actions/workflows/ci.yml/badge.svg?branch=main' README.md
assert_contains 'actions/workflows/workshop-smoke.yml/badge.svg?branch=main' README.md
assert_contains 'actions/workflows/codeql.yml/badge.svg?branch=main' README.md
assert_contains 'img.shields.io/github/v/release/cvsz/zworkshop' README.md
assert_contains "docs/**" .github/workflows/workshop-smoke.yml
assert_contains "examples/**" .github/workflows/workshop-smoke.yml
assert_contains 'actions/checkout@v7' .github/workflows/ci.yml
assert_contains 'github/codeql-action/init@v4' .github/workflows/codeql.yml
assert_contains 'actions/dependency-review-action@v5' .github/workflows/dependency-review.yml
assert_contains 'vMAJOR.MINOR.PATCH' docs/release.md
assert_contains 'gh release create' docs/release.md
assert_contains 'no automatic artifact upload' docs/release.md
assert_contains 'release.yml' .github/PULL_REQUEST_TEMPLATE.md

assert_not_contains 'ztemplate' \
    README.md ABOUT.md CONTRIBUTING.md IMPLEMENTATION-CHECKLIST.md ROADMAP.md \
    SECURITY.md docs/architecture.md docs/development.md docs/release.md \
    .github/CODEOWNERS .github/PULL_REQUEST_TEMPLATE.md \
    .github/ISSUE_TEMPLATE/config.yml .github/ISSUE_TEMPLATE/feature_request.yml
assert_not_contains 'github.com/cvsz/ztemplate' .github/ISSUE_TEMPLATE/config.yml

printf 'documentation contract PASS\n'
