#!/bin/bash
# Status line: dir (branch*) +added -removed session model effort  ctx used  5h left (reset in)  week left  [output style]
input=$(cat)

# One jq run reads every field, joined by the unit separator so empty ones keep their place.
IFS=$'\x1f' read -r dir model effort ctx_left h5_used h5_reset wk_used style session added removed < <(
  echo "$input" | jq -r '
    def int: if . == null then "" else floor | tostring end;
    [ (.workspace.current_dir // .cwd // ""),
      (.model.display_name // ""),
      (.effort.level // ""),
      (.context_window.remaining_percentage | int),
      (.rate_limits.five_hour.used_percentage | int),
      (.rate_limits.five_hour.resets_at | int),
      (.rate_limits.seven_day.used_percentage | int),
      (.output_style.name // ""),
      (.session_name // ""),
      (.cost.total_lines_added | int),
      (.cost.total_lines_removed | int)
    ] | join("\u001f")'
)

branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
if [ -n "$branch" ] && [ -n "$(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null | head -1)" ]; then
  dirty=1
fi

reset=$'\e[0m'
bold_blue=$'\e[1;34m'
green=$'\e[32m'
orange=$'\e[38;2;217;119;87m'
magenta=$'\e[35m'
cyan=$'\e[36m'
bright_blue=$'\e[94m'
red=$'\e[31m'
yellow=$'\e[33m'
sand_italic=$'\e[3;38;5;180m'
light_gray=$'\e[38;5;250m'

# Under 50% used: the given color (green by default); under 80%: yellow; else red.
level() {
  if [ "$1" -lt 50 ]; then printf '%s' "${2:-$'\e[32m'}"
  elif [ "$1" -lt 80 ]; then printf '\e[33m'
  else printf '\e[31m'
  fi
}

# Context used, in five soft stages: green, olive, sand, clay, rose.
ctx_level() {
  if [ "$1" -lt 20 ]; then printf '\e[38;5;71m'
  elif [ "$1" -lt 40 ]; then printf '\e[38;5;107m'
  elif [ "$1" -lt 60 ]; then printf '\e[38;5;179m'
  elif [ "$1" -lt 80 ]; then printf '\e[38;5;173m'
  else printf '\e[38;5;167m'
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

# Time from now until epoch seconds, as 2h05m or 12m.
until_time() {
  local s=$(( $1 - $(date +%s) ))
  [ "$s" -lt 0 ] && s=0
  local h=$((s / 3600)) m=$(((s % 3600) / 60))
  if [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"; else printf '%dm' "$m"; fi
}

# One limit: label, used %, reset epoch (its countdown is written inside the bar,
# when given), color while under half is used. Shows what is left.
limit() {
  local left=$((100 - $2)) inside=''
  [ -n "$3" ] && inside=$(until_time "$3")
  printf '%s' "$(level "$2" "$4")$1 $(bar "$left" "$inside") ${left}%${reset}"
}

line="${bold_blue}$(basename "$dir")${reset}"
[ -n "$branch" ] && line="$line ${green}($branch${dirty:+${yellow}*${green}})${reset}"
if [ "${added:-0}" -gt 0 ] || [ "${removed:-0}" -gt 0 ]; then
  line="$line ${green}+${added:-0}${reset} ${red}-${removed:-0}${reset}"
fi
[ -n "$session" ] && line="$line ${sand_italic}$session${reset}"
[ -n "$model" ] && line="$line ${orange}$model${reset}"
[ -n "$effort" ] && line="$line ${magenta}$effort${reset}"
if [ -n "$ctx_left" ]; then
  ctx_used=$((100 - ctx_left))
  line="$line $(ctx_level "$ctx_used")ctx $(bar "$ctx_used") ${ctx_used}%${reset}"
fi
[ -n "$h5_used" ] && line="$line $(limit 5h "$h5_used" "$h5_reset" "$bright_blue")"
[ -n "$wk_used" ] && line="$line $(limit week "$wk_used" '' "$cyan")"
[ -n "$style" ] && line="$line ${light_gray}[$style]${reset}"

echo "$line"
