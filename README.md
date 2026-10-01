# pantheon-wait-for-build

A GitHub Action that polls the Pantheon API until a Next.js site build and deployment reaches a terminal state, then optionally clears the GCDN cache.

No Terminus CLI required — pure `curl` + `jq` against the Pantheon REST API.

## Usage

```yaml
- name: Wait for Pantheon build and deployment
  uses: jazzsequence/pantheon-wait-for-build@v2
  with:
    pantheon-access-token: ${{ secrets.PANTHEON_ACCESS_TOKEN }}
    site-name: my-pantheon-site
```

### With explicit environment and cache control

```yaml
- name: Wait for Pantheon build and deployment
  uses: jazzsequence/pantheon-wait-for-build@v2
  with:
    pantheon-access-token: ${{ secrets.PANTHEON_ACCESS_TOKEN }}
    site-name: my-pantheon-site
    environment: test
    timeout-minutes: 15
    clear-cache: false
```

### Using the output

```yaml
- name: Wait for Pantheon build and deployment
  id: pantheon
  uses: jazzsequence/pantheon-wait-for-build@v2
  with:
    pantheon-access-token: ${{ secrets.PANTHEON_ACCESS_TOKEN }}
    site-name: my-pantheon-site

- name: Do something after deployment
  if: steps.pantheon.outputs.deployment-ready == 'true'
  run: echo "Deployment is live!"
```

## Migrating from v1

v2 targets the Pantheon Public API v1 (`api.pantheon.io/v1`), which authenticates with a [Personal Access Token](https://docs.pantheon.io/personal-access-tokens) instead of exchanging a machine token for a session token.

1. Create a Personal Access Token and store it as a repository secret.
2. Pass it as `pantheon-access-token` instead of `pantheon-machine-token`.
3. Update `uses:` to `@v2`.

`pantheon-machine-token` is still accepted (and ignored when `pantheon-access-token` is set), but a real machine token will not authenticate against the v1 API. The input will be removed in a future release. Stay on `@v1` if you can't migrate yet.

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `pantheon-access-token` | Yes* | — | Pantheon [Personal Access Token](https://docs.pantheon.io/personal-access-tokens) for the Public API v1 |
| `pantheon-machine-token` | No | — | **Deprecated.** Fallback used only when `pantheon-access-token` is empty; logs a deprecation warning. The v1 API no longer exchanges machine tokens, so the value must be a Personal Access Token. |
| `site-name` | Yes | — | Pantheon site machine name (e.g. `my-site`) |
| `environment` | No | auto-detected | Pantheon environment: `dev`, `test`, `live`, or a multidev name like `pr-123`. If omitted, `pull_request` events use `pr-{number}` and everything else uses `dev`. |
| `timeout-minutes` | No | `10` | Maximum minutes to wait before failing |
| `clear-cache` | No | `true` | Clear Pantheon GCDN cache after a successful deployment |

\* One of `pantheon-access-token` or `pantheon-machine-token` is required. `pantheon-access-token` wins if both are set.

## Outputs

| Output | Description |
|---|---|
| `deployment-ready` | `'true'` if the deployment completed successfully, `'false'` otherwise |

## How it works

1. **Resolve site UUID** — looks up the site UUID from the site name via `GET /v1/sites/by-name/{siteName}`, authenticating with the Personal Access Token as a Bearer token
2. **Detect environment and commit** — derives the target environment and commit SHA from GitHub event context (no manual input required for standard push and pull_request workflows)
3. **Poll build status** — checks `GET /v1/sites/{id}/environments/{env}/builds` every 10 seconds, matching by `commitHash`, until the build is `SUCCESS` (and its `deploy` is `SUCCESS`, when reported) or reaches a failure state
4. **Clear cache** — if enabled, dispatches a GCDN cache clear via `POST /v1/sites/{id}/environments/{env}/cache/clear` and polls the workflow until it is `SUCCESS`, `FAILED`, or `CANCELED`

## Requirements

- A Pantheon Personal Access Token stored as a repository secret (PATs expire after 90 days — rotate them)
- `jq` — available by default on `ubuntu-latest` GitHub Actions runners
- `curl` — available by default on `ubuntu-latest` GitHub Actions runners

## Notes

**PR commit SHA**: On `pull_request` events, GitHub creates a synthetic merge commit (`github.sha`) that Pantheon never sees. This action automatically uses `github.event.pull_request.head.sha` (the branch head) for PR events, which is what Pantheon actually checks out and builds.

**Build list endpoint**: Build status polling uses the Pantheon Public API v1 builds endpoint. This action is designed for Pantheon front-end sites running Next.js.
