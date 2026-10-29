# statusline

A Claude Code status line that shows:

```
agent-config (main*) Opus 5.5 medium ctx ██░░░░░░░░ 18% 5h ██2h52m░░░ 72% wk ████████░░ 81% ↻Mon 06:00 [ELI5]
```

- Folder, git branch (`*` when there are uncommitted changes), model, effort
- `ctx`: context **used**, colored green → light green → yellow → orange → red as it fills
- `5h`: 5-hour limit **left**, with the time until it resets written inside the bar
- `wk`: weekly limit **left**, with the reset day and time (`↻`)
- `5h` and `wk` turn yellow, then red, as they run low
- Output style in `[ ]`

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
  "command": "bash ~/.claude/statusline.sh"
}
```

It shows after your next message. If not, restart Claude Code.
