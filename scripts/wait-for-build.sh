#!/usr/bin/env bash
set -euo pipefail

timeout_minutes="${INPUT_TIMEOUT_MINUTES:-10}"
max_attempts=$(( timeout_minutes * 6 ))
sleep_time=10
attempt=0
build_found=0

echo "Waiting for Pantheon deployment..."
echo "Environment : ${ENV}"
echo "Commit      : ${COMMIT_SHA:0:7}"

while [[ $attempt -lt $max_attempts ]]; do
  attempt=$(( attempt + 1 ))
  [[ "${RUNNER_DEBUG:-0}" == "1" ]] && echo "Check ${attempt} of ${max_attempts}..."

  builds_response=$(curl -s \
    -H "X-Pantheon-Session: ${SESSION_TOKEN}" \
    "https://terminus.pantheon.io/api/sites/${SITE_UUID}/environment/${ENV}/build/list?limit=10")

  if ! echo "$builds_response" | jq empty 2>/dev/null; then
    echo "⚠️  Non-JSON response from build list API — retrying..."
    sleep "$sleep_time"
    continue
  fi

  if [[ "${RUNNER_DEBUG:-0}" == "1" && $attempt -eq 1 ]]; then
    echo "--- DEBUG: build list (attempt 1) ---"
    echo "$builds_response" | jq '.'
    echo "-------------------------------------"
  fi

  build=$(echo "$builds_response" | jq -c --arg sha "$COMMIT_SHA" 'first(.[] | select(.commit == $sha)) // empty')

  if [[ -z "$build" ]]; then
    echo "⏳ No build yet for commit ${COMMIT_SHA:0:7}"
    sleep "$sleep_time"
    continue
  fi

  if [[ $build_found -eq 0 ]]; then
    echo "Build ID: $(echo "$build" | jq -r '.id')"
    build_found=1
  fi

  build_status=$(echo "$build" | jq -r '.status')
  echo "Status: $build_status"

  if [[ "$build_status" == "DEPLOYMENT_SUCCESS" || "$build_status" == "BUILD_SUCCESS" ]]; then
    echo "✅ Deployment successful"
    echo "deployment_ready=true" >> "$GITHUB_OUTPUT"
    exit 0
  elif [[ "$build_status" == *"FAILURE"* ]]; then
    echo "❌ Build/deployment failed (status: $build_status)"
    echo "deployment_ready=false" >> "$GITHUB_OUTPUT"
    exit 1
  fi

  sleep "$sleep_time"
done

echo "❌ Timeout after ${timeout_minutes} minutes"
echo "deployment_ready=false" >> "$GITHUB_OUTPUT"
exit 1
