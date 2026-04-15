# Claude Code Tips

Claude Code 实用技巧集合。每个技巧包含问题描述和可直接发给 AI 执行的 prompt。

---

## 1. 禁用 Workspace Trust 提示

### 问题

每次启动 Claude Code 时弹出 "Quick safety check: Is this a project you created or one you trust?" 提示，选了 "Yes" 后下次仍然出现。

### 解决办法

将以下 prompt 发送给 Claude Code 执行：

```
帮我修改 ~/.claude.json，把 projects 里所有目录的 hasTrustDialogAccepted 设为 true，这样以后不会再弹 workspace trust 提示。
```

---

## 2. 开启 Bypass Permissions 模式

### 问题

Claude Code 默认每次执行文件编辑、命令运行等操作都需要手动确认，操作效率低。希望跳过所有权限确认，让 Claude Code 自动执行。

### 解决办法

将以下 prompt 发送给 Claude Code 执行：

```
帮我修改 ~/.claude/settings.json，在 permissions 里把 defaultMode 设为 "bypassPermissions"，同时把 skipDangerousModePermissionPrompt 设为 true。
```

---

## 3. 配置底部状态栏显示用量信息和当前模型

### 问题

Claude Code 底部状态栏默认没有显示有用信息，无法直观看到当前使用的模型、上下文窗口用量、5 小时滚动用量和每周用量。

### 解决办法

状态栏通过 `~/.claude/settings.json` 里的 `statusLine` 配置执行一个 shell 脚本，脚本从 stdin 读 JSON，输出一行字符串渲染到底部。

**效果：**

```
studio (main) | Sonnet 4.6 | ctx 94% | 5h 73% ~18:30 | 7d 82%
```

依次展示：**当前目录名**（基于工作区路径，仅取最后一段）· **git 分支**（不在仓库则不显示）· **模型名**（去掉 `Claude ` 前缀）· **上下文剩余 %** · **5 小时窗口剩余 % + 重置时刻** · **7 天窗口剩余 %**。

#### 步骤 1：保存脚本到 `~/.claude/statusline-command.sh`

```sh
#!/bin/sh
input=$(cat)

# Model: strip "Claude " prefix, e.g. "Claude Sonnet 4.6" -> "Sonnet 4.6"
model=$(echo "$input" | jq -r '.model.display_name // empty' | sed 's/Claude //')

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
if [ -n "$cwd_full" ]; then
  cwd_base=$(basename "$cwd_full")
else
  cwd_base=$(basename "$PWD")
fi

# Git branch (suppress errors; omit if not in a git repo)
git_branch=""
if [ -n "$cwd_full" ]; then
  git_branch=$(git -C "$cwd_full" rev-parse --abbrev-ref HEAD 2>/dev/null)
else
  git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# Build output segments
parts=""

if [ -n "$git_branch" ]; then
  parts=$(printf "\033[33m%s\033[0m \033[32m(%s)\033[0m" "$cwd_base" "$git_branch")
elif [ -n "$cwd_base" ]; then
  parts=$(printf "\033[33m%s\033[0m" "$cwd_base")
fi

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
```

#### 步骤 2：在 `~/.claude/settings.json` 里注册

```json
{
  "statusLine": {
    "type": "command",
    "command": "sh /Users/你的用户名/.claude/statusline-command.sh"
  }
}
```

#### 步骤 3：赋执行权限

```bash
chmod +x ~/.claude/statusline-command.sh
```

保存后重开一个 Claude Code 会话即可生效。依赖 `jq`（macOS：`brew install jq`）。

> 如果只想让 AI 帮你配好，可以把下面这段 prompt 丢给 Claude Code，它会调用 `statusline-setup` agent 自动写入脚本并改 settings：
>
> ```
> 用 statusline-setup agent 帮我配置状态栏，显示：目录名（仅最后一段）、git 分支、模型名、上下文剩余 %、5 小时窗口剩余 % 与重置时刻、7 天窗口剩余 %。
> ```

---

## 4. 全局搜索并恢复历史会话

### 问题

Claude Code 内置的 `/resume` 和 `--resume` 只显示当前项目下的 session，跨项目查找历史对话很不方便，且最多只显示 50 条。

### 解决办法

安装 [cc-sessions](https://github.com/chronologos/cc-sessions) 工具，它可以搜索所有项目下的历史会话，支持预览和全文检索，选中后直接启动 Claude Code 并恢复该会话。

**安装：**

```bash
# macOS Apple Silicon
curl -L https://github.com/chronologos/cc-sessions/releases/latest/download/cc-sessions-macos-arm64 -o ~/.local/bin/cc-sessions
chmod +x ~/.local/bin/cc-sessions
xattr -cr ~/.local/bin/cc-sessions && codesign -s - -f ~/.local/bin/cc-sessions
```

**添加快捷别名（推荐）：**

```bash
echo "alias cs='cc-sessions'" >> ~/.zshrc
source ~/.zshrc
```

**使用：**

```bash
cs          # 打开交互式 picker，上下键选择会话，回车恢复
cs --list   # 纯列表模式查看所有会话
```

在 picker 界面中按 `ctrl+s` 可全文搜索对话内容。

---

## 关注我

<img src="./雷码工坊微信公众号.jpg" alt="雷码工坊笔记微信公众号" width="200" />

**雷码工坊笔记** — 微信扫码关注
