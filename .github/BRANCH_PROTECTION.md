# Branch Protection Setup

This guide shows how to protect the `main` branch from direct pushes and require Pull Requests.

## Automated Setup (Recommended)

Run the setup script using GitHub CLI:

```bash
# Make sure GitHub CLI is installed and authenticated
gh auth login

# Run the setup script
.github/setup-branch-protection.sh
```

That's it! The script will configure all protection rules automatically.

---

## Manual Setup

If you prefer manual configuration:

1. **Go to Branch Protection Settings**

   Visit: <https://github.com/koiralapankaj7/mz_utils/settings/branches>

2. **Click "Add branch protection rule"**

3. **Configure the following settings:**

---

### Branch name pattern

```text
main
```

### Protection Rules

#### ✅ Require a pull request before merging

- **Require approvals**: 0 (or 1 if you want self-review)
  - For solo projects, 0 is fine - you'll still need to create PRs
  - For team projects, set to 1 or more

- ☑ **Dismiss stale pull request approvals when new commits are pushed**
  - This ensures reviews are current

- ☑ **Require review from Code Owners** (optional)
  - Only if you create a `.github/CODEOWNERS` file

#### ✅ Require status checks to pass before merging

- ☑ **Require branches to be up to date before merging**

- **Status checks that are required:**
  - `Analyze` (from CI workflow)
  - `Test` (from CI workflow)
  - `Package Analysis` (from CI workflow)
  - `Build Example App` (from CI workflow)

  > **Note**: These will appear after you merge your first PR and CI runs

#### ✅ Require conversation resolution before merging

- Ensures all review comments are addressed

#### ✅ Require linear history (optional but recommended)

- Prevents merge commits, keeps history clean
- All PRs must be rebased or squashed

#### ❌ Do not allow bypassing the above settings

- Leave **UNCHECKED** if you want to bypass as repository admin
- Check if you want strict enforcement even for admins

#### ❌ Allow force pushes

- Keep **UNCHECKED** - never allow force pushes to main

#### ❌ Allow deletions

- Keep **UNCHECKED** - prevent accidental branch deletion

---

## Recommended Settings Summary

```yaml
Branch name pattern: main

Protection rules:
  ✅ Require pull request before merging
     - Required approvals: 0 (solo) or 1+ (team)
     - Dismiss stale reviews: Yes

  ✅ Require status checks to pass
     - Require up-to-date branches: Yes
     - Required checks: Analyze, Test, Package Analysis, Build Example App

  ✅ Require conversation resolution: Yes

  ✅ Require linear history: Yes (optional)

  ❌ Allow bypassing: No (or Yes if you need admin override)

  ❌ Allow force pushes: No

  ❌ Allow deletions: No
```

## Testing the Protection

After setup, try to push directly to main:

```bash
git checkout main
git commit --allow-empty -m "test"
git push origin main
```

You should see:
```
! [remote rejected] main -> main (protected branch hook declined)
```

This confirms protection is working! ✅

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

# 5. Wait for CI checks to pass

# 6. Merge PR (through GitHub UI)

# 7. Delete feature branch (optional)
git branch -d feature/my-feature
git push origin --delete feature/my-feature
```

## For Your Current dev → main PR

Since you already have a dev branch with changes:

1. ✅ Set up branch protection (follow steps above)
2. ✅ Create PR: https://github.com/koiralapankaj7/mz_utils/compare/main...dev
3. ✅ Wait for CI checks to pass
4. ✅ Review and merge PR
5. ✅ After merge, tag v0.0.1 for first release

---

## Optional: Protect dev Branch Too

If you want to protect the `dev` branch (less strict):

```yaml
Branch name pattern: dev

Protection rules:
  ✅ Require status checks to pass
     - Required checks: Analyze, Test

  ❌ Require pull request: No (can push directly)

  ❌ Allow force pushes: No
```

This ensures dev always passes CI but allows direct pushes.

---

## Need Help?

- [GitHub Docs on Protected Branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- If you get locked out, you can temporarily disable protection in Settings → Branches
