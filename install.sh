#!/usr/bin/env bash
# Dev container dotfiles bootstrap.
#
# Cursor/VS Code clones this repo into every dev container it creates and runs this script.
# Keep everything here idempotent and safe to run in a container that knows nothing about
# it -- it executes in ALL your dev containers, not just one.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"

# --- Claude environment ---------------------------------------------------------
# Mounting and linking is done by the claude-env devcontainer Feature (injected via the
# host's dev.containers.defaultFeatures), because a dotfiles script runs after the
# container already exists and so cannot create a bind mount. The call below is only
# belt-and-braces: link.sh is idempotent, and running it here covers the case where the
# Feature's postCreateCommand has not fired yet.
if [ -x /usr/local/share/claude-env/link.sh ]; then
  /usr/local/share/claude-env/link.sh || \
    echo "dotfiles: claude-env link deferred -- quit Claude Code and re-run link.sh"
else
  echo "dotfiles: claude-env Feature not present in this container, skipping"
fi

# --- Shell configuration --------------------------------------------------------
# A marker-delimited block, rewritten whole on each run, so edits to .zshrc.append apply
# cleanly and old content is never duplicated or stranded.
BEGIN='# >>> dotfiles managed block >>>'
END='# <<< dotfiles managed block <<<'

refresh_zshrc_block() {
  [ -f "$HERE/.zshrc.append" ] || return 0
  touch "$HOME/.zshrc"

  # mktemp, not a fixed name: two overlapping runs (a manual re-run while the container-create
  # hook is still going) would otherwise write the same file and one would clobber the other.
  tmp=$(mktemp "$HOME/.zshrc.XXXXXX") || return 1

  # The END guard matters. Without it, a dangling BEGIN -- from an interrupted earlier run or a
  # hand edit -- leaves `skip` set for the rest of the file, so everything after the marker is
  # dropped and awk still exits 0. That silently truncates ~/.zshrc, which `set -e` cannot catch.
  if ! awk -v b="$BEGIN" -v e="$END" '
        $0 == b { skip = 1 }
        skip != 1 { print }
        $0 == e { skip = 0 }
        END { if (skip) exit 1 }
      ' "$HOME/.zshrc" > "$tmp"; then
    rm -f "$tmp"
    echo "dotfiles: ~/.zshrc has an unterminated managed block -- refusing to rewrite it." >&2
    echo "dotfiles: remove the stray '$BEGIN' line by hand, then re-run." >&2
    return 1
  fi

  {
    printf '%s\n' "$BEGIN"
    cat "$HERE/.zshrc.append"
    printf '%s\n' "$END"
  } >> "$tmp"

  mv "$tmp" "$HOME/.zshrc"
  echo "dotfiles: refreshed the managed .zshrc block"
}

# Contained like the claude-env call above, so a failure here does not skip the sections below.
refresh_zshrc_block || echo "dotfiles: .zshrc block not refreshed -- see the message above"

# --- mise global tools ----------------------------------------------------------
# Declarative, so it belongs in this repo rather than in a persisted mount: the whole
# global tool list is a few lines of TOML. Only the binaries need persisting, and those
# live on the /mise-data volume. Written only when absent, so a `mise use -g` in the
# container is not clobbered on the next run.
seed_mise_global() {
  [ -f "$HOME/.config/mise/config.toml" ] && return 0
  [ -f "$HERE/mise-global.toml" ] || return 0
  mkdir -p "$HOME/.config/mise"
  cp "$HERE/mise-global.toml" "$HOME/.config/mise/config.toml"
  echo "dotfiles: seeded ~/.config/mise/config.toml"
}

seed_mise_global || echo "dotfiles: could not seed ~/.config/mise/config.toml"

if command -v mise >/dev/null 2>&1; then
  mise install || echo "dotfiles: mise install failed -- run 'mise install' by hand"
else
  echo "dotfiles: mise not on PATH yet -- global tools materialize on the next 'mise install'"
fi
