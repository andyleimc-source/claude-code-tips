# Claude Code Tips

Claude Code 实用技巧集合，帮助你更高效地使用 Claude Code。

---

## 禁用 Workspace Trust 提示

每次启动 Claude Code 时，会弹出 "Quick safety check: Is this a project you created or one you trust?" 提示。即使选了 "Yes"，某些目录下次启动仍会再次弹出。

### 原因

Trust 状态保存在 `~/.claude.json` 文件的 `projects` 字段中，对应目录的 `hasTrustDialogAccepted` 值为 `false`。

### 解决方法

用 Python 直接修改 `~/.claude.json`：

```bash
python3 -c "
import json
with open('$HOME/.claude.json', 'r') as f:
    d = json.load(f)
# 替换为你的目录路径
d['projects'].setdefault('$HOME', {})['hasTrustDialogAccepted'] = True
with open('$HOME/.claude.json', 'w') as f:
    json.dump(d, f, indent=2)
print('Done')
"
```

如果要为所有已知目录批量禁用：

```bash
python3 -c "
import json
with open('$HOME/.claude.json', 'r') as f:
    d = json.load(f)
for path in d.get('projects', {}):
    d['projects'][path]['hasTrustDialogAccepted'] = True
with open('$HOME/.claude.json', 'w') as f:
    json.dump(d, f, indent=2)
print('Done - all projects trusted')
"
```

### 验证

```bash
python3 -c "
import json
with open('$HOME/.claude.json') as f:
    d = json.load(f)
for path, cfg in d.get('projects', {}).items():
    status = cfg.get('hasTrustDialogAccepted', False)
    print(f\"{'✓' if status else '✗'} {path}\")
"
```
