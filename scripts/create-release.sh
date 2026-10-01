#!/usr/bin/env bash
set -euo pipefail

# Determine next version by bumping the patch of the latest v2.x.y tag
git fetch --tags
LATEST=$(git tag -l 'v2.*.*' | sort -V | tail -1)

if [[ -z "$LATEST" ]]; then
  NEXT="v2.0.0"
else
  MAJOR=$(echo "$LATEST" | cut -d. -f1)
  MINOR=$(echo "$LATEST" | cut -d. -f2)
  PATCH=$(echo "$LATEST" | cut -d. -f3)
  NEXT="${MAJOR}.${MINOR}.$(( PATCH + 1 ))"
fi

echo "Latest tag : ${LATEST:-none}"
echo "Next version: ${NEXT}"

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git tag "$NEXT"
git push origin "$NEXT"

gh release create "$NEXT" \
  --repo "$GITHUB_REPOSITORY" \
  --title "$NEXT" \
  --generate-notes \
  --latest

echo "✅ Released ${NEXT}"
