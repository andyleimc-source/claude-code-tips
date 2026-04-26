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
studio · Opus · ctx 94% · 5h 73% ~18:30 · 7d 82%
```

依次展示：**当前目录名**（基于工作区路径，仅取最后一段）· **git 分支**（仅当 ≠ main/master 时显示，例如 `studio (feat-x)`）· **模型名**（只取首词，如 `Opus` / `Sonnet` / `Haiku`）· **上下文剩余 %** · **5 小时窗口剩余 % + 重置时刻** · **7 天窗口剩余 %**。

#### 步骤 1：保存脚本到 `~/.claude/statusline-command.sh`

```sh
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

SEP=" · "

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

parts="${parts}${SEP}${ctx_part}"

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

## 5. `/inpro` 项目初始化 skill — 多轮会话的共享记忆骨架

### 问题

和 Claude 做持续性项目（比如一个需要多天多轮对话推进的产品），每次开新会话上下文都丢了：上轮解决的 bug、做过的架构决策、当前做到哪、下一步该干嘛——都要人工复述。

### 解决办法

一个 Claude Code skill，在项目目录里一键生成 6 个协作骨架 md，并**内置"文档维护规则"**，让 Claude 在后续会话里主动维护它们：

- `CLAUDE.md` — 项目说明 + 协作规则（Claude 每次启动自动加载）
- `plan.md` — 当前迭代计划 / 里程碑
- `progress.md` — 进度流水（日期倒序）
- `decision.md` — 架构/选型决策记录
- `bug.md` — 已知问题 & 修复
- `handoff.md` — 会话交接（给下一轮 Claude 看）

关键在 `CLAUDE.md` 里写死的维护规则——触发即更、改完直接 commit、不用人工提醒：

- 修完 bug → `bug.md` OPEN 移 FIXED
- 完成 plan 勾选项 / 阶段性进展 → 追加 `progress.md`
- 新的架构/选型决策 → 追加 `decision.md`
- scope 变化 / 里程碑调整 → 改 `plan.md`
- 会话即将结束 → 刷新 `handoff.md`

### 安装

```bash
git clone https://github.com/andyleimc-source/claude-code-tips.git /tmp/cct
mkdir -p ~/.claude/skills
cp -r /tmp/cct/skills/inpro ~/.claude/skills/
```

### 使用

在 Claude Code 里（或任何支持 skill 的客户端）：

```
/inpro                  # 在当前 cwd 初始化
/inpro /path/to/project # 在指定目录初始化
```

或直接说"初始化项目"/"inpro"也会触发。

> **注意**：文档维护规则是**软约束**，靠模型读取 CLAUDE.md 后遵守，不是 harness 层强制。想要强制触发（比如 commit 前阻塞检查）用 hooks（`update-config` skill）。当前规则对日常项目已足够。

---

## 6. 每次回答完播放提示音（Stop hook + 自然语言开关）

### 问题

Claude Code 内置通知（`preferredNotifChannel`）只在**需要你输入**或**完成后窗口失焦**时才响，盯着看的时候不响。想要"每条回答完都叮一声"，并且能在新会话里用一句中文随手开关，不用记命令、不用编辑文件。

### 解决办法

用 **Stop hook + 状态文件**：hook 每轮回答完触发，命令里检查 `~/.claude/.bell-off` 是否存在，存在就静音。再把"自然语言开关"的规则写进 `~/.claude/CLAUDE.md`，让 Claude 在任意新会话里都能听懂"关声音/静音 1 小时/换成 Pop"这类话。

#### 步骤 1：在 `~/.claude/settings.json` 加 Stop hook

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[ ! -f ~/.claude/.bell-off ] && afplay /System/Library/Sounds/Morse.aiff &"
          }
        ]
      }
    ]
  }
}
```

`&` 让播放后台执行，不阻塞 Claude Code。`[ ! -f ... ] &&` 让状态文件存在时直接跳过。

#### 步骤 2：在 `~/.claude/CLAUDE.md` 加自然语言规则

```markdown
## CC 提示音（Stop hook）
- 全局 ~/.claude/settings.json 的 Stop hook 每轮回答完播放 Morse.aiff
- 通过 ~/.claude/.bell-off 状态文件控制开关（文件存在=静音，不存在=响）
- 用户说"关声音/静音/别响了" → `touch ~/.claude/.bell-off`
- 用户说"开声音/恢复提示音" → `rm -f ~/.claude/.bell-off`
- 用户说"静音 N 分钟/小时" → `touch ~/.claude/.bell-off && (sleep <秒数> && rm -f ~/.claude/.bell-off) &`
- 用户问"现在响吗/声音状态" → 检查 ~/.claude/.bell-off 是否存在
- 用户说"换成 X 声"（X ∈ Basso/Blow/Bottle/Frog/Funk/Glass/Hero/Morse/Ping/Pop/Purr/Sosumi/Submarine/Tink） → 改 settings.json hook 命令里的 .aiff 文件名
- 即时生效，不用重启 CC
```

#### 步骤 3：让 hook 生效

新加的 hook 当前会话不会立即生效——按一次 `/hooks` 重载，或重开 Claude Code。状态文件方案的好处是：**之后切换开关都即时生效**，不用再重载。

### 用法

| 你说 | Claude 做的 |
|---|---|
| "关声音" / "静音" / "别响了" | `touch ~/.claude/.bell-off` |
| "开声音" / "恢复提示音" | `rm -f ~/.claude/.bell-off` |
| "静音 1 小时" | `touch` + 后台 `sleep 3600 && rm` |
| "现在响吗" | 检查文件并报告状态 |
| "换成 Pop" | 改 settings.json 里的 `Morse.aiff` 为 `Pop.aiff` |

### 可选声音（macOS 自带）

`Basso` / `Blow` / `Bottle` / `Frog` / `Funk` / `Glass` / `Hero` / `Morse` / `Ping` / `Pop` / `Purr` / `Sosumi` / `Submarine` / `Tink`

预览全部：

```bash
for s in Basso Blow Bottle Frog Funk Glass Hero Morse Ping Pop Purr Sosumi Submarine Tink; do
  echo "▶ $s"; afplay /System/Library/Sounds/$s.aiff; sleep 0.3
done
```

### 让 AI 帮你配

把下面这段 prompt 丢给 Claude Code：

```
帮我配置 Stop hook 提示音功能：
1. 在 ~/.claude/settings.json 的 hooks.Stop 里加一条 command hook，命令是
   [ ! -f ~/.claude/.bell-off ] && afplay /System/Library/Sounds/Morse.aiff &
2. 在 ~/.claude/CLAUDE.md 加一段"CC 提示音"规则，说明用 ~/.claude/.bell-off
   状态文件做开关，用户说"关声音/开声音/静音 N 分钟/换成 X 声"时分别怎么操作。
配完告诉我怎么让当前会话生效。
```

---

## 关注我

<img src="./雷码工坊微信公众号.jpg" alt="雷码工坊笔记微信公众号" width="200" />

**雷码工坊笔记** — 微信扫码关注
