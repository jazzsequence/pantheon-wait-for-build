#!/usr/bin/env bash
set -euo pipefail

# Nothing to release if v1 is already up-to-date with main
git fetch origin v1 main
if git diff --quiet origin/v1 origin/main; then
  echo "v1 is already up-to-date with main — no release PR needed"
  exit 0
fi

# Idempotent — if an open PR from main → v1 already exists, do nothing.
# The open PR auto-tracks the main branch head, so no update is needed.
EXISTING=$(gh pr list \
  --repo "$GITHUB_REPOSITORY" \
  --base v1 \
  --head main \
  --state open \
  --json number \
  --jq '.[0].number // empty')

if [[ -n "$EXISTING" ]]; then
  echo "Release PR #${EXISTING} already exists — no action needed"
  exit 0
fi

echo "Creating draft release PR: main → v1"
gh pr create \
  --repo "$GITHUB_REPOSITORY" \
  --base v1 \
  --head main \
  --draft \
  --title "Release: merge main into v1" \
  --body "Automated draft PR to merge \`main\` into \`v1\`.

Merge this PR when you are ready to cut a release. A GitHub release will be created automatically once merged."

echo "✅ Draft release PR created"
