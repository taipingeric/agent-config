#!/bin/bash
# Status line: dir (branch*) +added -removed (uncommitted) session model effort  ctx used  5h left (reset in)  week left  cache  [output style]
input=$(cat)

# One jq run reads every field, joined by the unit separator so empty ones keep their place.
IFS=$'\x1f' read -r dir model effort ctx_left h5_used h5_reset wk_used style session cache_warm cache_expires < <(
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
      (if .prompt_cache then .prompt_cache.warm | tostring else "" end),
      (.prompt_cache.expires_at | int)
    ] | join("\u001f")'
)

branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
if [ -n "$branch" ] && [ -n "$(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null | head -1)" ]; then
  dirty=1
  # Uncommitted lines, staged or not, against the last commit.
  read -r added removed < <(git -C "$dir" --no-optional-locks diff HEAD --numstat 2>/dev/null |
    awk '{ a += $1; r += $2 } END { print a + 0, r + 0 }')
fi

# Fixed RGB values (iTerm2's default palette), not ANSI 31-37, so every terminal
# shows the same colors whatever its theme.
reset=$'\e[0m'
bold_blue=$'\e[1;38;2;39;68;199m'
green=$'\e[38;2;0;194;0m'
orange=$'\e[38;2;217;119;87m'
magenta=$'\e[38;2;192;64;190m'
cyan=$'\e[38;2;0;197;199m'
bright_blue=$'\e[38;2;167;171;242m'
red=$'\e[38;2;180;60;42m'
yellow=$'\e[38;2;199;196;0m'
sand_italic=$'\e[3;38;5;180m'
light_gray=$'\e[38;5;250m'

# Under 50% used: the given color (green by default); under 80%: yellow; else red.
level() {
  if [ "$1" -lt 50 ]; then printf '%s' "${2:-$green}"
  elif [ "$1" -lt 80 ]; then printf '%s' "$yellow"
  else printf '%s' "$red"
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
  if [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"
  elif [ "$m" -gt 0 ]; then printf '%dm' "$m"
  else printf '<1m'
  fi
}

# One limit: label, used %, reset epoch (its countdown is written inside the bar,
# when given), color while under half is used. Shows what is left.
limit() {
  local left=$((100 - $2)) inside=''
  [ -n "$3" ] && inside=$(until_time "$3")
  printf '%s' "$(level "$2" "$4")$1 $(bar "$left" "$inside") ${left}%${reset}"
}

# Segments, in order. The first one also carries the branch and diff counts.
first="${bold_blue}$(basename "$dir")${reset}"
[ -n "$branch" ] && first="$first ${green}($branch${dirty:+${yellow}*${green}})${reset}"
if [ "${added:-0}" -gt 0 ] || [ "${removed:-0}" -gt 0 ]; then
  first="$first ${green}+${added:-0}${reset} ${red}-${removed:-0}${reset}"
fi
segs=("$first")
[ -n "$session" ] && segs+=("${sand_italic}$session${reset}")
[ -n "$model" ] && segs+=("${orange}$model${reset}")
[ -n "$effort" ] && segs+=("${magenta}$effort${reset}")
if [ -n "$ctx_left" ]; then
  ctx_used=$((100 - ctx_left))
  segs+=("$(ctx_level "$ctx_used")ctx $(bar "$ctx_used") ${ctx_used}%${reset}")
fi
[ -n "$h5_used" ] && segs+=("$(limit 5h "$h5_used" "$h5_reset" "$bright_blue")")
[ -n "$wk_used" ] && segs+=("$(limit week "$wk_used" '' "$cyan")")
# Prompt cache: time until it goes cold, or "cold".
if [ "$cache_warm" = true ] && [ -n "$cache_expires" ] && [ "$cache_expires" -gt "$(date +%s)" ]; then
  segs+=("${green}cache $(until_time "$cache_expires")${reset}")
elif [ -n "$cache_warm" ]; then
  segs+=("${light_gray}cache cold${reset}")
fi
[ -n "$style" ] && segs+=("${light_gray}[$style]${reset}")

# Columns a segment takes on screen: color codes dropped, and each 3-byte
# character (CJK) counted as two.
width_of() {
  local plain chars bytes
  plain=$(printf '%s' "$1" | sed $'s/\e\[[0-9;]*m//g')
  chars=${#plain}
  bytes=$(printf '%s' "$plain" | LC_ALL=C wc -c | tr -d ' ')
  printf '%d' $(( chars + (bytes - chars) / 2 ))
}

# Terminal width; STATUSLINE_WIDTH overrides it. The script has no terminal of
# its own, so ask the one Claude Code (our parent) runs in.
term_cols() {
  local tty
  tty=$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')
  case "$tty" in ''|'?'|'??') tty='' ;; *) tty=/dev/$tty ;; esac
  { stty size <"${tty:-/dev/tty}"; } 2>/dev/null | awk '{ print $2 }'
}
cols=${STATUSLINE_WIDTH:-$(term_cols)}
cols=${cols:-${COLUMNS:-0}}
# Keep a few columns spare for Claude Code's own padding.
max=$(( cols > 0 ? cols - 4 : 0 ))

# Fill each line with segments; start a new line when the next one won't fit.
line='' used=0
for seg in "${segs[@]}"; do
  w=$(width_of "$seg")
  if [ -z "$line" ]; then line=$seg used=$w
  elif [ "$max" -gt 0 ] && [ $((used + 1 + w)) -gt "$max" ]; then
    echo "$line"
    line=$seg used=$w
  else line="$line $seg" used=$((used + 1 + w))
  fi
done
echo "$line"
