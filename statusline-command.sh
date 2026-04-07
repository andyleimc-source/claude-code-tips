#!/bin/sh
input=$(cat)

# Model: strip "Claude " prefix, e.g. "Claude Sonnet 4.6" -> "Sonnet 4.6"
model=$(echo "$input" | jq -r '.model.display_name // empty' | sed 's/Claude //')

# Context: remaining % (not used)
ctx_remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
if [ -n "$ctx_remaining" ]; then
  ctx=$(echo "$ctx_remaining" | awk '{printf "%.0f", $1}')
  ctx_part="ctx ${ctx}%"
else
  ctx_part="ctx --"
fi

# 5-hour rate limit
five_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

# 7-day rate limit
week_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Current working directory (basename only)
cwd_full=$(echo "$input" | jq -r '.cwd // empty')
if [ -n "$cwd_full" ]; then
  cwd_base=$(basename "$cwd_full")
else
  cwd_base=""
fi

# Build output segments
parts=""

[ -n "$cwd_base" ] && parts="$cwd_base"

if [ -n "$model" ]; then
  [ -n "$parts" ] && parts="${parts} | ${model}" || parts="$model"
fi

parts="${parts} | ${ctx_part}"

if [ -n "$five_used" ] && [ -n "$five_resets" ]; then
  five_remaining=$(echo "$five_used" | awk '{printf "%.0f", 100 - $1}')
  now=$(date +%s)
  secs=$(( five_resets - now ))
  if [ "$secs" -le 0 ]; then
    parts="${parts} | 5h ready"
  else
    five_reset_time=$(date -r "$five_resets" "+%H:%M" 2>/dev/null || date -d "@$five_resets" "+%H:%M" 2>/dev/null)
    parts="${parts} | 5h ${five_remaining}% ~${five_reset_time}"
  fi
fi

if [ -n "$week_used" ]; then
  week_remaining=$(echo "$week_used" | awk '{printf "%.0f", 100 - $1}')
  parts="${parts} | 7d ${week_remaining}%"
fi

echo "$parts"
