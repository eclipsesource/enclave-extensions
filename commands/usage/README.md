# usage

Experimental command-only extension providing `enclave usage`. It runs
[ccusage](https://github.com/ryoppippi/ccusage) over the Claude, Codex,
and Pi sessions that Enclave persists per project, producing token and cost
reports for sandboxed work.

## Owner

Tobias Ortmayr — [tortmayr@eclipsesource.com](mailto:tortmayr@eclipsesource.com)

## How I use it

To inspect token usage and estimated costs across persisted sandbox sessions
without opening each project's agent data separately. Host sessions can be
included when I want a combined view.

## State

🟡 Occasionally used, may receive updates. Experimental; ccusage compatibility
and retained session data determine report coverage.

## Install

Requires an Enclave version with command-extension support:

```bash
enclave commands add eclipsesource/enclave-extensions --name usage
```

The command is available immediately after installation. There is no feature to
enable, container installation, or image rebuild.

## Usage

```bash
enclave usage                      # daily report, Enclave sessions only
enclave usage monthly --by-agent   # ccusage arguments pass through
enclave usage --include-host       # also include ordinary host sessions
enclave usage --show-paths         # print discovered session roots, then exit
enclave usage --help               # wrapper options
```

Unrecognized arguments pass through to ccusage. Use `enclave usage daily --help`
for ccusage's daily-report help; a first-position `--help` shows wrapper help.
`--enclave-only` switches back to the default scope, and `--` forwards all
remaining arguments without interpreting wrapper options.

The command uses `ccusage@latest` by default. Set `ENCLAVE_CCUSAGE_VERSION` to
use a specific version or tag:

```bash
ENCLAVE_CCUSAGE_VERSION=20.0.48 enclave usage monthly
```

An unset or empty variable uses `latest`.

## Requirements and host access

- Runs on the **host**, outside Enclave's sandbox, and requires Bash and `npx`
  (Node.js/npm). Help and `--show-paths` do not require `npx`.
- Executes ccusage through `npx --yes`.
  npm may contact its configured registry to fetch the package and dependencies;
  ccusage may fetch pricing data. Host networking applies, not Enclave's gateway
  allowlists.
- Reads local session data. No agent credentials are configured or required by
  this wrapper.
- Keeps the npm cache in `~/.npm`. Temporary isolation directories are removed
  when the command exits; session files are not modified by the wrapper.

## Scope and limitations

- By default, discovers sessions under Enclave's platform state root:
  `${XDG_STATE_HOME:-~/.local/state}/enclave` on Linux (only absolute XDG
  overrides are honored), or `~/Library/Application Support/org.eclipse.enclave/state`
  on macOS. It scans all persisted projects, not just the current directory.
- Enclave-only mode isolates ccusage's home/XDG discovery so it does not
  automatically include ordinary host sessions. Agents without persisted
  Enclave data receive explicit empty roots.
- `--include-host` adds the standard Claude, Codex, and Pi host data
  directories and leaves ccusage's other host discovery enabled. It does not
  explicitly resolve custom agent data-directory overrides as additional roots.
- Reports depend on retained transcripts and ccusage's supported formats and
  pricing, not provider billing records or live account quotas.
- Data paths containing commas or newlines are unsupported. Canonically identical
  roots are deduplicated per agent.

Use `--show-paths` to inspect discovered roots without running ccusage or fetching
npm packages.
