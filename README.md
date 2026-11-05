# EclipseSource Enclave Extensions

A collection of extensions for [Eclipse Enclave](https://github.com/eclipse-enclave/enclave)
that we use at EclipseSource.

The goal is **not** to maintain polished, production-ready extensions, but to share what we build for ourselves so that others can:

- **discover** extensions that might solve a problem they have,
- **adapt** them to their own needs, or
- **get inspired** to build something similar.

There are no promises of long-term maintenance or support. Every extension is shared as-is.

## Structure

```text
features/  Optional sandbox capabilities (kind: mixin)
tools/     Runnable sandbox tools (kind: sandbox)
commands/  Host-only commands (kind: command)
```

Each extension lives in `<kind>/<name>/` with its own `spec.yaml` and
`README.md`.

## Install

Install an extension by name with the command for its type:

```bash
enclave tools add eclipsesource/enclave-extensions --name <name>
enclave features add eclipsesource/enclave-extensions --name <name>
enclave commands add eclipsesource/enclave-extensions --name <name>
```

See the extension's README for requirements and usage, and Enclave's
[installation guide](https://github.com/eclipse-enclave/enclave/blob/main/docs/extensions/installing.md)
for more options.

## Trust and maturity

Extensions may be experimental, specific to a use case, or have rough edges.
Check the extension's README for requirements, credentials, network access,
persistence, and limitations. Read the installer's capability summary before
installing or updating. Host commands run outside the sandbox with your user
privileges. Tools and features may also run code during container builds and
startup.

## Contributing

Any ES employee can add an extension. No proposal is needed. Keep it small and
practical. Put it in the directory for its type and include a README with:

1. A short description of what it does.
2. How you use it: the problem it solves and where it fits in your workflow.
3. The owner's name and contact details or GitHub handle.
4. Its maintenance state:
   - 🟢 Used daily and actively maintained
   - 🟡 Occasionally used, may receive updates
   - 🔵 Ad-hoc (built for a one-time task, not expected to be updated)
   - ⚫ Archived (no longer used or maintained)
5. Enough instructions to install and run it, including requirements and any
   relevant credentials, network access, persistence, or known limitations.

### Ownership and pull requests

The owner listed in the extension's README is the point of contact. This does
not come with a commitment to provide support.

- Open a PR for a new extension or an update to one you own. You can merge it
  yourself without additional review.
- If a PR changes someone else's extension code, get that owner's approval
  before merging. For changes spanning several owners, ask each affected owner.

We follow these rules by agreement, without automated enforcement.

### Extension layout

- Put tools in `tools/<name>/` with `kind: sandbox`.
- Put features in `features/<name>/` with `kind: mixin`.
- Put host-only extensions in `commands/<name>/` with `kind: command`.
- Match the directory name to the spec's `name`.
- Command specs contain metadata only. Put executable commands in
  `commands/host/<command-name>` within the extension, and preserve their
  executable bits. They do not install anything into a sandbox image.

See Enclave's [extension reference](https://github.com/eclipse-enclave/enclave/blob/main/docs/extensions/README.md)
and [installation guide](https://github.com/eclipse-enclave/enclave/blob/main/docs/extensions/installing.md).

## License

MIT. See [LICENSE](LICENSE).
