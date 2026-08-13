#!/usr/bin/env bash
# Point $HOME at the bind-mounted host directories. Runs as the remote user at container create,
# via this Feature's postCreateCommand. Safe to re-run by hand:
#
#   /usr/local/share/claude-env/link.sh
#   /usr/local/share/claude-env/link.sh --force   # relink even with claude running
#
# Symlinks rather than an env var such as CLAUDE_CONFIG_DIR: the editor extension spawns its
# bundled binary straight from the extension host, so it never inherits integrated-terminal
# environment. Symlinks apply whatever launches Claude.
#
# The paths below are the container mount targets, and they are deliberately identical to the host
# paths. A devcontainer mount target cannot be a variable, and the relative symlinks inside
# ~/.claude (skills -> ../Github/claude-config-sai/skills) only resolve on both sides if every tree
# lands at the same absolute path everywhere. Do not "tidy" these into /var or $HOME.
set -euo pipefail

HOST_HOME=/Users/saip-tribe
CLAUDE="$HOST_HOME/.claude"
CONFIG="$HOST_HOME/Github/claude-config-sai"
# Must match the volume target in devcontainer-feature.json. Hardcoded in both places rather than
# derived from $HOME, because variable substitution inside a Feature's own mounts is not part of
# the documented spec.
CLI_DIR=/home/vscode/.local/share/claude

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '  %s\n' "$*"; }

# Never fail container creation over a missing mount: that is a misconfigured host, not a broken
# build. Warn loudly instead -- without this the symptom is Claude quietly reporting no skills and
# no history, which reads as a Claude bug rather than an absent mount.
if [[ ! -d "$CLAUDE" ]]; then
  echo "WARNING: the Claude store is not mounted at $CLAUDE." >&2
  echo "WARNING: skills, commands, sessions and credentials are all unavailable." >&2
  echo "WARNING: check dev.containers.defaultFeatures in the host's editor settings." >&2
  exit 0
fi
[[ -d "$CONFIG/skills" ]] || echo "WARNING: config repo not mounted at $CONFIG -- skills and commands will dangle." >&2
# The config repo's skills/agent-browser is a relative link out to an externally installed copy;
# it needs this mount to resolve, and nothing here to link.
[[ -d "$HOST_HOME/.agents" ]] || echo "WARNING: $HOST_HOME/.agents not mounted -- the agent-browser skill will dangle." >&2

# Repointing ~/.claude under a live claude process can lose the tail of that session. Compare the
# actual target, not merely "is it a symlink" -- a symlink to the wrong place still needs fixing,
# and would otherwise slip past this guard and be repointed anyway.
if pgrep -x claude >/dev/null 2>&1 && [[ $FORCE -eq 0 ]] \
   && [[ "$(readlink "$HOME/.claude" 2>/dev/null)" != "$CLAUDE" ]]; then
  echo "A 'claude' process is running. Quit Claude Code and re-run, or pass --force." >&2
  exit 1
fi

# The host side is canonical -- it exists before any container does. So there is nothing to seed:
# an unexpected real path at the target is moved aside, never merged or deleted. The backup is
# timestamped, so a second collision cannot silently destroy the first one's contents.
link() {
  local home_path="$1" target="$2" label="$3"

  if [[ -L "$home_path" && "$(readlink "$home_path")" == "$target" ]]; then
    say "$label: already linked"
    return
  fi

  if [[ -e "$home_path" && ! -L "$home_path" ]]; then
    local backup="${home_path}.pre-link.$(date +%Y%m%d%H%M%S)"
    say "$label: real path in \$HOME, moving to $(basename "$backup")"
    mv "$home_path" "$backup"
  fi

  mkdir -p "$(dirname "$home_path")"
  ln -sfn "$target" "$home_path"
  say "$label: -> $target"
}

echo "claude-env: linking \$HOME to the mounted host trees"

link "$HOME/.claude"          "$CLAUDE"                  ".claude"
# Kept inside the mounted directory on purpose: bind-mounting a single file breaks the moment
# something rewrites it whole, which a directory mount survives.
link "$HOME/.claude.json"     "$CLAUDE/claude.json"      ".claude.json"

# Graphite config is shared with the host, so one `gt auth` serves both.
link "$HOME/.config/graphite" "$HOST_HOME/.config/graphite" "graphite config"

# gh is deliberately container-local: the host's config is not portable to Linux, so sharing it
# would leave gh unauthenticated here. Persisted in the store so it survives rebuilds; expect one
# `gh auth login` in a new container.
mkdir -p "$CLAUDE/tools/gh"
chmod 700 "$CLAUDE/tools/gh"
link "$HOME/.config/gh" "$CLAUDE/tools/gh" "gh config (container-local)"

# Persist host-key trust across rebuilds, rather than StrictHostKeyChecking=accept-new which
# re-trusts blindly every time. Caveat: `ssh-keygen -R` rewrites this file whole and would replace
# the symlink with a regular file; re-run this script if that happens.
mkdir -p "$CLAUDE/ssh" "$HOME/.ssh"
touch "$CLAUDE/ssh/known_hosts"
link "$HOME/.ssh/known_hosts" "$CLAUDE/ssh/known_hosts" "known_hosts"

# Shell history is NOT symlinked. zsh trims the file by writing a temp file and renaming it over
# the target, which replaces a symlink with a regular file and silently stops persisting. The
# managed .zshrc block sets HISTFILE to the store path directly instead.
mkdir -p "$CLAUDE/shell"

# ~/.config/mise is not linked either. The global tool list is a few lines of declarative TOML, so
# it is authored config: install.sh seeds it from mise-global.toml. The binaries live on a volume.

# The standalone CLI lives on a named volume -- platform-specific binaries must not be shared with
# the host -- so only the PATH shim needs recreating after a rebuild.
if [[ "$HOME" != "/home/vscode" ]]; then
  say "note: \$HOME is $HOME, but the CLI volume is mounted at $CLI_DIR"
fi
latest="$(ls -1 "$CLI_DIR/versions" 2>/dev/null | sort -V | tail -1 || true)"
if [[ -n "$latest" ]]; then
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$CLI_DIR/versions/$latest" "$HOME/.local/bin/claude"
  say "CLI shim: ~/.local/bin/claude -> $latest"
else
  say "CLI: not on the volume yet (install once; it then survives rebuilds)"
fi

echo "Done."
