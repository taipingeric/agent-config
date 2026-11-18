# statusline

A Claude Code mod that brings the [status line script](../../statusline/README.md) to the desktop app.

The desktop app doesn't draw the `statusLine` setting. This mod runs the same script and draws its line, in color, as a full-width row above the prompt box:

```
agent-config (main*) +120 -30 Opus 5.5 medium ctx ██░░░░░░░░ 18% 5h ██2h52m░░░ 72% week ████████░░ 81% fable ██████░░░░ 63% [ELI5]
```

- It feeds the script the folder, model, effort, context used, 5h and weekly limits, and output style.
- It redraws after each tool call, after each reply step, and every 30 seconds.
- Session name and prompt cache are left out: a mod can't read them.

`bin/statusline.sh` is a copy of `statusline/statusline.sh`. Keep the two the same.

Needs `jq` (`brew install jq` on macOS).

## Install

At the prompt of a Claude Code terminal session:

```
/plugin install statusline --marketplace taipingeric/agent-config
```

Answer `y` to add the marketplace, then pick a scope (user is first).

From a shell:

```
claude plugin install statusline --marketplace taipingeric/agent-config
```

In the desktop app: click + next to the prompt box, then Plugins, Add marketplace with `taipingeric/agent-config`, then Add plugin.

## Update

```
claude plugin update statusline
```

Then run `/reload-plugins` in Claude Code.
