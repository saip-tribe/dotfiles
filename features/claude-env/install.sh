#!/usr/bin/env bash
# Feature build step. Runs as root while the image is built, with this directory as cwd.
# All it does is stage link.sh where the Feature's postCreateCommand can find it —
# the real work happens at container-create time, as the remote user.
set -eu

install -d -m 0755 /usr/local/share/claude-env
install -m 0755 link.sh /usr/local/share/claude-env/link.sh

echo "claude-env: staged link.sh for postCreate"
