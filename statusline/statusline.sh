#!/bin/bash
# Status line: dir (branch) model effort  ctx left  wk left  [output style]
input=$(cat)

dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
ctx_left=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty' | cut -d. -f1)
wk_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
style=$(echo "$input" | jq -r '.output_style.name // empty')

branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)

line="$(basename "$dir")"
[ -n "$branch" ] && line="$line ($branch)"
[ -n "$model" ] && line="$line $model"
[ -n "$effort" ] && line="$line $effort"
[ -n "$ctx_left" ] && line="$line ${ctx_left}% ctx left"
[ -n "$wk_used" ] && line="$line $((100 - wk_used))% wk left"
[ -n "$style" ] && line="$line [$style]"

echo "$line"
