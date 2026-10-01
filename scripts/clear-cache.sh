#!/usr/bin/env bash
set -euo pipefail

echo "Clearing Pantheon GCDN cache for ${ENV}..."

# POST /v1/sites/{siteId}/environments/{environment}/cache/clear
clear_response=$(curl -s -X POST \
  -H "Authorization: Bearer ${PANTHEON_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg s "$SITE_UUID" --arg e "$ENV" '{siteId: $s, environment: $e, frameworkCache: true}')" \
  "https://api.pantheon.io/v1/sites/${SITE_UUID}/environments/${ENV}/cache/clear")

workflow_id=$(echo "$clear_response" | jq -r '.id // empty')
if [[ -z "$workflow_id" ]]; then
  echo "⚠️  Cache clear dispatch failed — continuing anyway"
  echo "Response: $clear_response"
  exit 0
fi
echo "✅ Cache clear dispatched (workflow: $workflow_id)"

# Poll GET /v1/sites/{siteId}/workflows/{workflowId} until terminal status
# status values: NOT_STARTED, IN_PROGRESS, SUCCESS, FAILED, CANCELED
attempt=0
max=30
while [[ $attempt -lt $max ]]; do
  attempt=$(( attempt + 1 ))
  sleep 5

  status=$(curl -s \
    -H "Authorization: Bearer ${PANTHEON_TOKEN}" \
    "https://api.pantheon.io/v1/sites/${SITE_UUID}/workflows/${workflow_id}" \
    | jq -r '.status // empty')

  echo "  Cache clear status: ${status:-pending}"

  if [[ "$status" == "SUCCESS" ]]; then
    echo "✅ Cache cleared"
    exit 0
  elif [[ "$status" == "FAILED" || "$status" == "CANCELED" ]]; then
    echo "⚠️  Cache clear failed — continuing anyway"
    exit 0
  fi
done

echo "⚠️  Cache clear polling timed out — continuing anyway"
