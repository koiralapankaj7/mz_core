# GitHub Workflows & Configuration - Complete Explanation

This document explains every file in the `.github` directory so developers can understand exactly what each file does and when they're used.

## 📂 Directory Structure

```dart
.github/
├── workflows/              # Automated workflows (CI/CD)
│   ├── ci.yml             # Main CI pipeline
│   ├── release.yml        # Release automation
│   ├── pr-checks.yml      # PR quality checks
│   └── stale.yml          # Stale issue/PR management
├── ISSUE_TEMPLATE/        # Issue templates
│   ├── bug_report.yml     # Bug report form
│   └── feature_request.yml # Feature request form
├── dependabot.yml         # Dependency updates
├── labeler.yml            # Auto-labeling rules
├── pull_request_template.md # PR template
├── SETUP.md               # Setup documentation
└── WORKFLOWS_EXPLAINED.md # This file
```

---

## 🔄 Workflows Directory

### 1. **`workflows/ci.yml`** - Main CI Pipeline

**When it runs:**

- Every push to `main` branch
- Every pull request to `main` branch

**What it does:**
This is your main quality gate. It runs 6 parallel jobs:

#### Job 1: **Analyze** (Code Quality)

```yaml
- Checkout code from repository
- Install Flutter 3.24.0
- Run `dart format --set-exit-if-changed`  # Fails if code isn't formatted
- Run `dart analyze --fatal-infos`         # Fails on any warnings
```

**Purpose**: Ensures all code is properly formatted and has no lint warnings.

#### Job 2: **Test** (Testing & Coverage)

```yaml
- Checkout code
- Install Flutter 3.24.0
- Run `flutter test`                       # Run all tests
- Run `flutter test --coverage`            # Generate coverage report
- Upload coverage to Codecov               # For coverage badge
```

**Purpose**: Runs all 475+ tests and tracks code coverage over time.

#### Job 3: **Pana** (Package Quality)

```yaml
- Install pana tool (pub.dev's scoring tool)
- Run `pana --no-warning`                  # Check package quality
```

**Purpose**: Checks if your package meets pub.dev quality standards (gives you a score out of 140).

#### Job 4: **Dependency Review** (PR only)

```yaml
- Reviews dependencies changed in PR
- Warns about known vulnerabilities
```

**Purpose**: Security - alerts if a PR introduces a vulnerable dependency.

#### Job 5: **Security** (Trivy Scanner)

```yaml
- Scan filesystem for vulnerabilities
- Upload results to GitHub Security tab
```

**Purpose**: Finds security issues in dependencies and code.

**Why you need this:**
This prevents broken code from reaching `main`. If any job fails, the PR can't be merged.

---

### 2. **`workflows/release.yml`** - Release Automation

**When it runs:**

- When you push a git tag matching `v*.*.*` (e.g., `v0.0.1`, `v1.2.3`)

**What it does:**

#### Job 1: **Create Release**

```yaml
1. Extract version from tag (v0.0.1 → 0.0.1)
2. Extract changelog from CHANGELOG.md for this version
3. Create GitHub Release with:
   - Version number as title
   - Changelog as release notes
   - Tag attached to release
```

#### Job 2: **Publish to pub.dev**

```yaml
1. Run `flutter pub publish --dry-run`  # Verify package is publishable
2. (Optional) Auto-publish to pub.dev  # Currently commented out
```

**Example workflow:**

```bash
# You do this:
git tag v0.0.2
git push origin v0.0.2

# GitHub automatically:
1. Runs all tests
2. Creates GitHub Release
3. Extracts v0.0.2 changelog
4. (Optional) Publishes to pub.dev
```

**Why you need this:**
Automates the entire release process. One command creates a professional release.

---

### 3. **`workflows/pr-checks.yml`** - PR Quality Checks

**When it runs:**

- When a PR is opened, updated, or reopened

**What it does:**

#### Job 1: **Changelog Check**

```yaml
- Check if CHANGELOG.md was modified
- Warn if not (doesn't fail the build)
```

**Purpose**: Reminds contributors to update the changelog.

#### Job 2: **PR Labeler**

```yaml
- Read .github/labeler.yml rules
- Auto-apply labels based on changed files
```

**Example**: If you modify `lib/src/logger.dart`, it automatically adds the `logger` label.

#### Job 3: **PR Size Check**

```yaml
- Count lines changed (insertions + deletions)
- Warn if > 500 lines
```

**Purpose**: Encourages smaller, focused PRs that are easier to review.

#### Job 4: **Commit Message Linting**

