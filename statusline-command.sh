#!/bin/sh
input=$(cat)

# Model: take first word after stripping "Claude " prefix
# e.g. "Claude Opus 4.7 (1M context)" -> "Opus"
model=$(echo "$input" | jq -r '.model.display_name // empty' | sed 's/^Claude //' | awk '{print $1}')

# Context: remaining %
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
cwd_full=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
if [ -z "$cwd_full" ]; then
  cwd_full="$PWD"
fi
cwd_base=$(basename "$(dirname "$cwd_full")")/$(basename "$cwd_full")

# Git branch (suppress all errors; omit if not in a git repo)
git_branch=""
if [ -n "$cwd_full" ]; then
  git_branch=$(git -C "$cwd_full" rev-parse --abbrev-ref HEAD 2>/dev/null)
else
  git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

SEP=" · "

# Machine name (mkp / work …) so it's clear which Mac this session runs on
host=$(scutil --get LocalHostName 2>/dev/null || hostname -s)

# Build output segments
parts=""

# Hide branch when it's main/master (default)
if [ -n "$git_branch" ] && [ "$git_branch" != "main" ] && [ "$git_branch" != "master" ]; then
  parts=$(printf "\033[33m%s\033[0m \033[32m(%s)\033[0m" "$cwd_base" "$git_branch")
elif [ -n "$cwd_base" ]; then
  parts=$(printf "\033[33m%s\033[0m" "$cwd_base")
fi

if [ -n "$model" ]; then
  [ -n "$parts" ] && parts="${parts}${SEP}${model}" || parts="$model"
fi

# Context usage placed next to the model (right side)
if [ -n "$ctx_part" ]; then
  [ -n "$parts" ] && parts="${parts}${SEP}${ctx_part}" || parts="$ctx_part"
fi

if [ -n "$five_used" ] && [ -n "$five_resets" ]; then
  five_remaining=$(echo "$five_used" | awk '{printf "%.0f", 100 - $1}')
  now=$(date +%s)
  secs=$(( five_resets - now ))
  if [ "$secs" -le 0 ]; then
    parts="${parts}${SEP}5h ready"
  else
    five_reset_time=$(date -r "$five_resets" "+%H:%M" 2>/dev/null || date -d "@$five_resets" "+%H:%M" 2>/dev/null)
    parts="${parts}${SEP}5h ${five_remaining}% ~${five_reset_time}"
  fi
fi

if [ -n "$week_used" ]; then
  week_remaining=$(echo "$week_used" | awk '{printf "%.0f", 100 - $1}')
  parts="${parts}${SEP}7d ${week_remaining}%"
fi

if [ -n "$host" ]; then
  host_part=$(printf "\033[36m%s\033[0m" "$host")
  [ -n "$parts" ] && parts="${host_part}${SEP}${parts}" || parts="$host_part"
fi

echo "$parts"
