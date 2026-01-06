# GitHub Rulesets Setup

This guide shows how to protect branches using **GitHub Rulesets** - the modern, file-based approach to branch protection.

## What are Rulesets?

**GitHub Rulesets** are the newer way to protect branches and tags. Unlike classic branch protection rules, rulesets:

- ✅ **File-based configuration** - Can be version controlled
- ✅ **More flexible** - Target multiple branches with patterns
- ✅ **Better organization** - Centralized in `.github/rulesets/`
- ✅ **Easier management** - Import/export via API
- ✅ **Future-proof** - GitHub's recommended approach

**Rulesets vs Branch Protection Rules:**

| Feature | Rulesets | Branch Protection |
|---------|----------|-------------------|
| File-based config | ✅ Yes | ❌ No (UI/API only) |
| Multiple branches | ✅ Yes (patterns) | ⚠️ Limited |
| Version control | ✅ Yes | ❌ No |
| Tag protection | ✅ Yes | ❌ No |
| GitHub recommendation | ✅ Modern | ⚠️ Legacy |

---

## Why Rulesets? (For Developers)

### The Problem

You want to protect your `main` branch from accidental direct pushes and ensure all changes go through Pull Requests with CI checks. Traditionally, you'd configure this through GitHub's web UI, but that has downsides:

- ❌ Settings aren't version controlled
- ❌ Hard to replicate across repositories
- ❌ No audit trail of protection changes
- ❌ Can't review protection changes in PRs

### The Solution: File-Based Configuration

**GitHub Rulesets** let you define protection rules in a **JSON file** (`.github/rulesets/main-protection.json`) that lives in your repository:

```json
{
  "name": "Protect main branch",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"]
    }
  },
  "rules": [
    {"type": "pull_request"},
    {"type": "required_status_checks"},
    {"type": "deletion"},
    {"type": "non_fast_forward"}
  ]
}
```

This file is:
- ✅ **Version controlled** - Track changes in git history
- ✅ **Portable** - Copy to other projects easily
- ✅ **Reviewable** - Changes go through PRs like any code
- ✅ **Auditable** - See who changed what and when

### How It Works

#### 1. Define Rules in JSON File

The file `.github/rulesets/main-protection.json` contains all protection rules.

#### 2. Apply via GitHub CLI

```bash
./.github/setup-rulesets.sh
```

This script sends your JSON configuration to GitHub's API, which then **enforces** these rules.

#### 3. GitHub Enforces Rules

Once applied, GitHub automatically enforces all rules:

**Without Rulesets** (Before):
```bash
git checkout main
git commit -m "quick fix"
git push origin main  # ✅ Works - no protection
```

**With Rulesets** (After):
```bash
git checkout main
git commit -m "quick fix"
git push origin main  # ❌ BLOCKED by GitHub!

# Error message:
# ! [remote rejected] main -> main (protected by ruleset)
```

**Correct Workflow**:
```bash
# Must create a feature branch
git checkout -b fix/quick-fix
git commit -m "quick fix"
git push origin fix/quick-fix

# Then create PR on GitHub
# Wait for CI checks (Analyze, Test, Package Analysis, Build Example)
# Merge through GitHub UI only
```

### What Our Ruleset Protects

The `main-protection.json` ruleset enforces:

1. **Pull Request Required** (`"type": "pull_request"`)
   - Nobody can push directly to main
   - All changes must go through a PR
   - Even repository owners must follow this

2. **CI Checks Required** (`"type": "required_status_checks"`)
   - PRs blocked until all checks pass:
     - ✅ `Analyze` - Code formatting and analysis
     - ✅ `Test` - Test suite with coverage
     - ✅ `Package Analysis` - pub.dev quality scoring
     - ✅ `Build Example App` - Example app compilation

3. **No Force Pushes** (`"type": "non_fast_forward"`)
   - Prevents `git push --force`
   - Protects git history from being rewritten

4. **No Branch Deletion** (`"type": "deletion"`)
   - Prevents accidental deletion of main branch

5. **Linear History** (`"type": "required_linear_history"`)
   - Keeps history clean (no merge commits)
   - Enforces squash or rebase merges

6. **Conversation Resolution** (`"required_review_thread_resolution": true`)
   - All PR comments must be resolved before merge
   - Ensures discussions are addressed

### Benefits for This Project

