#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

for path in \
    workshop-automated-installer.sh \
    tests/test-workshop-automated-installer.sh \
    tests/test-tutorial-fixtures.sh \
    tests/test-root-workshop-layout.sh \
    ci/workshop-smoke.sh \
    .github/workflows/workshop-smoke.yml \
    docs/tutorial.md \
    examples/tutorial/README.md \
    docs/superpowers/specs/2026-09-02-workshop-full-wrapper-design.md \
    docs/superpowers/plans/2026-09-02-workshop-full-wrapper.md; do
    test -f "$ROOT_DIR/$path" || { echo "missing root path: $path" >&2; exit 1; }
done

test ! -e "$ROOT_DIR/uws"
test -x "$ROOT_DIR/workshop-automated-installer.sh"
test -x "$ROOT_DIR/tests/test-workshop-automated-installer.sh"
test -x "$ROOT_DIR/tests/test-tutorial-fixtures.sh"
test -x "$ROOT_DIR/tests/test-root-workshop-layout.sh"
test -x "$ROOT_DIR/ci/workshop-smoke.sh"
grep -Fq "bash ci/workshop-smoke.sh" "$ROOT_DIR/.github/workflows/workshop-smoke.yml"

checked_files=(
    "$ROOT_DIR/workshop-automated-installer.sh"
    "$ROOT_DIR/tests/test-workshop-automated-installer.sh"
    "$ROOT_DIR/ci/workshop-smoke.sh"
    "$ROOT_DIR/.github/workflows/workshop-smoke.yml"
    "$ROOT_DIR/.github/workflows/ci.yml"
    "$ROOT_DIR/README.md"
    "$ROOT_DIR/Makefile"
    "$ROOT_DIR/docs/tutorial.md"
    "$ROOT_DIR/CHANGELOG.md"
    "$ROOT_DIR/docs/development.md"
    "$ROOT_DIR/docs/release.md"
    "$ROOT_DIR/docs/superpowers/specs/2026-09-02-workshop-full-wrapper-design.md"
    "$ROOT_DIR/docs/superpowers/plans/2026-09-02-workshop-full-wrapper.md"
)
for file in "${checked_files[@]}"; do
    if grep -nE '(^|[^[:alnum:]_])uws/' "$file"; then
        echo "obsolete uws/ path reference found in ${file#"$ROOT_DIR"/}" >&2
        exit 1
    fi
done

echo 'root layout PASS'
