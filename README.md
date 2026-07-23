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
- **用户说 `bye` / `bb` / `88` / `再见` / `下班` / `收工` / `拜拜`**（结束本轮对话的触发词）→ 按需把本轮重要信息落盘到上述 5 个 md（不存在就跳过，不要新建），写完直接 commit；回复只说"已落盘"，不要"晚安/收工愉快"——用户可能转头就开新对话
- **任何改动做完直接 `git commit`，不用问**；如果当前目录还不是 git 仓库，先 `git init` 再提交

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

## 7. 用 `y` 命令打开 yazi 文件管理器，退出时自动 cd 到最后停留的目录

### 问题

终端里在多层目录间切换很啰嗦。[yazi](https://github.com/sxyazi/yazi) 是一个超快的 TUI 文件管理器（Rust 写的，预览图片/视频/PDF），但它默认退出后 shell 还停在原来的目录——浏览半天找到目标目录，还得手动 `cd` 一次。

### 解决办法

包一个 shell 函数 `y`：启动 yazi 时把"退出时所在目录"写到临时文件，函数读出来再 `cd` 过去。yazi 官方推荐用法。

#### 步骤 1：安装 yazi（macOS）

```bash
brew install yazi ffmpeg sevenzip jq poppler fd ripgrep fzf zoxide resvg imagemagick font-symbols-only-nerd-font
```

`yazi` 是核心，其余是预览/搜索依赖（PDF、图片、字体图标等），按需装。

#### 步骤 2：在 `~/.zshrc` 加 `y` 函数

```sh
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}
```

bash 用户把上面这段放到 `~/.bashrc`，语法兼容。

#### 步骤 3：生效

```bash
source ~/.zshrc
```

### 使用

```bash
y              # 在当前目录打开 yazi
y ~/projects   # 直接在指定目录打开
```

进 yazi 后常用键：`hjkl` 移动 / `space` 选中 / `enter` 打开 / `q` 退出 / `cd` 输入路径跳转。退出后 shell 已自动 `cd` 到 yazi 最后停留的目录。

### 让 AI 帮你配

```
帮我装 yazi 并在 ~/.zshrc 里加一个 y() 函数，要求退出 yazi 后 shell 自动 cd 到 yazi 最后停留的目录。
```

---

## 8. `facd` 模糊跳目录 —— 输入片段 + fzf 选择器（带创建/修改时间和大小预览）

### 问题

在几十个项目目录间切换，`cd ~/Documents/coding/xxx/yyy` 打全路径太累，`zoxide` 又只认你去过的目录、认不准同名的新目录。想要：**输入目录名的一个片段，从常用根目录里模糊搜出所有匹配，用 fzf 上下键选**，右侧还能顺手看到这个目录的创建/修改时间和体积，避免进错版本。

### 解决办法

在 `~/.zshrc` 里包一组函数：`facd`（从固定几个根搜）/ `fcd`（只搜当前目录下）/ `mkcd`（建了就进）。核心是 `find` 出候选喂给 `fzf`，预览窗口用 `stat` + `du` 懒加载显示信息。

**效果：** `facd studio` → 列出所有名字含 `studio` 的目录，回车进；只有一个匹配时直接跳、不弹选择器。

#### 步骤 1：装依赖（macOS）

```bash
brew install fzf
```

#### 步骤 2：在 `~/.zshrc` 加函数

```sh
# Fuzzy cd helpers — fzf 选择器(↑↓ 选 / Enter 进 / Esc 取消)
# 右侧预览含:创建时间 / 修改时间 / 文件夹大小(按高亮项懒加载,du 不卡)
_FACD_PREVIEW='d={2};
  stat -f "创建   %SB%n修改   %Sm" -t "%Y-%m-%d %H:%M" "$d";
  printf "大小   "; du -sh "$d" 2>/dev/null | cut -f1'
_facd_core() {
  local pattern="${@[-1]}" roots=("${@[1,-2]}")
  local dirs=() root rdir rdepth
  # 每个根默认深度 3;写成 "<路径>::<深度>" 可单独指定(如 home 根只搜深度 1,避开 Library/node_modules)
  for root in "${roots[@]}"; do
    rdir="${root%%::*}"; rdepth=3
    [[ "$root" == *"::"* ]] && rdepth="${root##*::}"
    while IFS= read -r line; do dirs+=("$line"); done \
      < <(find "$rdir" -maxdepth "$rdepth" -type d -iname "*$pattern*" 2>/dev/null)
  done
  case ${#dirs[@]} in
    0) echo "没找到匹配 '$pattern' 的目录"; return 1 ;;
    1) cd "${dirs[1]}"; return ;;
  esac
  local lines=() d short
  for d in "${dirs[@]}"; do
    short="$(basename "$(dirname "$d")")/$(basename "$d")"
    lines+=("$short"$'\t'"$d")
  done
  local sel
  sel="$(printf '%s\n' "${lines[@]}" | fzf --delimiter=$'\t' --with-nth=1 \
    --height=80% --reverse --ansi --prompt='cd> ' \
    --preview "$_FACD_PREVIEW" --preview-window='right,46%,wrap')"
  [ -n "$sel" ] && cd "${sel#*$'\t'}"
}
# 改成你自己的常用根目录;"$HOME::1" 表示 home 只搜一层,避开 Library
facd() { _facd_core ~/coding ~/Documents ~/Desktop "$HOME::1" "$1"; }
fcd()  { _facd_core . "$1"; }
mkcd() { mkdir -p "$1" && cd "$1"; }
```

`_facd_core` 接受「若干根 + 最后一个参数是搜索词」，每个根默认往下搜 3 层；某个根写成 `路径::层数` 可单独限定深度（例子里 `$HOME::1` 让家目录只搜一层，避开 `Library`、`node_modules` 这种深坑）。`fzf` 里只显示 `父目录/目录名` 两段，右侧预览懒加载 `stat`（创建/修改时间）和 `du`（体积）。

#### 步骤 3：生效

```bash
source ~/.zshrc
```

### 使用

```bash
facd studio    # 从 ~/coding ~/Documents ~/Desktop 和 home(1层) 里模糊找含 "studio" 的目录
fcd src        # 只在当前目录下往下找含 "src" 的目录
mkcd ~/tmp/new # 新建目录并直接进去
```

唯一匹配直接跳；多个匹配弹 fzf，↑↓ 选、Enter 进、Esc 取消；进之前右侧就能看到目标目录的时间和大小。

### 让 AI 帮你配

```
帮我在 ~/.zshrc 里加一组 fzf 模糊 cd 函数：facd 从 ~/coding ~/Documents ~/Desktop
和 home(只搜一层) 里按名字片段找目录，用 fzf 选择器让我上下键选，右侧预览显示该目录
的创建时间、修改时间和体积；只有一个匹配时直接 cd 过去。另外再加 fcd(只搜当前目录下)
和 mkcd(建了就进)。依赖 fzf，没装就先 brew install fzf。
```

---

## 9. `op/of/oc/oh` 按文件名全盘找并打开 —— 不用管文件在哪个目录

### 问题

想打开一个文件（`profiles-overview.html`、某张报销单、某个截图），但不记得它在哪个目录。手动 `cd` 半天、或用 Finder 一层层翻很烦。希望在终端任何位置敲一个短命令 + 文件名，就自动找到并打开它；有多个同名文件时能列出**完整路径**让我上下键挑。

### 解决办法

一组 `o` 开头的文件命令族，共用一个「`fd` 全盘找 → 唯一直接干 / 多个 `fzf` 挑」的核心：

| 命令 | 作用 |
|------|------|
| `op <文件名>` | **o**pen，用系统默认程序打开（.pdf→预览、.html→浏览器、.xlsx→Excel…一视同仁） |
| `of <文件名>` | open in **f**inder，在 Finder 里定位并**选中**该文件（`open -R`） |
| `oc <文件名>` | open **c**opy，把该文件的**完整路径**复制到剪贴板（`pbcopy`） |
| `oh` | **h**elp，本速查表 |

唯一命中直接执行；多个同名弹 `fzf`，显示完整路径 + 右侧预览（修改时间/大小），↑↓ 选、Enter 确认、Esc 取消。支持通配：`op '*.html'`、`op 'report*'`。依赖 `fd` 和 `fzf`（`brew install fd fzf`）。

> 说明：本想用 `do` 表示 direct open，但 `do` 是 shell 保留字（`for…do…done`）用不了，故用 `op`；`d` 又被 oh-my-zsh 的目录栈快捷键占用，故帮助命令用 `oh`。

#### 步骤 1：把下面这组函数加到 `~/.zshrc`

```zsh
# ── 文件命令族(op/of/oc/oh):不管在哪个目录,按文件名全盘找 ──
#   唯一命中→直接动作;多个同名→fzf 列表(显示完整路径,↑↓ 选 / Enter 确认 / Esc 取消)
#   支持通配:op profiles-overview.html  /  op '*.html'  /  op 'report*'
#   默认在 $HOME 下搜(排除 Library / 垃圾桶 / 依赖 / 缓存)。oh 看速查表。
# _dfind <文件名> — 内部核心:解析出唯一/选中的【绝对路径】打到 stdout;没找到或取消→return 1
_dfind() {
  emulate -L zsh
  local name="$1"
  local -a matches
  matches=("${(@f)$(fd --glob --type f --hidden --no-ignore \
    --exclude Library --exclude node_modules --exclude .git \
    --exclude .Trash --exclude Caches --exclude .cache \
    -- "$name" "$HOME" 2>/dev/null)}")
  matches=(${matches:#})   # 去掉空元素
  case ${#matches[@]} in
    0) echo "没找到 '$name'(在 $HOME 下)" >&2; return 1 ;;
    1) print -r -- "${matches[1]}" ;;
    *)
      local lines=() f sel
      for f in "${matches[@]}"; do lines+=("${f/#$HOME/~}"$'\t'"$f"); done
      sel=$(printf '%s\n' "${lines[@]}" | fzf \
        --delimiter=$'\t' --with-nth=1 \
        --height=70% --reverse --prompt='pick> ' \
        --header="${#matches[@]} 个同名文件 — ↑↓ 选 · Enter 确认 · Esc 取消" \
        --preview 'stat -f "修改   %Sm%n大小   %z bytes" -t "%Y-%m-%d %H:%M" {2}' \
        --preview-window='down,3,wrap')
      [ -n "$sel" ] || return 1
      print -r -- "${sel#*$'\t'}"
      ;;
  esac
}
# op <文件名> — direct open:找到并用默认程序打开
op() { emulate -L zsh; local f; f=$(_dfind "${1:?用法: op <文件名>   例:op report.pdf}") || return 1; echo "→ 打开 ${f/#$HOME/~}"; open "$f"; }
# of <文件名> — open in finder:在 Finder 里定位并选中该文件,方便你找到它
of() { emulate -L zsh; local f; f=$(_dfind "${1:?用法: of <文件名>   例:of report.pdf}") || return 1; echo "→ Finder 定位 ${f/#$HOME/~}"; open -R "$f"; }
# oc <文件名> — open copy:把该文件的完整路径复制到剪贴板
oc() { emulate -L zsh; local f; f=$(_dfind "${1:?用法: oc <文件名>   例:oc report.pdf}") || return 1; printf '%s' "$f" | pbcopy; echo "→ 已复制路径到剪贴板:${f/#$HOME/~}"; }
# oh — 列出文件命令族速查表
oh() {
  print -P "%B%F{green}文件命令族%f%b — 不管在哪个目录,按文件名全盘找(在 \$HOME 下)"
  print -P "  %F{yellow}op%f <文件名>   打开文件(系统默认程序)        例:op report.pdf"
  print -P "  %F{yellow}of%f <文件名>   在 Finder 里定位并选中该文件     例:of report.pdf"
  print -P "  %F{yellow}oc%f <文件名>   复制该文件的完整路径到剪贴板     例:oc report.pdf"
  print -P "  %F{yellow}oh%f           本速查表"
  print -P "  %F{8}多个同名 → fzf 列表(↑↓ 选 / Enter 确认 / Esc 取消);支持通配如 '*.html'%f"
}
```

#### 步骤 2：生效

```bash
source ~/.zshrc
```

### 使用

```bash
op profiles-overview.html   # 全盘找,唯一就用默认程序打开;多个同名弹 fzf 挑
op 报销单.pdf                # 任何格式都行(→ 预览)
op '*.html'                 # 支持通配
of report.pdf               # 在 Finder 里定位并选中它
oc report.pdf               # 复制它的完整路径到剪贴板,粘哪都行
oh                          # 忘了命令就敲这个
```

搜索范围是整个 `$HOME`（排除了 `Library`、垃圾桶、`node_modules`、缓存这些噪音），所以你在哪个目录都无所谓，全盘搜大约 3~4 秒。

### 让 AI 帮你配

```
帮我在 ~/.zshrc 里加一组 o 开头的「按文件名全盘找并打开」命令族,共用一个基于 fd + fzf
的核心:op <文件名> 用系统默认程序打开、of 在 Finder 里定位并选中(open -R)、oc 复制该文件
完整路径到剪贴板(pbcopy)、oh 打印速查表。搜索范围是整个 $HOME,排除 Library/垃圾桶/
node_modules/缓存;唯一命中直接执行,多个同名弹 fzf 列出完整路径(带修改时间/大小预览)让我
↑↓ 选、Enter 确认;支持通配如 '*.html'。依赖 fd 和 fzf,没装先 brew install fd fzf。
注意 do 是 shell 保留字用不了、d 常被 oh-my-zsh 占用,所以用 op 和 oh。
```

---

## 关注我

<img src="./雷码工坊微信公众号.jpg" alt="雷码工坊笔记微信公众号" width="200" />

**雷码工坊笔记** — 微信扫码关注
