# Release Checklist

This document outlines all steps required before releasing a new version of mz_core or mz_lints.

## Pre-Release Checklist

### 1. Version Updates

#### mz_core

Update version in the following files:

| File | Location |
| ---- | -------- |
| `pubspec.yaml` | `version:` field |
| `CHANGELOG.md` | Add new version section at top |
| `README.md` | `mz_core: ^x.x.x` in Installation section |
| `doc/getting_started.md` | `mz_core: ^x.x.x` in Installation section |

#### mz_lints

Update version in the following files:

| File | Location |
| ---- | -------- |
| `packages/mz_lints/pubspec.yaml` | `version:` field |
| `packages/mz_lints/CHANGELOG.md` | Add new version section at top |
| `packages/mz_lints/README.md` | `mz_lints: ^x.x.x` (2 occurrences: dev_dependencies and plugins sections) |
| `packages/mz_lints/example/lib/main.dart` | `mz_lints: ^x.x.x` in doc comment |

### 2. Update Documentation

Update documentation files to reflect new features and changes:

#### For New Features

| File | What to Update |
| ---- | -------------- |
| `doc/core_concepts.md` | Add new section explaining the feature concept, API, and usage patterns |
| `doc/getting_started.md` | Add quick start examples for the new feature |
| `doc/troubleshooting.md` | Add common issues and solutions for the new feature |
| `README.md` | Update Features table if adding major functionality |

#### Documentation Checklist

- [ ] Add feature to Table of Contents in each doc file
- [ ] Include code examples with comments
- [ ] Document common pitfalls and solutions
- [ ] Add to "Known Limitations" section if applicable
- [ ] Update "Tips" section with best practices

#### Example: Adding a New Feature Section

```markdown
## Feature Name

### Concept

Brief description of what the feature does and why it exists.

### Basic Usage

\`\`\`dart
// Code example
\`\`\`

### Advanced Usage

Additional examples for complex scenarios.

### When to Use

| Use Case | Example |
| -------- | ------- |
| **Case 1** | Description |
| **Case 2** | Description |
```

### 3. Update CHANGELOG

Follow [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format:

```markdown
## [x.x.x] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes to existing functionality

### Deprecated
- Features to be removed in future

### Removed
- Removed features

### Fixed
- Bug fixes

### Improved
- Performance or quality improvements
```

Add version link at bottom of CHANGELOG:

```markdown
[x.x.x]: https://github.com/koiralapankaj7/mz_core/releases/tag/vx.x.x
```

### 4. Run Tests

```bash
# mz_core tests
flutter test

# mz_lints tests
cd packages/mz_lints && dart test
```

Ensure all tests pass before proceeding.

### 5. Verify Analysis

```bash
# Check for analysis issues
dart analyze --fatal-infos

# For mz_lints
cd packages/mz_lints && dart analyze --fatal-infos
```

### 6. Run CI Locally

Run GitHub Actions workflows locally using [act](https://github.com/nektos/act) to verify CI will pass before pushing:

```bash
# Run mz_core CI
act -W .github/workflows/ci.yml -j analyze --container-architecture linux/amd64

# Run mz_lints CI
act -W .github/workflows/mz_lints_ci.yml -j analyze -j test --container-architecture linux/amd64
```

Fix any failures before proceeding. Post-step cache failures (e.g., "node not found") can be ignored.

### 7. Create Commit

```bash
git add .
git commit -m "chore: release mz_core vX.X.X and mz_lints vX.X.X"
```

Or if only releasing one package:

```bash
git commit -m "chore: release mz_core vX.X.X"
git commit -m "chore: release mz_lints vX.X.X"
```

### 8. Create Git Tags

```bash
# For mz_core
git tag -a vX.X.X -m "mz_core vX.X.X"

# For mz_lints
git tag -a mz_lints-vX.X.X -m "mz_lints vX.X.X"
```

### 9. Push Changes

```bash
git push origin dev
git push origin --tags
```

### 10. Publish to pub.dev

```bash
# Dry run first
dart pub publish --dry-run

# Publish mz_core
dart pub publish

# Publish mz_lints
cd packages/mz_lints && dart pub publish
```

## Version Numbering

Follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html):

- **MAJOR** (x.0.0): Breaking API changes
- **MINOR** (0.x.0): New features, backward compatible
- **PATCH** (0.0.x): Bug fixes, backward compatible

## Quick Search Commands

Find all version references:

```bash
# mz_core version references
grep -rn "mz_core:" --include="*.yaml" --include="*.md"

# mz_lints version references
grep -rn "mz_lints:" --include="*.yaml" --include="*.md" --include="*.dart"
```
