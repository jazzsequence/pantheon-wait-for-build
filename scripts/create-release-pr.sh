#!/usr/bin/env bash
set -euo pipefail

# Determine next version by bumping the patch of the latest v1.x.y tag
git fetch --tags origin v1 main
LATEST=$(git tag -l 'v1.*.*' | sort -V | tail -1)

if [[ -z "$LATEST" ]]; then
  NEXT="v1.0.0"
else
  MAJOR=$(echo "$LATEST" | cut -d. -f1)
  MINOR=$(echo "$LATEST" | cut -d. -f2)
  PATCH=$(echo "$LATEST" | cut -d. -f3)
  NEXT="${MAJOR}.${MINOR}.$(( PATCH + 1 ))"
fi

echo "Next version: ${NEXT}"

# Nothing to release if v1 is already up-to-date with main
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
  --title "Release ${NEXT}" \
  --body "Automated draft PR to merge \`main\` into \`v1\`.

Merge this PR when you are ready to cut a release. A GitHub release will be created automatically once merged."

echo "✅ Draft release PR created"
