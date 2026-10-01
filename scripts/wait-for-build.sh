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

  # GET /v1/sites/{siteId}/environments/{environment}/builds — newest first.
  # `pager` is a JSON-encoded query value; pager[first]=N is rejected with a 500.
  builds_response=$(curl -s -G \
    -H "Authorization: Bearer ${PANTHEON_TOKEN}" \
    --data-urlencode 'pager={"first":50}' \
    "https://api.pantheon.io/v1/sites/${SITE_UUID}/environments/${ENV}/builds?orderBy=LAST_UPDATED&direction=DESC")

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

  build=$(echo "$builds_response" | jq -c --arg sha "$COMMIT_SHA" 'first(.edges[]?.node | select(.commitHash == $sha)) // empty')

  if [[ -z "$build" ]]; then
    # The v1 list can transiently omit a build it returned on the previous poll, so keep polling
    if [[ $build_found -eq 1 ]]; then
      echo "⏳ Build not in this poll's results — retrying"
    else
      echo "⏳ No build yet for commit ${COMMIT_SHA:0:7}"
    fi
    sleep "$sleep_time"
    continue
  fi

  if [[ $build_found -eq 0 ]]; then
    echo "Build ID: $(echo "$build" | jq -r '.id')"
    build_found=1
  fi

  build_status=$(echo "$build" | jq -r '.status')
  deploy_status=$(echo "$build" | jq -r '.deploy.status // empty')
  echo "Status: $build_status${deploy_status:+ (deploy: $deploy_status)}"

  # A successful build is only "ready" once its deployment (when reported) has succeeded too.
  if [[ "$build_status" == "SUCCESS" && ( -z "$deploy_status" || "$deploy_status" == "SUCCESS" ) ]]; then
    echo "✅ Deployment successful"
    echo "deployment_ready=true" >> "$GITHUB_OUTPUT"
    exit 0
  elif [[ "$build_status" =~ ^(FAILURE|INTERNAL_ERROR|CANCELLED|TIMEOUT|EXPIRED)$ || "$deploy_status" =~ ^(FAILURE|INTERNAL_ERROR|CANCELLED|TIMEOUT|EXPIRED)$ ]]; then
    echo "❌ Build/deployment failed (build: $build_status, deploy: ${deploy_status:-n/a})"
    echo "deployment_ready=false" >> "$GITHUB_OUTPUT"
    exit 1
  fi

  sleep "$sleep_time"
done

echo "❌ Timeout after ${timeout_minutes} minutes"
echo "deployment_ready=false" >> "$GITHUB_OUTPUT"
exit 1
