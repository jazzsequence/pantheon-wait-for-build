#!/usr/bin/env bash
set -euo pipefail

REPO="jazzsequence/devrel-wait-for-build"
BRANCH="test/ci-${GITHUB_RUN_ID}"

echo "Cloning ${REPO}..."
git clone "https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git" devrel
cd devrel || exit 1

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git checkout -b "$BRANCH"

# Increment the counter file — any change triggers a Pantheon build
CURRENT=$(cat .test-trigger 2>/dev/null || echo "0")
echo $(( CURRENT + 1 )) > .test-trigger

git add .test-trigger
git commit -m "chore: trigger test build [run ${GITHUB_RUN_ID}]"
git push origin "$BRANCH"

COMMIT_SHA=$(git rev-parse HEAD)

echo "Creating PR on ${REPO}..."
PR_URL=$(gh pr create \
  --repo "$REPO" \
  --head "$BRANCH" \
  --base main \
  --title "Test build trigger [CI run ${GITHUB_RUN_ID}]" \
  --body "Automated test build triggered by \`pantheon-wait-for-build\` CI. This PR will be closed automatically once the build completes.")

PR_NUMBER=$(echo "$PR_URL" | grep -o '[0-9]*$')
echo "✅ Created PR #${PR_NUMBER} (commit ${COMMIT_SHA:0:7}) on branch ${BRANCH}"

{
  echo "pr_number=${PR_NUMBER}"
  echo "commit_sha=${COMMIT_SHA}"
  echo "branch=${BRANCH}"
} >> "$GITHUB_OUTPUT"
