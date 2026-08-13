# Cursor user settings

These live on the Mac, not in a container, and they are the **only** part of the setup that is
not installed by a script. Without them nothing else fires: they are what injects the Feature
and this dotfiles repo into every dev container.

Apply once per machine: `Cmd+Shift+P` → *Preferences: Open User Settings (JSON)*.

## Required — the devcontainer wiring

```json
{
  "dotfiles.repository": "saip-tribe/dotfiles",
  "dotfiles.installCommand": "install.sh",

  "dev.containers.defaultExtensions": ["anthropic.claude-code"],
  "dev.containers.defaultFeatures": {
    "ghcr.io/saip-tribe/dotfiles/claude-env:1": {}
  }
}
```

| Setting | Does what |
|---|---|
| `dotfiles.repository` | Cursor clones this repo to `~/dotfiles` **inside** every container and runs `installCommand`. Not a Mac path. |
| `dev.containers.defaultExtensions` | Reinstalls the Claude Code extension in every container. Extensions are not persisted — they are re-fetched, which is why a rebuild needs network. |
| `dev.containers.defaultFeatures` | The important one. Adds the `claude-env` Feature to every container, which is the only way to inject a **bind mount** without editing a project's `devcontainer.json`. A dotfiles script cannot do it: by the time it runs, the container's mounts are fixed. |

Verified supported by Cursor's `anysphere.remote-containers` 1.0.39. There is no global
"defaultMounts" equivalent — hence the Feature.

## Personal Claude Code preferences

Not required by the architecture; recorded so a new machine matches.

```json
{
  "claudeCode.preferredLocation": "panel",
  "claudeCode.selectedModel": "opus[1m]",
  "claudeCode.useCtrlEnterToSend": true
}
```

Two to set deliberately rather than copy blindly:

- **`claudeCode.environmentVariables`** — deliberately unset. Settings Sync uploads whatever is
  placed here, so it is not a place for credentials of any kind. Configure authentication in
  `~/.claude/settings.json`, which is not synced.
- **`claudeCode.allowDangerouslySkipPermissions`** — applies at *user* scope, so it affects every
  window and every repo rather than one project. Omitted on purpose.

## Settings Sync

If Settings Sync is on, everything above travels automatically and this file is just a reference.
