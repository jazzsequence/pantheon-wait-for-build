#!/usr/bin/env bash
set -euo pipefail

# Exchange machine token for a session token (POST /v0/authorize/machine-token)
session_response=$(curl -s -X POST https://api.pantheon.io/v0/authorize/machine-token \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg t "$PANTHEON_MACHINE_TOKEN" '{machine_token: $t, client: "github-actions"}')")

session_token=$(echo "$session_response" | jq -r '.session // empty')
if [[ -z "$session_token" ]]; then
  echo "❌ Failed to obtain Pantheon API session token"
  echo "Response: $session_response"
  exit 1
fi
echo "::add-mask::$session_token"
echo "✓ Authenticated with Pantheon API"

# Resolve site name → UUID (GET /v0/site-names/{site_name})
uuid_response=$(curl -s \
  -H "Authorization: Bearer $session_token" \
  "https://api.pantheon.io/v0/site-names/${SITE_NAME}")

site_uuid=$(echo "$uuid_response" | jq -r '.id // empty')
if [[ -z "$site_uuid" ]]; then
  echo "❌ Could not resolve site UUID for '${SITE_NAME}'"
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

# For PRs, use the branch head SHA — github.sha is GitHub's synthetic merge commit,
# which Pantheon never sees. The PR head is what Pantheon actually checks out and builds.
if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" ]]; then
  commit_sha="${GITHUB_PR_HEAD_SHA}"
else
  commit_sha="${GITHUB_SHA}"
fi

{
  echo "session_token=${session_token}"
  echo "site_uuid=${site_uuid}"
  echo "env=${env_name}"
  echo "commit_sha=${commit_sha}"
} >> "$GITHUB_OUTPUT"
