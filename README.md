# dotfiles

Personal dev container bootstrap, cloned and run automatically by Cursor/VS Code
in **every** dev container it creates.

Wired up via user settings on the Mac:

```json
"dotfiles.repository": "<your-github-user>/dotfiles",
"dotfiles.installCommand": "install.sh"
```

`install.sh` currently re-links persisted Claude Code state after a dev container
rebuild. It is written to be a no-op in containers that have no
`.claude-home/bootstrap.sh`, so it is safe everywhere.

Contains no secrets — safe as a public repo, which also avoids any clone-auth
question inside containers.
