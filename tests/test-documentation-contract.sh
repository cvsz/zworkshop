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
    .github/CODEOWNERS \
    .github/PULL_REQUEST_TEMPLATE.md \
    .github/ISSUE_TEMPLATE/config.yml \
    .github/ISSUE_TEMPLATE/feature_request.yml \
    .github/workflows/ci.yml \
    .github/workflows/codeql.yml \
    .github/workflows/dependency-review.yml \
    .github/workflows/workshop-smoke.yml; do
    test -f "$ROOT_DIR/$file" || fail "missing document: ${file}"
done

assert_contains '## Ubuntu Workshop automation' README.md
assert_contains 'Ubuntu Workshop' ABOUT.md
assert_contains 'zworkshop' IMPLEMENTATION-CHECKLIST.md
assert_contains 'Root Ubuntu Workshop automation' ROADMAP.md
assert_contains 'Workshop trust boundary' SECURITY.md
assert_contains 'workshop-automated-installer.sh' docs/architecture.md
assert_contains 'make workshop-test' CONTRIBUTING.md
assert_contains 'make workshop-smoke' .github/PULL_REQUEST_TEMPLATE.md
assert_contains 'https://github.com/cvsz/zworkshop/security' .github/ISSUE_TEMPLATE/config.yml
assert_contains 'workshop-smoke.yml' README.md
assert_contains "docs/**" .github/workflows/workshop-smoke.yml
assert_contains 'actions/checkout@v7' .github/workflows/ci.yml
assert_contains 'github/codeql-action/init@v4' .github/workflows/codeql.yml
assert_contains 'actions/dependency-review-action@v5' .github/workflows/dependency-review.yml

assert_not_contains 'ztemplate' \
    README.md ABOUT.md CONTRIBUTING.md IMPLEMENTATION-CHECKLIST.md ROADMAP.md \
    SECURITY.md docs/architecture.md docs/development.md docs/release.md \
    .github/CODEOWNERS .github/PULL_REQUEST_TEMPLATE.md \
    .github/ISSUE_TEMPLATE/config.yml .github/ISSUE_TEMPLATE/feature_request.yml
assert_not_contains 'github.com/cvsz/ztemplate' .github/ISSUE_TEMPLATE/config.yml
assert_not_contains 'release.yml' README.md

printf 'documentation contract PASS\n'