```yaml
- Check all commit messages follow Conventional Commits
- Expected format: "type(scope): description"
  - feat: add new feature
  - fix: resolve bug
  - docs: update documentation
```

**Purpose**: Maintains clean git history that can auto-generate changelogs.

**Why you need this:**
Keeps PRs organized and maintains project standards without manual review.

---

### 4. **`workflows/stale.yml`** - Stale Issue Management

**When it runs:**

- Daily at midnight UTC
- Can also trigger manually

**What it does:**

```yaml
Issues:
  - After 60 days of inactivity → Add "stale" label + comment
  - After 7 more days → Auto-close

PRs:
  - After 30 days of inactivity → Add "stale" label + comment
  - After 14 more days → Auto-close

Exemptions:
  - Issues/PRs with labels: pinned, security, help-wanted, good-first-issue
```

**Example timeline:**

```dart
Day 0:  Issue created
Day 60: Bot adds "stale" label and comment
Day 65: Someone comments → "stale" label removed, timer resets
Day 125: No activity for 60 more days → "stale" label added again
Day 132: No activity for 7 days → Issue auto-closed
```

**Why you need this:**
Keeps your issue tracker clean without manually closing old issues.

---

## 📋 Configuration Files

### 5. **`labeler.yml`** - Auto-Labeling Rules

**What it does:**
Defines rules for automatically applying labels to PRs.

**File-based labels:**

```yaml
'documentation':
  - changed-files:
    - any-glob-to-any-file:
      - 'README.md'
      - 'doc/**/*'
      - '**/*.md'
```

**Meaning**: If a PR changes any `.md` file, add the `documentation` label.

**Branch-based labels:**

```yaml
'bug':
  - head-branch: ['^fix', '^bugfix', 'bug']
```

**Meaning**: If PR branch starts with `fix`, `bugfix`, or `bug`, add the `bug` label.

**All defined labels:**

- `documentation` - Any markdown files
- `dependencies` - `pubspec.yaml` changes
- `tests` - Test files
- `example` - Example app
- `controller` - Controller-related files
- `logger` - Logger-related files
- `extensions` - Extension files
- `ci/cd` - GitHub Actions changes
- `breaking-change` - Breaking changes (branch name)
- `enhancement` - New features (branch name)
- `bug` - Bug fixes (branch name)
- `refactor` - Refactoring (branch name)

**Why you need this:**
Saves time organizing PRs. Labels appear automatically based on what changed.

---

### 6. **`dependabot.yml`** - Dependency Updates

**What it does:**
Configures Dependabot to automatically check for dependency updates.

#### Configuration 1: Main Package**

```yaml
- package-ecosystem: "pub"        # Dart/Flutter packages
  directory: "/"                  # Root pubspec.yaml
  schedule:
    interval: "weekly"            # Check every week
    day: "monday"                 # On Mondays
  open-pull-requests-limit: 5     # Max 5 PRs at once
  labels: ["dependencies", "automated"]
```

#### Configuration 2: Example App**

```yaml
- package-ecosystem: "pub"
  directory: "/example"           # Example's pubspec.yaml
  schedule:
    interval: "weekly"
  open-pull-requests-limit: 3
  labels: ["dependencies", "example", "automated"]
```

#### Configuration 3: GitHub Actions

```yaml
- package-ecosystem: "github-actions"
  directory: "/"                  # Workflow files
  schedule:
    interval: "weekly"
  labels: ["ci/cd", "dependencies", "automated"]
```

**What happens every Monday:**

1. Dependabot checks for updates to:
   - Your pub dependencies (mz_utils)
   - Example app dependencies
   - GitHub Actions versions (e.g., `actions/checkout@v4` → `@v5`)

2. Creates PRs like:
   - "chore(deps): bump very_good_analysis from 10.0.0 to 10.1.0"
   - "chore(deps): bump actions/checkout from v4 to v5"

3. You review and merge (or auto-merge if you trust it)

**Why you need this:**
Keeps dependencies up-to-date automatically. Reduces security vulnerabilities.

---

## 📝 Issue Templates

### 7. **`ISSUE_TEMPLATE/bug_report.yml`** - Bug Report Form

**What it does:**
Creates a structured form when users click "New Issue" → "Bug Report"

**Fields required:**

```yaml
1. Description (text area) - What's the bug?
2. Steps to Reproduce (text area) - How to trigger it?
3. Expected Behavior - What should happen?
4. Actual Behavior - What actually happens?
5. Minimal Code Sample (code block) - Reproducible example
6. mz_utils Version (text input) - Which version?
7. Flutter Version (text input) - Flutter version
8. Dart Version (text input) - Dart version
9. Platform (dropdown, multi-select) - Android/iOS/Web/etc.
10. Logs and Stack Traces (code block) - Error messages
11. Additional Context (optional text area)
12. Checklist:
    - Searched existing issues
    - Provided minimal code sample
    - Using latest version
```

