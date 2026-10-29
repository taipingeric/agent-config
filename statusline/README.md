# statusline

A Claude Code status line that shows:

```
agent-config (main) Opus 5.5 high 88% ctx left 81% wk left [ELI5]
```

Folder, git branch, model, effort, context left, weekly usage left, output style.
Parts with no data yet (like weekly usage before the first reply) are left out.

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
