# GitHub Actions & CI/CD Setup

This document describes the GitHub Actions workflows and community standards configured for the mz_utils package.

## 🎯 Overview

The repository includes comprehensive CI/CD automation with:

- ✅ Continuous Integration (CI) on every push and PR
- ✅ Automated testing with coverage reporting
- ✅ Code quality checks (formatting, analysis, security)
- ✅ Automated releases
- ✅ Dependency management
- ✅ Community standards (issue templates, PR templates)

## 📋 Workflows

### 1. CI Workflow (`.github/workflows/ci.yml`)

**Triggers**: Push to `main` branch, Pull Requests

**Jobs**:

#### Analyze

- Checkout code
- Setup Flutter (v3.24.0)
- Install dependencies
- **Verify code formatting** (`dart format`)
- **Analyze code** (`dart analyze --fatal-infos`)

#### Test

- Run all tests (`flutter test`)
- **Generate coverage report** (`flutter test --coverage`)
- **Upload coverage to Codecov** (requires `CODECOV_TOKEN` secret)

#### Pana (Package Analysis)

- Run pub.dev scoring tool
- Ensures package meets pub.dev standards

#### Build Example

- Builds the example Android app
- Verifies example app compiles successfully

#### Dependency Review (PR only)

- Reviews dependency changes in PRs
- Alerts on vulnerable dependencies

#### Security

- **Trivy vulnerability scanner** for security issues
- Uploads results to GitHub Security tab

---

### 2. Release Workflow (`.github/workflows/release.yml`)

**Triggers**: Tag push matching `v*.*.*` (e.g., `v0.0.1`)

**Jobs**:

#### Create Release

- Extracts version from git tag
- Extracts changelog from CHANGELOG.md
- Creates GitHub Release with changelog

#### Publish (Manual)

- Runs `flutter pub publish --dry-run`
- Auto-publish is commented out (enable when ready)
- Requires `PUB_CREDENTIALS` secret for auto-publish

**Usage**:

```bash
git tag v0.0.2
git push origin v0.0.2
```

---

### 3. PR Checks Workflow (`.github/workflows/pr-checks.yml`)

**Triggers**: Pull Request opened/updated

**Jobs**:

#### Changelog Check

- Warns if CHANGELOG.md not updated (non-blocking)

#### PR Labeler

- Automatically labels PRs based on changed files
- Uses `.github/labeler.yml` configuration

#### PR Size Check

- Warns if PR changes >500 lines
- Encourages smaller, focused PRs

#### Commit Message Linting

- Validates commit messages follow Conventional Commits
- Format: `type(scope): description`

---

### 4. Stale Issues/PRs Workflow (`.github/workflows/stale.yml`)

**Triggers**: Daily at midnight, manual trigger

**Configuration**:

- **Issues**: Marked stale after 60 days, closed after 7 days
- **PRs**: Marked stale after 30 days, closed after 14 days
- **Exempt labels**: `pinned`, `security`, `help-wanted`

---

## 🏷️ Auto-Labeling (`.github/labeler.yml`)

Automatically applies labels based on changed files:

| Label | Triggered by |
| ------- | ------------- |
| `documentation` | `README.md`, `doc/**`, `*.md` |
| `dependencies` | `pubspec.yaml` |
| `tests` | `test/**`, `*_test.dart` |
| `example` | `example/**` |
| `controller` | `**/controller*.dart` |
| `logger` | `**/logger*.dart` |
| `ci/cd` | `.github/**` |

Branch-based labels:

- `breaking-change`: Branch starts with `breaking` or `major`
- `enhancement`: Branch starts with `feat`, `feature`
- `bug`: Branch starts with `fix`, `bugfix`

---

## 🔄 Dependabot (`.github/dependabot.yml`)

Automated dependency updates:

### Pub Dependencies

- **Schedule**: Weekly (Monday)
- **Scope**: Main package and example app
- **PR limit**: 5 per run
- **Labels**: `dependencies`, `automated`

### GitHub Actions

- **Schedule**: Weekly (Monday)
- **Updates**: Action versions
- **Labels**: `ci/cd`, `dependencies`

---

## 📝 Issue Templates

### Bug Report (`.github/ISSUE_TEMPLATE/bug_report.yml`)

Structured template requiring:

- Description and reproduction steps
- Expected vs actual behavior
- Minimal code sample
- Version information (mz_utils, Flutter, Dart)
- Platform information
- Logs/stack traces

### Feature Request (`.github/ISSUE_TEMPLATE/feature_request.yml`)

Template for feature suggestions:

- Problem statement
- Proposed solution and API
- Use cases
- Breaking change indicator
- Alternatives considered

