#!/usr/bin/env bash
set -euo pipefail

REPO="jazzsequence/devrel-wait-for-build"

echo "Closing PR #${PR_NUMBER} on ${REPO}..."
gh pr close "$PR_NUMBER" \
  --repo "$REPO" \
  --comment "Test complete — closing automatically."

echo "Deleting branch ${DEVREL_BRANCH}..."
gh api -X DELETE "repos/${REPO}/git/refs/heads/${DEVREL_BRANCH}"

echo "✅ Cleanup complete"
