#!/usr/bin/env bash
set -euo pipefail

echo "Clearing Pantheon GCDN cache for ${ENV}..."

# POST /v0/sites/{site_id}/environments/{env_id}/cache/clear
clear_response=$(curl -s -X POST \
  -H "Authorization: Bearer ${SESSION_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"framework_cache": true}' \
  "https://api.pantheon.io/v0/sites/${SITE_UUID}/environments/${ENV}/cache/clear")

workflow_id=$(echo "$clear_response" | jq -r '.id // empty')
if [[ -z "$workflow_id" ]]; then
  echo "⚠️  Cache clear dispatch failed — continuing anyway"
  echo "Response: $clear_response"
  exit 0
fi
echo "✅ Cache clear dispatched (workflow: $workflow_id)"

# Poll GET /v0/sites/{site_id}/workflows/{workflow_id} until terminal result
# result values: "succeeded", "failed", empty (queued/running)
attempt=0
max=30
while [[ $attempt -lt $max ]]; do
  attempt=$(( attempt + 1 ))
  sleep 5

  status=$(curl -s \
    -H "Authorization: Bearer ${SESSION_TOKEN}" \
    "https://api.pantheon.io/v0/sites/${SITE_UUID}/workflows/${workflow_id}" \
    | jq -r '.result // empty')

  echo "  Cache clear status: ${status:-pending}"

  if [[ "$status" == "succeeded" ]]; then
    echo "✅ Cache cleared"
    exit 0
  elif [[ "$status" == "failed" ]]; then
    echo "⚠️  Cache clear failed — continuing anyway"
    exit 0
  fi
done

echo "⚠️  Cache clear polling timed out — continuing anyway"
