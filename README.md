# pantheon-wait-for-build

A GitHub Action that polls the Pantheon API until a Next.js site build and deployment reaches a terminal state, then optionally clears the GCDN cache.

No Terminus CLI required — pure `curl` + `jq` against the Pantheon REST API.

## Usage

```yaml
- name: Wait for Pantheon build and deployment
  uses: jazzsequence/pantheon-wait-for-build@v1
  with:
    pantheon-machine-token: ${{ secrets.PANTHEON_MACHINE_TOKEN }}
    site-name: my-pantheon-site
```

### With explicit environment and cache control

```yaml
- name: Wait for Pantheon build and deployment
  uses: jazzsequence/pantheon-wait-for-build@v1
  with:
    pantheon-machine-token: ${{ secrets.PANTHEON_MACHINE_TOKEN }}
    site-name: my-pantheon-site
    environment: test
    timeout-minutes: 15
    clear-cache: false
```

### Using the output

```yaml
- name: Wait for Pantheon build and deployment
  id: pantheon
  uses: jazzsequence/pantheon-wait-for-build@v1
  with:
    pantheon-machine-token: ${{ secrets.PANTHEON_MACHINE_TOKEN }}
    site-name: my-pantheon-site

- name: Do something after deployment
  if: steps.pantheon.outputs.deployment-ready == 'true'
  run: echo "Deployment is live!"
```

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `pantheon-machine-token` | Yes | — | Pantheon machine token for API authentication |
| `site-name` | Yes | — | Pantheon site machine name (e.g. `my-site`) |
| `environment` | No | auto-detected | Pantheon environment: `dev`, `test`, `live`, or a multidev name like `pr-123`. If omitted, `pull_request` events use `pr-{number}` and everything else uses `dev`. |
| `timeout-minutes` | No | `10` | Maximum minutes to wait before failing |
| `clear-cache` | No | `true` | Clear Pantheon GCDN cache after a successful deployment |

## Outputs

| Output | Description |
|---|---|
| `deployment-ready` | `'true'` if the deployment completed successfully, `'false'` otherwise |

## How it works

1. **Authenticate** — exchanges the machine token for a session token via `POST /v0/authorize/machine-token`
2. **Resolve site UUID** — looks up the site UUID from the site name via `GET /v0/site-names/{site_name}`
3. **Detect environment and commit** — derives the target environment and commit SHA from GitHub event context (no manual input required for standard push and pull_request workflows)
4. **Poll build status** — checks the Pantheon build list every 10 seconds, matching by commit SHA, until the build reaches `DEPLOYMENT_SUCCESS`, `BUILD_SUCCESS`, or a failure state
5. **Clear cache** — if enabled, dispatches a GCDN cache clear via `POST /v0/sites/{id}/environments/{env}/cache/clear` and polls until the workflow completes

## Requirements

- A Pantheon machine token stored as a repository secret
- `jq` — available by default on `ubuntu-latest` GitHub Actions runners
- `curl` — available by default on `ubuntu-latest` GitHub Actions runners

## Notes

**PR commit SHA**: On `pull_request` events, GitHub creates a synthetic merge commit (`github.sha`) that Pantheon never sees. This action automatically uses `github.event.pull_request.head.sha` (the branch head) for PR events, which is what Pantheon actually checks out and builds.

**Build list endpoint**: The build status polling uses an internal Pantheon endpoint (`terminus.pantheon.io`) that is specific to Next.js sites on Pantheon. This action is designed for Pantheon front-end sites running Next.js.
