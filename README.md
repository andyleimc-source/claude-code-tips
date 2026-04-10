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

将以下 prompt 发送给 Claude Code 执行：

```
请用 statusline-setup agent 帮我配置 Claude Code 底部状态栏，展示以下信息：
1. 当前模型名称
2. 当前会话上下文窗口用量百分比
3. 5 小时滚动用量百分比
4. 本周用量百分比

格式要尽量简洁：Sonnet 4.6 CTX:34% 5h:61% 7d:18%
```

**说明**：状态栏通过 `statusLine` 配置执行一个 shell 脚本，脚本从 stdin 读取 JSON 数据，其中 `model.display_name` 字段包含当前模型名称（如 Sonnet、Opus、Haiku）。

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

## 5. 用 Claude Code 驱动 AI 视频生产流水线

### 问题

AI 生图/生视频的 API 调用成本高、耗时长。写了 10 个镜头的 storyboard，跑到一半出错，或者某个镜头效果不好需要重跑，不得不全部重来。

### 解决办法

**脚本设计：幂等跳过 + 按镜头过滤**

让每个镜头的输出文件作为"完成标志"，已存在则自动跳过；用 `--shots` 参数指定只重跑哪几个镜头：

```python
# 关键逻辑：文件存在即跳过
img_path = output_dir / f"shot_{idx:02d}.png"
if img_path.exists():
    logging.info(f"[shot {idx}] 图片已存在，跳过生成")
    continue
```

```bash
# 只重新生成 shot_07 和 shot_09 的静帧
python generate_shots.py \
  --storyboard drafts/nocoly-48h/storyboard.json \
  --only-images \
  --shots 7,9
```

**Claude Code 在其中的角色**

用 `CLAUDE.md` 把整个制作流程文档化（故事结构 → 视觉圣经 → 角色参考图 → 分镜 Prompt → 生图 → 生视频 → 剪辑），Claude 在每个步骤严格按规范执行，无需重复解释意图。

将以下 prompt 发给 Claude Code 执行：

```
读 CLAUDE.md 了解制作规范，读 progress.md 确认当前进度，
然后继续下一步：为 drafts/nocoly-48h 生成 storyboard.json
的 image_prompt（遵循 PROMPT_GUIDE.md 自查清单）。
```

**完整工作流实战记录**：[我用 AI 做了一支企业剧情短片：从剧本到静帧的完整工作流](https://mp.weixin.qq.com/s/TODO)

---

## 关注我

<img src="./雷码工坊微信公众号.jpg" alt="雷码工坊笔记微信公众号" width="200" />

**雷码工坊笔记** — 微信扫码关注
