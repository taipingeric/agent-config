# mods-panel

A Claude Code mod: `/mods-panel` opens a panel with an ON/OFF switch for every mod.

- ON mods are listed first, then OFF mods, A to Z within each.
- Press a switch to turn a mod ON or OFF. The choice is saved across sessions.
- After a change, press **⟳ Reload plugins** (or `r`) at the bottom of the panel, or run `/reload-plugins`, to apply it.

## Install

At the prompt of a Claude Code terminal session:

```
/plugin install mods-panel --marketplace taipingeric/agent-config
```

Answer `y` to add the marketplace, then pick a scope (user is first). The mod works right away.

From a shell:

```
claude plugin install mods-panel --marketplace taipingeric/agent-config
```

In the desktop app: click + next to the prompt box, then Plugins, Add marketplace with `taipingeric/agent-config`, then Add plugin.

## Update

```
claude plugin update mods-panel
```

Then run `/reload-plugins` in Claude Code.

## Use

```
/mods-panel
```

## Limits

- A mod that loads before mods-panel cannot be switched OFF by it, and may not show in the list.
- A switch takes effect on the next `/reload-plugins` or restart, not at once.