---

## 🔀 Pull Request Template (`.github/pull_request_template.md`)

Comprehensive PR template with:

- Description and type of change
- Related issue linking
- Testing checklist
- Code quality checklist (formatting, analysis, tests)
- Breaking change documentation

---

## 🔐 Required Secrets

Configure these in GitHub Settings → Secrets and variables → Actions:

### For Coverage (Optional)

- `CODECOV_TOKEN`: Token from [codecov.io](https://codecov.io)
  - Sign up at codecov.io
  - Add repository
  - Copy token to GitHub secrets

### For Auto-Publish (Optional)

- `PUB_CREDENTIALS`: pub.dev credentials
  - Run `flutter pub publish` locally once
  - Copy credentials from `~/.pub-cache/credentials.json`
  - Add to GitHub secrets as JSON

---

## 🎨 Badges in README

The following badges are now active:

```markdown
[![pub package](https://img.shields.io/pub/v/mz_utils.svg)](https://pub.dev/packages/mz_utils)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![codecov](https://codecov.io/gh/koiralapankaj7/mz_utils/branch/main/graph/badge.svg)](https://codecov.io/gh/koiralapankaj7/mz_utils)
[![CI](https://github.com/koiralapankaj7/mz_utils/workflows/CI/badge.svg)](https://github.com/koiralapankaj7/mz_utils/actions)
```

---

## 🚀 Getting Started

### 1. Enable Workflows

Push your code to enable workflows:

```bash
git add .github
git commit -m "ci: add GitHub Actions workflows"
git push origin main
```

### 2. Set Up Codecov (Optional)

1. Visit [codecov.io](https://codecov.io)
2. Sign in with GitHub
3. Add `koiralapankaj7/mz_utils` repository
4. Copy the upload token
5. Add as `CODECOV_TOKEN` secret in GitHub

### 3. Create First Release

```bash
# Commit your changes
git add .
git commit -m "chore: prepare for release"
git push

# Create and push tag
git tag v0.0.1
git push origin v0.0.1
```

The release workflow will automatically:

- Run all tests
- Extract changelog
- Create GitHub release

### 4. Enable Auto-Publish (Optional)

To enable automatic publishing to pub.dev on release:

1. Uncomment lines in `.github/workflows/release.yml`:

   ```yaml
   - name: Publish package
     run: flutter pub publish --force
     env:
       PUB_CREDENTIALS: ${{ secrets.PUB_CREDENTIALS }}
   ```

2. Add `PUB_CREDENTIALS` secret to GitHub

---

## 📊 Monitoring

### CI Dashboard

View all workflow runs:

- GitHub → Actions tab
- See test results, coverage, security scans

### Security Alerts

- GitHub → Security tab
- View Dependabot alerts
- Review Trivy scan results

### Code Coverage

- Visit codecov.io dashboard
- View coverage trends
- Identify untested code

---

## 🔧 Maintenance

### Weekly Tasks (Automated)

- Dependabot creates PRs for updates
- Stale bot marks inactive issues/PRs

### On Each PR

- CI runs automatically
- Coverage report generated
- PR labeled automatically
- Size check performed

### On Release

- Tag triggers release workflow
- GitHub release created
- Can auto-publish to pub.dev

---

## 📖 Best Practices

1. **Commit Messages**: Follow Conventional Commits
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation
   - `test:` for tests
   - `refactor:` for refactoring
   - `chore:` for maintenance

2. **Branch Naming**:
   - `feat/feature-name` for features
   - `fix/bug-name` for bug fixes
   - `docs/doc-name` for documentation

3. **PRs**:
   - Keep PRs focused and small (<500 lines)
   - Update CHANGELOG.md for significant changes
   - Fill out PR template completely
   - Ensure all CI checks pass

4. **Releases**:
   - Update version in `pubspec.yaml`
   - Update `CHANGELOG.md`
   - Create git tag matching version
   - Follow semantic versioning

---

## ❓ Troubleshooting

### Workflow Not Running

- Check workflow file syntax (YAML)
- Ensure workflow is in `.github/workflows/`
- Check trigger conditions match your action

### Coverage Not Uploading

- Verify `CODECOV_TOKEN` is set correctly
- Check coverage file is generated: `coverage/lcov.info`
- Review Codecov action logs

### Auto-Publish Failing

- Verify `PUB_CREDENTIALS` format is correct JSON
- Ensure package passes `flutter pub publish --dry-run`
- Check pub.dev for package name conflicts

---

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Codecov Documentation](https://docs.codecov.com/)
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [pub.dev Publishing Guide](https://dart.dev/tools/pub/publishing)
