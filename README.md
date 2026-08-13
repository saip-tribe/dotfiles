# dotfiles

Personal dev container setup, applied automatically to **every** dev container, with no edits to
any project's `devcontainer.json`.

Contains no tokens, keys or credentials. Public because `dotfiles.repository` clones it
anonymously inside each container, with no credentials available there; the published Feature's
registry visibility is a separate setting and does not depend on this.

Companion repo: **`claude-config-sai`** (private) holds the authored Claude config this mounts.
Full architecture and usage lives in that repo's `SETUP.md`.

## Two mechanisms, and why both are here

Easy to conflate. They differ in exactly the capability that matters.

| | `install.sh` (dotfiles) | `features/` (devcontainer Features) |
|---|---|---|
| Runs | *after* the container exists, inside it | *during* container creation |
| Wired by | `dotfiles.repository` | `dev.containers.defaultFeatures` |
| Install packages, write shell config, symlink | ✅ | ✅ |
| **Create bind mounts** | ❌ | ✅ |

A dotfiles script cannot mount anything: by the time it runs, the container's mounts are fixed.
That is the entire reason the Claude environment needs a Feature.

## Contents

- **`features/claude-env/`** — bind-mounts `~/.claude` (runtime state plus relative symlinks into
  `claude-config-sai`), the config repo itself, `~/.agents`, and `~/.config/graphite`; adds a named
  volume for the standalone CLI. `link.sh` then points `$HOME` at all of it, and additionally
  persists `known_hosts` and gives `gh` a **container-local** config — the one thing it does *not*
  share with the host, because the host's copy is not portable to Linux.

  Every bind uses its **identical host path** for both source and target. That is deliberate and
  load-bearing: a mount target cannot be a variable, and the relative symlinks inside `~/.claude`
  only resolve on both sides if every tree lands at the same absolute path everywhere. Sources are
  spelled out rather than derived from `${localEnv:HOME}`, because substitution inside a *Feature's*
  own mounts is not part of the documented spec.

  The CLI is a *volume*, not part of a bind mount, because it holds platform-specific binaries —
  sharing it with the host would hand one platform the other's.

- **`install.sh`** — re-runs `link.sh` (idempotent, in case the Feature hook has not fired),
  refreshes the managed `.zshrc` block, seeds `~/.config/mise/config.toml`, and runs
  `mise install` to re-materialize global tools if the `/mise-data` volume was recreated.

- **`.zshrc.append`** — rewritten into `~/.zshrc` between markers on every run. Points `HISTFILE`
  at the mounted store so shell history survives a rebuild, and defines `wt` (create a worktree
  under `.worktrees/`, on the workspace bind mount, so it survives a rebuild) and `wtls` (list
  worktrees with the slug each one's dev stack derives from its directory name).

- **`mise-global.toml`** — user-global mise tools. Declarative and tiny, so it is versioned here
  rather than kept in a persisted mount. Only the binaries need persisting, and those live on the
  `/mise-data` volume.

- **`cursor-settings.md`** — the Mac user settings that inject all of the above. The only part of
  the setup no script installs.

## Publishing a Feature change

Bump `version` in `features/<id>/devcontainer-feature.json` and push to `main`;
`.github/workflows/release-features.yml` publishes to `ghcr.io/<owner>/<repo>/<id>`. It can also be
run by hand from the Actions tab (`workflow_dispatch`). Confirm the package is publicly readable
after the first publish — that is a one-time setting, separate from this workflow. Then rebuild the
container to pick the new version up.

## Safe everywhere

Every step is idempotent and guarded. In a container without the Feature, `install.sh` says so and
moves on; if `~/.zshrc` has an unterminated managed block it refuses to rewrite rather than
truncate. `link.sh` warns rather than fails when a mount is absent, refuses to repoint `~/.claude`
out from under a running `claude` process, and moves an unexpected real path aside to a
**timestamped** `.pre-link.<stamp>` rather than deleting it or overwriting an earlier backup.
