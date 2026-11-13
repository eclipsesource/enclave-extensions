# gws

The [Google Workspace CLI](https://github.com/googleworkspace/cli) (`gws`)
from a pinned release. Opt-in (disabled by default). Use it with the
[gws filter](../../filters/gws/README.md), which keeps the Google credential on
the host and decides which API calls go through.

## Owner

Stefan Dirix ([sdirix@eclipsesource.com](mailto:sdirix@eclipsesource.com))

## How it is used

Let the agent work with Gmail, Calendar, Drive, Docs, Sheets, and Slides
through `gws`, limited to what a filter preset allows, for example reading
mail and drafting replies without sending them.

## State

🟡 Occasionally used, may receive updates. Experimental. Needs an Enclave
version with request filters.

## Usage

**Priority**: 60

```bash
enclave features add eclipsesource/enclave-extensions --name gws
enclave filters add eclipsesource/enclave-extensions --name gws
enclave --features +gws --filters gws
```

Setup of the Google OAuth client and the presets are in the
[filter README](../../filters/gws/README.md).

## Installation

| Component | Source | Provides |
|-----------|--------|----------|
| gws `0.22.5` | `install.sh` | `gws` in `~/.local/bin` |

`install.sh` downloads the static musl build for x86_64 or aarch64 from the
[googleworkspace/cli releases](https://github.com/googleworkspace/cli/releases)
and verifies it against a pinned SHA-256. A mismatch fails the build. The musl
build avoids the glibc 2.39 requirement of the gnu build.

To bump, update `GWS_VERSION` and both checksums together. The release
publishes them next to each archive as
`google-workspace-cli-<arch>-unknown-linux-musl.tar.gz.sha256`.

## Configuration

| Variable | Value | Why |
|----------|-------|-----|
| `GOOGLE_WORKSPACE_CLI_TOKEN` | Placeholder, set by the gws filter | gws sends it as the bearer token and skips its credential store and keyring |
| `GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND` | `file` | gws has no OS keyring on Linux. Only `gws auth` commands use it |

gws keeps its discovery cache (24 hour TTL) and the account timezone in
`~/.config/gws`. That directory is in the container, so it starts empty each
session. `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` is not needed.

gws uses the system trust store and `SSL_CERT_FILE`, so it trusts the gateway
CA that the filter needs for inspecting requests.

## Network

None declared. The gws filter adds its hosts to the session's allowlist and
blocks every other `googleapis.com` host
([Limitations](../../filters/gws/README.md#limitations)).

## Credentials

None declared. The filter sets `GOOGLE_WORKSPACE_CLI_TOKEN`. Without the filter
gws has no credential. Do not pass a real token with `--env`, the agent could
read it.

## Skill

`gws-filter` tells the agent to read the active preset from
`ENCLAVE_ACTIVE_FILTERS` and the policy summary from
`$ENCLAVE_FILTER_SUMMARY_DIR/gws.json` before acting. Enclave core sets both
in the tool container. The skill also explains how to read a 403 with reason
`enclaveFilter` and what is never allowed.

## Limitations

- `gws auth login`, `gws auth setup`, and `gws auth export` do not apply. Log
  in on the host with `enclave filters login gws`.
- Helpers that call Tasks, Chat, Pub/Sub, Workspace Events, Apps Script, or
  Model Armor fail. The filter blocks those hosts and does not govern them.
  See the
  [filter README](../../filters/gws/README.md#gws-commands-per-preset).
