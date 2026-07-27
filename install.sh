#!/usr/bin/env bash
# Dev container dotfiles bootstrap.
#
# Cursor/VS Code clones this repo into every dev container it creates and runs
# this script. Keep everything here idempotent and safe to run in a container
# that knows nothing about it -- it executes in ALL your dev containers, not
# just one.
set -eu

# Re-link persisted Claude Code state in any workspace that has a store.
# The glob simply matches nothing in containers without one.
for bootstrap in /workspaces/*/.claude-home/bootstrap.sh; do
  [ -f "$bootstrap" ] || continue
  echo "dotfiles: running $bootstrap"
  # bash, not sh: bootstrap.sh uses [[ ]] and BASH_SOURCE.
  # Non-fatal: bootstrap refuses to run while a claude process is live, which can
  # happen if the extension launched before dotfiles finished. Don't --force here
  # (that risks a live session); surface it and let the rest of the dotfiles run.
  bash "$bootstrap" --with-cli || \
    echo "dotfiles: bootstrap deferred -- quit Claude Code and run '$bootstrap --with-cli'"
done

# Add further personal setup below (shell config, aliases, git settings...).
# Anything referencing a specific repo should be guarded like the loop above.