1. **Quality Assurance**: Every change must pass CI (format, analyze, test, build)
2. **Code Review**: Creating PRs forces you to review your own changes
3. **Safety**: Can't accidentally break main with force push or direct commits
4. **Transparency**: All changes visible in PR history
5. **Stable Main**: Main branch is always in a releasable state
6. **Tag-Based Releases**: Use tags (v0.0.1, v0.1.0) to mark releases

### Example Scenario

**Developer makes a change:**

```bash
# 1. Create feature branch
git checkout -b feat/add-new-utility

# 2. Make changes
echo "new code" >> lib/src/new_utility.dart
git add .
git commit -m "feat: add new utility function"

# 3. Push to remote
git push origin feat/add-new-utility

# 4. Create PR on GitHub
# GitHub automatically runs CI:
#   - Analyze ✅ (dart analyze passes)
#   - Test ✅ (475+ tests pass)
#   - Package Analysis ✅ (pana score good)
#   - Build Example ✅ (example app builds)

# 5. All checks pass → Merge button enabled
# 6. Merge PR (squash and merge)
# 7. GitHub automatically deletes feature branch
```

**Main branch is protected throughout this process** - no way to bypass the rules.

---

## How to Apply the Ruleset

GitHub provides **two ways** to apply the ruleset configuration from `.github/rulesets/main-protection.json`:

### Option 1: Import via GitHub UI (Recommended)

This is the **official GitHub approach**:

1. **Go to Repository Rulesets**

   Visit: <https://github.com/koiralapankaj7/mz_utils/settings/rules>

2. **Click "New ruleset" → "Import a ruleset"**

3. **Upload the JSON file**
   - Select `.github/rulesets/main-protection.json` from your local repo
   - Or copy/paste the JSON content directly

4. **Click "Create"**

That's it! GitHub will enforce the ruleset immediately.

### Option 2: Automated Setup via CLI (Optional Helper)

For convenience, we provide a script to automate the setup using GitHub CLI:

```bash
# Prerequisites: gh CLI installed and authenticated with your personal account
gh auth login

# Run the automation script
./.github/setup-rulesets.sh
```

**Note**: This is an **optional automation helper**, not required by GitHub. The script does the same thing as Option 1 but via the API instead of the UI.

---

## What Gets Protected

The ruleset in `.github/rulesets/main-protection.json` protects the `main` branch with:

### Pull Request Requirements

- ✅ **Require pull request before merging**
- ✅ **Required approvals**: 0 (for solo projects)
- ✅ **Dismiss stale reviews when new commits are pushed**
- ✅ **Require conversation resolution before merging**

### Status Check Requirements

- ✅ **Require status checks to pass before merging**
- ✅ **Require branches to be up to date before merging**
- ✅ **Required checks**:
  - `Analyze` (code formatting and analysis)
  - `Test` (test suite with coverage)
  - `Package Analysis` (pub.dev scoring)
  - `Build Example App` (example app compilation)

### Additional Protections

- ✅ **Prevent branch deletion**
- ✅ **Prevent force pushes** (non-fast-forward)
- ✅ **Require linear history** (no merge commits)

---

## Alternative: Manual Setup via GitHub UI

If you prefer to configure the ruleset from scratch instead of importing the JSON file:

1. **Go to Repository Rulesets**

   Visit: <https://github.com/koiralapankaj7/mz_utils/settings/rules>

2. **Click "New ruleset" → "New branch ruleset"**

3. **Configure the ruleset**:

   ```text
   Ruleset name: Protect main branch
   Enforcement status: Active

   Target branches:
     ✓ Include: main

   Branch protections:
     ✓ Restrict deletions
     ✓ Require a pull request before merging
       - Required approvals: 0
       - Dismiss stale pull request approvals: Yes
       - Require conversation resolution: Yes
     ✓ Require status checks to pass
       - Require branches to be up to date: Yes
       - Status checks: Analyze, Test, Package Analysis, Build Example App
     ✓ Block force pushes
     ✓ Require linear history
   ```

4. **Click "Create"**

---

## Customizing the Ruleset

You can modify `.github/rulesets/main-protection.json` to customize protection rules:

### Require Code Review

Change `required_approving_review_count` to require approvals:

```json
{
  "type": "pull_request",
  "parameters": {
    "required_approving_review_count": 1  // Require 1 approval
  }
}
```

### Add More Status Checks

