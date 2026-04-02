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
