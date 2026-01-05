#!/bin/bash

# Branch Protection Setup Script
# This script uses GitHub CLI to configure branch protection rules
#
# Prerequisites:
#   - GitHub CLI installed: https://cli.github.com/
#   - Authenticated: gh auth login
#
# Usage:
#   chmod +x .github/setup-branch-protection.sh
#   .github/setup-branch-protection.sh

set -e

REPO="koiralapankaj7/mz_utils"
BRANCH="main"

echo "🔒 Setting up branch protection for $REPO on branch: $BRANCH"

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed."
    echo "📦 Install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI."
    echo "🔑 Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI is installed and authenticated"
echo ""

# Enable branch protection
echo "⚙️  Configuring branch protection rules..."

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "/repos/$REPO/branches/$BRANCH/protection" \
  -f required_status_checks[strict]=true \
  -f required_status_checks[contexts][]=Analyze \
  -f required_status_checks[contexts][]=Test \
  -f required_status_checks[contexts][]='Package Analysis' \
  -f required_status_checks[contexts][]='Build Example App' \
  -f enforce_admins=false \
  -f required_pull_request_reviews[dismiss_stale_reviews]=true \
  -f required_pull_request_reviews[require_code_owner_reviews]=false \
  -f required_pull_request_reviews[required_approving_review_count]=0 \
  -f required_pull_request_reviews[require_last_push_approval]=false \
  -f restrictions=null \
  -f required_conversation_resolution=true \
  -f lock_branch=false \
  -f allow_fork_syncing=true \
  -f required_linear_history=false \
  -f allow_force_pushes=false \
  -f allow_deletions=false

echo ""
echo "✅ Branch protection configured successfully!"
echo ""
echo "📋 Protection rules applied:"
echo "  ✓ Require pull request before merging"
echo "  ✓ Required approvals: 0"
echo "  ✓ Dismiss stale reviews: Yes"
echo "  ✓ Require status checks: Analyze, Test, Package Analysis, Build Example App"
echo "  ✓ Require conversation resolution: Yes"
echo "  ✓ Allow force pushes: No"
echo "  ✓ Allow deletions: No"
echo "  ✓ Enforce for admins: No (you can bypass if needed)"
echo ""
echo "🔍 View settings at: https://github.com/$REPO/settings/branches"
echo ""
echo "✨ Done! Try pushing directly to $BRANCH - it should be blocked."
