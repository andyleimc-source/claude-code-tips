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

# ── Line 1: location (host · dir/branch) ──────────────────────────
# Dedup worktrees: dir leaf and branch leaf often say the same thing.
#   native worktree: dir "worktrees/0713-0844" + branch "worktree-0713-0844"
#   task-card wt:    dir ".worktrees/B120"      + branch "task/B120"
# In both, strip the worktree-/task- prefix from the branch; if what's left
# equals the dir leaf, show it once as "wt <name>".
dir_leaf=$(basename "$cwd_full")
branch_leaf=$(echo "$git_branch" | sed 's#^worktree[-/]##; s#^task[-/]##')

loc=""
if [ -n "$git_branch" ] && [ "$branch_leaf" = "$dir_leaf" ] && [ "$git_branch" != "$dir_leaf" ]; then
  # worktree: dir and branch are redundant → collapse to one
  loc=$(printf "\033[33mwt %s\033[0m" "$dir_leaf")
elif [ -n "$git_branch" ] && [ "$git_branch" != "main" ] && [ "$git_branch" != "master" ]; then
  loc=$(printf "\033[33m%s\033[0m \033[32m(%s)\033[0m" "$cwd_base" "$git_branch")
elif [ -n "$cwd_base" ]; then
  loc=$(printf "\033[33m%s\033[0m" "$cwd_base")
fi

line1=""
if [ -n "$host" ]; then
  line1=$(printf "\033[36m%s\033[0m" "$host")
fi
[ -n "$loc" ] && { [ -n "$line1" ] && line1="${line1}${SEP}${loc}" || line1="$loc"; }

# ── Line 2: session (model · ctx · 5h · 7d) ───────────────────────
line2=""
[ -n "$model" ] && line2="$model"

if [ -n "$ctx_part" ]; then
  [ -n "$line2" ] && line2="${line2}${SEP}${ctx_part}" || line2="$ctx_part"
fi

if [ -n "$five_used" ] && [ -n "$five_resets" ]; then
  five_remaining=$(echo "$five_used" | awk '{printf "%.0f", 100 - $1}')
  now=$(date +%s)
  secs=$(( five_resets - now ))
  if [ "$secs" -le 0 ]; then
    line2="${line2}${SEP}5h ready"
  else
    five_reset_time=$(date -r "$five_resets" "+%H:%M" 2>/dev/null || date -d "@$five_resets" "+%H:%M" 2>/dev/null)
    line2="${line2}${SEP}5h ${five_remaining}% ~${five_reset_time}"
  fi
fi

if [ -n "$week_used" ]; then
  week_remaining=$(echo "$week_used" | awk '{printf "%.0f", 100 - $1}')
  line2="${line2}${SEP}7d ${week_remaining}%"
fi

# ── Line 3: 会话标题 ──────────────────────────────────────────────
# CC 给每个会话自动生成一个标题（transcript 里的 ai-title），statusline 的
# 入参 .session_name 就是它——若手动 /rename 过则优先给自定义标题。
# 用途：同时开一堆会话时，一眼看出这个窗口在干什么。太长会挤掉别的信息，截断。
# 覆盖优先：CC 只在第一条消息时起一次标题，之后话题跑偏也不会重算。
# session-title.sh 这个 hook 会让 AI 在跑偏时把新标题写进这里。
sid=$(echo "$input" | jq -r '.session_id // empty')
override=""
if [ -n "$sid" ] && [ -r "$HOME/.claude/session-title/$sid" ]; then
  override=$(head -1 "$HOME/.claude/session-title/$sid")
fi

# 截断按「显示宽度」算不是按字数：中文一个字占两列，纯按字数截中文标题会撑爆窄分屏。
title=$(echo "$input" | jq --arg ov "$override" -r '
  .session_name = (if $ov != "" then $ov else .session_name end) |
  # 宽字符（占两列）的码点区间，jq 不认 0x 写法所以用十进制
  def cw: if . >= 4352 and (. <= 4447
      or (. >= 11904 and . <= 42191)
      or (. >= 44032 and . <= 55203)
      or (. >= 63744 and . <= 64255)
      or (. >= 65072 and . <= 65135)
      or (. >= 65280 and . <= 65376)
      or (. >= 65504 and . <= 65510)) then 2 else 1 end;
  (.session_name // "") as $t
  | if $t == "" then empty else
      ($t | explode
       | reduce .[] as $c ({w:0, out:[], over:false};
           if .over then .
           elif .w + ($c|cw) > 48 then .over = true
           else {w: (.w + ($c|cw)), out: (.out + [$c]), over:false} end)
       | if .over then (.out|implode) + "…" else (.out|implode) end)
    end')
line3=""
if [ -n "$title" ]; then
  line3=$(printf "\033[2;37m%s\033[0m" "$title")
fi

printf "%s\n%s\n" "$line1" "$line2"
[ -n "$line3" ] && printf "%s\n" "$line3"
exit 0
