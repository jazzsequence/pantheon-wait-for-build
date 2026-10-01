#!/usr/bin/env bash
set -euo pipefail

# v1 authenticates every request with a Personal Access Token sent as a Bearer token —
# there is no machine-token → session-token exchange anymore.
if [[ -z "${PANTHEON_TOKEN:-}" ]]; then
  echo "❌ No Pantheon token provided (set the pantheon-access-token input)"
  exit 1
fi
if [[ -n "${LEGACY_MACHINE_TOKEN_USED:-}" ]]; then
  echo "::warning::'pantheon-machine-token' is deprecated. The Pantheon v1 API needs a Personal Access Token — pass it via 'pantheon-access-token'."
fi

# Resolve site name → UUID (GET /v1/sites/by-name/{siteName}); the response body is the UUID string
uuid_response=$(curl -s \
  -H "Authorization: Bearer ${PANTHEON_TOKEN}" \
  "https://api.pantheon.io/v1/sites/by-name/${SITE_NAME}")

# Accept a JSON string, an object with .id, or a bare UUID — the spec only says "string"
site_uuid=$(echo "$uuid_response" | jq -r 'if type == "string" then . else (.id // empty) end' 2>/dev/null || true)
if [[ -z "$site_uuid" ]]; then
  site_uuid=$(echo "$uuid_response" | grep -Eio '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' || true)
fi
if [[ -z "$site_uuid" ]]; then
  echo "❌ Could not resolve site UUID for '${SITE_NAME}' (check the token and site name)"
  echo "Response: $uuid_response"
  exit 1
fi
echo "✓ Site UUID resolved"

# Determine environment from input or GitHub context
if [[ -n "${INPUT_ENVIRONMENT:-}" ]]; then
  env_name="${INPUT_ENVIRONMENT}"
elif [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" ]]; then
  env_name="pr-${GITHUB_PR_NUMBER}"
else
  env_name="dev"
fi

# Commit SHA: explicit override takes priority (used when the relevant commit is in a
# different repo, e.g. integration test workflows). Otherwise derive from GitHub context.
# For PRs, use the branch head — github.sha is GitHub's synthetic merge commit, which
# Pantheon never sees.
if [[ -n "${INPUT_COMMIT_SHA:-}" ]]; then
  commit_sha="${INPUT_COMMIT_SHA}"
elif [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" ]]; then
  commit_sha="${GITHUB_PR_HEAD_SHA}"
else
  commit_sha="${GITHUB_SHA}"
fi

{
  echo "site_uuid=${site_uuid}"
  echo "env=${env_name}"
  echo "commit_sha=${commit_sha}"
} >> "$GITHUB_OUTPUT"