**Why you need this:**
Forces users to provide all information needed to debug. Saves back-and-forth asking for details.

**Example:**

- Without template: "Logger doesn't work"
- With template: Complete bug report with code, versions, error logs

---

### 8. **`ISSUE_TEMPLATE/feature_request.yml`** - Feature Request Form

**What it does:**
Structured form for suggesting new features.

**Fields required:**

```yaml
1. Problem Statement - What problem does this solve?
2. Proposed Solution - How should it work?
3. Proposed API (optional code block) - Show example API
4. Alternatives Considered - What else did you think of?
5. Use Cases - When would this be used?
6. Breaking Change (dropdown) - Yes/No/Unsure
7. Additional Context (optional)
8. Checklist:
    - Searched existing issues
    - Willing to submit PR
```

**Why you need this:**
Ensures feature requests are well-thought-out and include use cases.

---

## 📄 Templates

### 9. **`pull_request_template.md`** - PR Template

**What it does:**
Pre-fills the PR description when someone creates a pull request.

**Sections:**

```markdown
## Description
[What changed?]

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Refactoring
- [ ] Performance
- [ ] Test improvement

## Related Issue
Fixes #123

## Changes Made
- Item 1
- Item 2

## Testing
- [ ] All tests pass
- [ ] New tests added
- [ ] Manual testing done

## Checklist
- [ ] Follows Effective Dart
- [ ] Self-reviewed code
- [ ] Added comments
- [ ] Updated documentation
- [ ] No new warnings
- [ ] Tests pass
- [ ] Code formatted
- [ ] Updated CHANGELOG.md
- [ ] Updated version (if applicable)

## Screenshots (if applicable)

## Breaking Changes

## Additional Notes
```

**Why you need this:**
Ensures every PR has:

- Clear description
- Tests
- Documentation
- Proper formatting
- Updated changelog

**Example:**

- Without template: PR description: "Fixed bug"
- With template: Complete description with checklist, testing info, etc.

---

## 📚 Documentation

### 10. **`SETUP.md`** - Setup Documentation

**What it does:**
Comprehensive guide explaining:

- All workflows and when they run
- How to set up Codecov
- How to create releases
- Required secrets
- Best practices
- Troubleshooting

**Why you need this:**
Reference documentation for you and contributors on how the CI/CD works.

---

## 🎯 Summary by Category

### **Automation (Workflows)**

- `ci.yml` → Quality checks on every push/PR
- `release.yml` → Auto-release on git tags
- `pr-checks.yml` → PR quality and organization
- `stale.yml` → Clean up old issues/PRs

### **Configuration**

- `labeler.yml` → Auto-label PRs
- `dependabot.yml` → Auto-update dependencies

### **Templates**

- `bug_report.yml` → Structured bug reports
- `feature_request.yml` → Structured feature requests
- `pull_request_template.md` → PR checklist

### **Documentation**

- `SETUP.md` → How everything works
- `WORKFLOWS_EXPLAINED.md` → Detailed explanation (this file)

---

## 💡 Real-World Example Scenarios

### Scenario 1: You Push Code to Main

```bash
git push origin main
```

**What happens:**

1. `ci.yml` triggers automatically
2. Runs 6 parallel jobs:
   - ✅ Formats all code
   - ✅ Runs static analysis
   - ✅ Runs 475 tests
   - ✅ Generates coverage
   - ✅ Checks package quality
   - ✅ Builds example app
   - ✅ Scans for security issues
3. If all pass → Green checkmark ✅
4. If any fail → Red X ❌, build fails
5. Coverage report uploads to Codecov
6. Badge in README updates automatically

### Scenario 2: You Create a Release

```bash
git tag v0.0.2
git push origin v0.0.2
```

**What happens:**

1. `release.yml` triggers
2. Runs all tests again
3. Extracts v0.0.2 section from CHANGELOG.md
4. Creates GitHub Release with that changelog
5. Release appears on GitHub with download links
6. (Optional) Auto-publishes to pub.dev

### Scenario 3: Someone Opens a Pull Request

**What happens:**

1. `ci.yml` runs all quality checks
2. `pr-checks.yml` runs additional checks:
   - Checks if CHANGELOG.md updated
   - Auto-applies labels based on changed files
   - Warns if PR is too large (>500 lines)
   - Validates commit message format
3. `dependency-review` checks for vulnerable deps
4. All results show up in PR checks section

### Scenario 4: It's Monday Morning

