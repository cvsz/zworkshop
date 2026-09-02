# Changelog

All notable changes to projects created from this template should be documented here.

The format is based on Keep a Changelog and projects are encouraged to follow Semantic Versioning.

## [Unreleased]

### Added

- README status badges for CI, Workshop smoke, CodeQL, and the latest release.
- Complete four-part Ubuntu Workshop tutorial guide and definition-first
  fixtures for the Workshop, in-project SDK, and SDKcraft workflows.
- Explicit `sdkcraft-install` and `sdkcraft-refresh` wrapper commands plus
  project-directory routing for SDKcraft passthrough.
- Conservative tag-driven GitHub release workflow with generated notes,
  least-privilege publication, and no automatic artifact upload.

### Changed

- Added tutorial fixture validation to the Makefile, CI baseline, and
  non-mutating Workshop smoke workflow.
- Added the release workflow contract to local and hosted repository gates.

### Fixed

### Security

## [0.1.0] - 2026-09-02

### Added

- Repository template baseline
- Security and contribution policies
- GitHub issue and pull request templates
- CI, CodeQL, dependency review, and Dependabot automation
- Release documentation and project documentation structure
- Root-level Ubuntu Workshop installer with lifecycle, interface, SDK, sketch, diagnostics, completion, JSON, and dry-run support
- Fake-backend Workshop test harness, repository layout regression test, and non-mutating smoke workflow
- Project and GitHub documentation for Workshop architecture, security, contribution, release, ownership, and issue/PR workflows

### Changed

- Aligned Workshop examples and command routing with the current Ubuntu Workshop tutorial and moved all automation from the previous subdirectory into the repository root.
- Updated GitHub Actions to `actions/checkout@v7`, CodeQL Action `v4`, and dependency review Action `v5`.

### Fixed

### Security