Add additional required checks:

```json
{
  "type": "required_status_checks",
  "parameters": {
    "required_status_checks": [
      {"context": "Analyze"},
      {"context": "Test"},
      {"context": "Package Analysis"},
      {"context": "Build Example App"},
      {"context": "Security Scan"}  // Add new check
    ]
  }
}
```

### Allow Admin Bypass

Add bypass actors to allow admins to override:

```json
{
  "bypass_actors": [
    {
      "actor_id": 1,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ]
}
```

**After modifying the JSON file**, you need to re-apply the ruleset:
- **Via GitHub UI**: Delete the old ruleset and import the updated JSON file
- **Via CLI script** (optional): Re-run `./.github/setup-rulesets.sh` after deleting the old ruleset

---

## Testing the Protection

After setup, try to push directly to main:

```bash
git checkout main
git commit --allow-empty -m "test"
git push origin main
```

You should see an error like:

```text
! [remote rejected] main -> main (refusing to allow a Personal Access Token to create or update workflow)
```

This confirms protection is working! ✅

---

## Workflow After Protection

All changes must go through PRs:

```bash
# 1. Create a feature branch
git checkout -b feature/my-feature

# 2. Make changes and commit
git add .
git commit -m "feat: add new feature"

# 3. Push to remote
git push origin feature/my-feature

# 4. Create PR on GitHub
# Visit: <https://github.com/koiralapankaj7/mz_utils/compare>

# 5. Wait for CI checks to pass (Analyze, Test, Package Analysis, Build Example)

# 6. Merge PR (through GitHub UI)

# 7. Delete feature branch (optional)
git branch -d feature/my-feature
git push origin --delete feature/my-feature
```

---

## Managing Rulesets

### List All Rulesets

```bash
gh api repos/koiralapankaj7/mz_utils/rulesets | jq '.[] | {id, name, target, enforcement}'
```

### View Specific Ruleset

```bash
# Get ruleset ID from list command above
gh api repos/koiralapankaj7/mz_utils/rulesets/RULESET_ID
```

### Update Ruleset

```bash
# Modify .github/rulesets/main-protection.json, then:
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/koiralapankaj7/mz_utils/rulesets/RULESET_ID" \
  --input .github/rulesets/main-protection.json
```

### Delete Ruleset

```bash
gh api \
  --method DELETE \
  -H "Accept: application/vnd.github+json" \
  "/repos/koiralapankaj7/mz_utils/rulesets/RULESET_ID"
```

---

## Quick Start: Protect Your Main Branch Now

Follow these steps to protect your `main` branch:

1. ✅ **Apply the ruleset** (choose one):
   - **Option A**: Import via GitHub UI (Settings → Rules → Import ruleset)
   - **Option B**: Run `./.github/setup-rulesets.sh` (requires `gh` CLI)

2. ✅ **Create your first PR**: <https://github.com/koiralapankaj7/mz_utils/compare/main...dev>

3. ✅ **Wait for CI checks** to pass (Analyze, Test, Package Analysis, Build Example)

4. ✅ **Merge the PR** through GitHub UI

5. ✅ **Tag and release**: After merge, create v0.0.1 tag for first release

---

## Troubleshooting

### "Not authenticated" error

```bash
gh auth login
# Choose your personal account (koiralapankaj7), not work account
```

### "Ruleset already exists" error

View existing rulesets:

```bash
gh api repos/koiralapankaj7/mz_utils/rulesets
```

Delete the old one and re-run setup, or update it directly.

### Status checks not appearing

Status check names appear after the first CI run. You may need to:

1. Create PR without status checks requirement first
2. Let CI run once
3. Update ruleset to add status checks

---

## Need Help?

- [GitHub Docs on Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [Rulesets API Reference](https://docs.github.com/en/rest/repos/rules)
- If you get locked out, you can temporarily disable the ruleset in Settings → Rules

---

## Why Rulesets Over Branch Protection?

**Rulesets** are GitHub's modern approach:

1. **Version Controlled**: Configuration lives in your repo (`.github/rulesets/`)
2. **Portable**: Easy to copy to other repositories
3. **Auditable**: Changes are tracked in git history
4. **Flexible**: Target multiple branches, tags, and more
5. **Future-Proof**: GitHub is investing in rulesets, not legacy branch protection

For new projects, **always use rulesets** instead of classic branch protection rules.