**What happens (automatically):**

1. Dependabot wakes up
2. Checks for updates to:
   - pub dependencies
   - Example app dependencies
   - GitHub Actions versions
3. Creates PRs for any updates found
4. You review and merge (or auto-merge)

### Scenario 5: An Issue is 60 Days Old

**What happens:**

1. Stale bot checks the issue
2. Sees no activity for 60 days
3. Adds "stale" label
4. Posts a comment explaining it will close in 7 days
5. If no response in 7 days → auto-closes
6. If someone comments → removes "stale" label, timer resets

---

## 🔧 How to Modify Workflows

### Change CI Checks

**File**: `.github/workflows/ci.yml`

Want to add a new check? Add a new job:

```yaml
new-check:
  name: My Custom Check
  runs-on: ubuntu-latest
  steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Run my custom script
      run: ./scripts/my-check.sh
```

### Change Stale Timeframes

**File**: `.github/workflows/stale.yml`

```yaml
days-before-issue-stale: 60    # Change to 30 for faster cleanup
days-before-issue-close: 7     # Change to 14 for longer grace period
```

### Add New Auto-Labels

**File**: `.github/labeler.yml`

```yaml
'my-new-label':
  - changed-files:
    - any-glob-to-any-file:
      - 'lib/src/my-feature/**/*'
```

### Change Dependabot Schedule

**File**: `.github/dependabot.yml`

```yaml
schedule:
  interval: "daily"    # Instead of "weekly"
  time: "09:00"        # Specific time
```

---

## ⚠️ Important Notes

### Required Secrets

Some workflows need secrets to be configured in GitHub:

1. **CODECOV_TOKEN** (optional but recommended)
   - Get from <https://codecov.io>
   - Add in GitHub → Settings → Secrets and variables → Actions
   - Used by: `ci.yml` (Test job)

2. **PUB_CREDENTIALS** (optional, for auto-publish)
   - Get from `~/.pub-cache/credentials.json` after running `flutter pub publish` once
   - Add in GitHub → Settings → Secrets and variables → Actions
   - Used by: `release.yml` (Publish job)

### Workflow Permissions

Some workflows need write permissions:

- `release.yml` needs `contents: write` to create releases
- `stale.yml` needs `issues: write` and `pull-requests: write`
- `pr-checks.yml` needs `pull-requests: write` for labeling

These are already configured in the workflow files.

---

## 🐛 Troubleshooting

### Workflow Not Running

**Problem**: Pushed code but no workflow ran

**Solutions**:

1. Check workflow file syntax (invalid YAML won't run)
2. Ensure workflow is in `.github/workflows/` directory
3. Check trigger conditions match your action (branch name, etc.)
4. Look at Actions tab → select workflow → check for errors

### Coverage Not Uploading

**Problem**: Tests pass but coverage doesn't upload

**Solutions**:

1. Verify `CODECOV_TOKEN` is set correctly in GitHub secrets
2. Check coverage file exists: `coverage/lcov.info`
3. Review Codecov action logs in workflow run
4. Ensure repository is added to Codecov account

### Auto-Labeling Not Working

**Problem**: PRs don't get auto-labeled

**Solutions**:

1. Check `.github/labeler.yml` syntax
2. Verify file paths match the glob patterns
3. Ensure `actions/labeler@v5` has permissions
4. Check workflow logs for errors

### Dependabot Not Creating PRs

**Problem**: It's Monday but no Dependabot PRs

**Solutions**:

1. Check if Dependabot is enabled in repository settings
2. Verify `.github/dependabot.yml` syntax
3. Check if dependencies are already up-to-date
4. Look at Security → Dependabot → check logs

---

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Codecov Documentation](https://docs.codecov.com/)
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [pub.dev Publishing Guide](https://dart.dev/tools/pub/publishing)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)

---

## 🤝 Contributing

When contributing to this project, please ensure:

1. **Follow workflow checks**: All CI checks must pass
2. **Update CHANGELOG.md**: For significant changes
3. **Follow commit conventions**: Use Conventional Commits format
4. **Keep PRs focused**: Under 500 lines when possible
5. **Fill out templates**: Use issue and PR templates completely
6. **Add tests**: New features need tests
7. **Update docs**: Document public APIs

---

## 📞 Questions?

If you have questions about any workflow:

1. Read the specific workflow file (they're commented)
2. Check this explanation document
3. Review the workflow run logs in GitHub Actions tab
4. Create an issue with the `question` label
5. Check GitHub Discussions

---

**Last Updated**: 2025-01-05

**Maintained By**: Pankaj Koirala (@koiralapankaj7)
