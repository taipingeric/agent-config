# agent-config
my agent configs

## Mods

Claude Code mods, one folder each under `mods/`.

| Mod | What it does |
| --- | --- |
| `mods-panel` | `/mods-panel` opens a panel with an ON/OFF switch for every mod. Press a switch, then run `/reload-plugins` to apply. |

### Install

At the prompt of a Claude Code terminal session:

```
/plugin install mods-panel --marketplace taipingeric/agent-config
```

Answer `y` to add the marketplace, then pick a scope (user is first).

From a shell:

```
claude plugin install mods-panel --marketplace taipingeric/agent-config
```
