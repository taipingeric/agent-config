# statusline

A Claude Code status line that shows:

```
agent-config (main*) +120 -30 Survivor 開發 Opus 5.5 medium ctx ██░░░░░░░░ 18% 5h ██2h52m░░░ 72% week ████████░░ 81% [ELI5]
```

- Folder, git branch (a yellow `*` when there are uncommitted changes)
- Uncommitted lines added and removed, as `git diff HEAD` counts them (hidden when there are none)
- Session name, in italics (when the session has one)
- Model, effort
- `ctx`: context **used**, in soft colors from green to rose as it fills
- `5h`: 5-hour limit **left**, with the time until it resets written inside the bar
- `week`: weekly limit **left**
- `5h` and `week` turn yellow, then red, as they run low
- `cache`: time until the prompt cache goes cold (green), or `cache cold` (gray)
- Output style in `[ ]`, in light gray

When the line is wider than your terminal, it wraps onto more lines, never splitting a part in two. To force a width, set `STATUSLINE_WIDTH` (e.g. `"command": "STATUSLINE_WIDTH=100 bash ~/.claude/statusline.sh"`).

Bars are drawn with background colors. Parts with no data yet (like the limits before the first reply) are left out.

## Install

Needs `jq` (`brew install jq` on macOS).

1. Download the script:

```
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/taipingeric/agent-config/main/statusline/statusline.sh
```

2. Add this to `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline.sh",
  "refreshInterval": 60
}
```

`refreshInterval` redraws it every 60 seconds, so the 5h and cache countdowns keep moving while you're idle.

It shows after your next message. If not, restart Claude Code.
