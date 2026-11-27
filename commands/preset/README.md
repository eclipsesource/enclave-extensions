# preset

Saved enclave flags per directory, git repository, or globally, kept in one
file. A repository rule covers every worktree of the repository. A global
preset works in every directory.

## Owner

Stefan Dirix ([sdirix@eclipsesource.com](mailto:sdirix@eclipsesource.com))

## How it is used

Keep the enclave flags a repository needs, such as features and allowed
domains, in one place and start every worktree with them. Named presets cover
variants such as a read-only review session, and global presets make one
available everywhere.

## State

🟢 Used daily and actively maintained. Experimental.

## Install

```bash
enclave commands add eclipsesource/enclave-extensions --name preset
```

Needs `jq` and `git` on the host. The command runs on the host, outside the
sandbox.

## Usage

```bash
enclave preset --save --features +java-dev --allow-domain +repo.maven.apache.org
enclave preset                 # enclave --features +java-dev --allow-domain ...
enclave preset shell           # saved flags first, then the typed arguments
enclave preset --tool codex    # a typed --tool overrides a saved one
enclave preset --show          # matching rules and the resulting command
enclave preset --use review    # a global preset, from any directory
```

`enclave preset [args]` runs `enclave <saved flags> [args]`. Typed arguments
come last, so a typed single-value flag wins and list flags add up. Use it with
commands that take session flags: `run`, `continue`, `resume`, `shell`, and
`config`. `enclave preset config --view source` shows what the saved flags
change.

Without a matching rule it runs `enclave [args]` and says so on stderr.

## Saving

`--save` checks the given flags with `enclave config`, asks where to save
them, writes them, and exits.

| Choice | Saves for |
|--------|-----------|
| This path | The project directory. Default outside git |
| All worktrees | The repository of the project directory. Offered and default in a git repository |
| Every directory | A [global preset](#global-presets). Asks for its name unless `--use` gives one |

`--save=path`, `--save=repo`, and `--save=global` skip the question. Before
writing, `--save` shows the flags it would replace and the rules that keep
precedence here, and asks to confirm. Without a terminal it fails instead of
asking.

Commands, `--` with tool arguments, `enclave config`'s own `--view` and
`--json`, and enclave's
[CLI-only options](https://github.com/eclipse-enclave/enclave/blob/main/docs/configuration.md#cli-only-options)
such as `--allow-sensitive-mounts` or `--rebuild` are rejected.

Paths are saved as typed. A relative `--add-dir ../shared` resolves where the
preset runs, so a repository rule mounts the `shared` next to each worktree.

Saved flags behave like typed ones. A plain list entry replaces the list from
your enclave config, so save `--allow-domain +example.com`, not
`--allow-domain example.com`.

## Presets

A rule holds named flag sets. `default` is used unless `--use` picks another,
for saving and for running:

```bash
enclave preset --save --use ui --features +java-dev,+vnc
enclave preset --use ui
```

Presets are independent: `ui` does not include the flags of `default`.

### Global presets

A global preset is not tied to a directory. Invoke it from anywhere with
`--use`:

```bash
enclave preset --save=global --use review --project-mount readonly
enclave preset --use review
```

A path, repository, or pattern rule that defines the same name takes
precedence. A global `default` applies wherever no rule defines `default`, so
saving globally without `--use` asks for a name instead of using `default`.

## Rules file

`--save` writes `presets.json` in enclave's config directory
(`~/.config/enclave/` on Linux). It is plain JSON for hand edits:

```json
{
  "presets": {
    "review": ["--project-mount", "readonly"]
  },
  "rules": [
    {
      "repo": "~/Git/enclave/enclave",
      "presets": {
        "default": ["--features", "+enclave-dev,+golang-dev"],
        "review": ["--project-mount", "readonly"]
      }
    },
    {
      "path": "~/Git/scratch/*",
      "presets": { "default": ["--tool", "codex"] }
    }
  ]
}
```

| Key | Matches |
|-----|---------|
| `path` | The project directory, the current directory enclave mounts |
| `repo` | The repository of the project directory, named by its main worktree, or by its path if bare. Every worktree and subdirectory matches |

Both take an absolute path or one starting with `~/`. `*`, `?`, or `[...]`
make it a pattern, unless the path is an existing directory, and `*` also
matches `/`. Other keys in a rule, such as a `comment`, are ignored.

The top-level `presets` holds the global presets and matches everywhere.

A session can write the project directory, including its `.git`, so a
repository counts only if its git directory is in the project directory or a
parent, or if it lists a linked worktree there. Otherwise only `path` rules
apply and `--show` says why. Submodules and `--separate-git-dir` checkouts
match `path` rules only.

For a preset, the most specific matching rule that defines it wins:

1. Exact `path`
2. Exact `repo`
3. Patterns, in file order
4. Global presets

A rule without the preset is skipped. A path rule with only `default` still
lets `--use review` fall through to the repository's rule.

## Limitations

- Only `enclave preset` reads the rules. Plain `enclave` and enclave's own
  project config are unaffected.
- `--save` rewrites the file in `jq`'s formatting.
- The rules file widens a session's access like enclave's project config does.
  It stays outside every worktree, so do not mount enclave's config directory
  into a session.
- A session that can write a repository's git directory can list other
  directories as its worktrees, as `git worktree add` does. A directory listed
  that way, and also writable by a session, then matches that repository's
  rules.
