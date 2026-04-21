#!/usr/bin/env bash
set -uo pipefail

REPO="jazzsequence/devrel-wait-for-build"
EXIT=0

if [[ -z "${PR_NUMBER:-}" ]]; then
  echo "⚠️  PR_NUMBER is unset — skipping PR close"
else
  echo "Closing PR #${PR_NUMBER} on ${REPO}..."
  if gh pr close "$PR_NUMBER" \
    --repo "$REPO" \
    --comment "Test complete — closing automatically."; then
    echo "✅ PR #${PR_NUMBER} closed"
  else
    echo "⚠️  Could not close PR #${PR_NUMBER} (may already be closed)"
    EXIT=1
  fi
fi

if [[ -z "${DEVREL_BRANCH:-}" ]]; then
  echo "⚠️  DEVREL_BRANCH is unset — skipping branch deletion"
else
  echo "Deleting branch ${DEVREL_BRANCH}..."
  if gh api -X DELETE "repos/${REPO}/git/refs/heads/${DEVREL_BRANCH}"; then
    echo "✅ Branch ${DEVREL_BRANCH} deleted"
  else
    echo "⚠️  Could not delete branch ${DEVREL_BRANCH} (may already be deleted)"
    EXIT=1
  fi
fi

exit $EXIT
