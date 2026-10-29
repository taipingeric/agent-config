#!/bin/bash
# Status line: dir (branch*) model effort  ctx used  5h left (reset in)  wk left ↻reset  [output style]
input=$(cat)

dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
ctx_left=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty' | cut -d. -f1)
h5_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
h5_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
wk_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
wk_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
style=$(echo "$input" | jq -r '.output_style.name // empty')

branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
if [ -n "$branch" ] && [ -n "$(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null | head -1)" ]; then
  branch="$branch*"
fi

reset=$'\e[0m'
bold_blue=$'\e[1;34m'
green=$'\e[32m'
orange=$'\e[38;2;217;119;87m'
magenta=$'\e[35m'
cyan=$'\e[36m'
bright_blue=$'\e[94m'
dim=$'\e[2m'

# Under 50% used: the given color (green by default); under 80%: yellow; else red.
level() {
  if [ "$1" -lt 50 ]; then printf '%s' "${2:-$'\e[32m'}"
  elif [ "$1" -lt 80 ]; then printf '\e[33m'
  else printf '\e[31m'
  fi
}

# Context used, in five stages: green, lime, yellow, orange, red.
ctx_level() {
  if [ "$1" -lt 20 ]; then printf '\e[38;5;46m'
  elif [ "$1" -lt 40 ]; then printf '\e[38;5;154m'
  elif [ "$1" -lt 60 ]; then printf '\e[38;5;226m'
  elif [ "$1" -lt 80 ]; then printf '\e[38;5;208m'
  else printf '\e[38;5;196m'
  fi
}

# A 10-cell bar filled to the given percent.
# Cells are painted with background color, not █/░ glyphs, so a text written
# centered inside the bar sits at the same height: filled cells take the current
# color reversed, the rest a gray background.
bar() {
  local filled=$(( ($1 + 5) / 10 )) text=$2 out='' i ch
  local start=$(( (10 - ${#text}) / 2 ))
  for ((i = 0; i < 10; i++)); do
    ch=' '
    [ -n "$text" ] && [ "$i" -ge "$start" ] && [ "$i" -lt $((start + ${#text})) ] && ch=${text:$((i - start)):1}
    if [ "$i" -lt "$filled" ]; then out+=$'\e[7m'"$ch"$'\e[27m'
    else out+=$'\e[48;5;238m'"$ch"$'\e[49m'
    fi
  done
  printf '%s' "$out"
}

# Epoch seconds as local time in the given format (macOS date, then GNU date),
# in English whatever the system language.
at() {
  LC_ALL=C date -r "$1" "+$2" 2>/dev/null || LC_ALL=C date -d "@$1" "+$2" 2>/dev/null
}

# Time from now until epoch seconds, as 2h05m or 12m.
until_time() {
  local s=$(( $1 - $(date +%s) ))
  [ "$s" -lt 0 ] && s=0
  local h=$((s / 3600)) m=$(((s % 3600) / 60))
  if [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"; else printf '%dm' "$m"; fi
}

# One limit: label, used %, reset epoch, reset time format (or "until" for a
# countdown written inside the bar), color while under half is used.
# Shows what is left.
limit() {
  local left=$((100 - $2)) out inside=''
  [ -n "$3" ] && [ "$4" = until ] && inside=$(until_time "${3%.*}")
  out="$(level "$2" "$5")$1 $(bar "$left" "$inside") ${left}%${reset}"
  [ -n "$3" ] && [ "$4" != until ] && out="$out ${dim}↻$(at "${3%.*}" "$4")${reset}"
  printf '%s' "$out"
}

line="${bold_blue}$(basename "$dir")${reset}"
[ -n "$branch" ] && line="$line ${green}($branch)${reset}"
[ -n "$model" ] && line="$line ${orange}$model${reset}"
[ -n "$effort" ] && line="$line ${magenta}$effort${reset}"
if [ -n "$ctx_left" ]; then
  ctx_used=$((100 - ctx_left))
  line="$line $(ctx_level "$ctx_used")ctx $(bar "$ctx_used") ${ctx_used}%${reset}"
fi
[ -n "$h5_used" ] && line="$line $(limit 5h "$h5_used" "$h5_reset" until "$bright_blue")"
[ -n "$wk_used" ] && line="$line $(limit wk "$wk_used" "$wk_reset" '%a %H:%M' "$cyan")"
[ -n "$style" ] && line="$line ${dim}[$style]${reset}"

echo "$line"
