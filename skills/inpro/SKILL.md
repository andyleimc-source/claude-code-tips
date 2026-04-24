---
name: inpro
description: Initialize a project with standard Claude collaboration docs — creates CLAUDE.md, plan.md, progress.md, decision.md, bug.md, handoff.md in the current working directory (or the path given as argument). Use when the user says "inpro", "初始化项目", "做项目初始化", or explicitly invokes /inpro.
---

# inpro — 项目初始化

在目标目录下创建 6 个协作骨架文件：`CLAUDE.md`、`plan.md`、`progress.md`、`decision.md`、`bug.md`、`handoff.md`。

## 使用方式

- 用户说 "inpro" / "初始化项目" / `/inpro [path]`
- 参数（可选）：目标目录绝对路径。缺省时使用当前工作目录。

## 执行步骤

1. **确认目标目录**
   - 如果用户给了路径：用该路径
   - 否则：当前 cwd
   - 如果目录不存在：`mkdir -p` 建好

2. **检查冲突**
   - 如果目标目录已存在同名 md，不要覆盖，询问用户："发现 X 已存在，要覆盖 / 跳过 / 合并？"
   - 其它文件直接写入

3. **了解项目（必要时问一句）**
   - 如果当前对话里已经有明确项目主题（比如刚聊完某个方案），直接把主题用到 `CLAUDE.md` 里
   - 如果完全没有上下文，只问一句："这个项目是做什么的？一句话概括。" 然后继续

4. **写入 6 个文件**，按下方模板，**把项目名、目标、上下文填进去**，不要留空模板给用户自己填

5. **git 初始化（可选）**
   - 如果目录不是 git 仓库，问一句要不要 `git init` + 首个 commit

6. **汇报**
   - 一句话说建了什么，在哪里，用户下一步应该 cd 过去开新会话

## 文件模板

### CLAUDE.md
```markdown
# {项目名}

{一句话项目描述}

## 目标
{核心目标}

## 架构
{如果有，画个简图}

## 关键约束
- {从对话里提取的硬约束}

## 关键文件
- `plan.md` — 当前迭代计划
- `progress.md` — 进度流水
- `decision.md` — 架构/选型决策记录
- `bug.md` — 已知问题 & 修复
- `handoff.md` — 会话交接

## 文档维护规则（无需用户提醒，主动执行）
这些文件不是装饰，是多轮 Claude 会话共享记忆的载体。触发条件出现就立即更新，改完直接 commit 不要问：
- **修完一个 bug** → `bug.md`：OPEN 那条移到 FIXED，补现象/根因/修复/日期
- **完成 plan.md 里的勾选项，或有可交付的阶段性进展** → `progress.md`：追加一条（日期倒序、做了什么、结果、下一步）
- **做了架构/选型/工具链决策** → `decision.md`：追加一条（决策 + Why + 备选 + 代价 + 日期）
- **讨论出新任务、调整里程碑、scope 变化** → `plan.md`：改勾选项 / 加条目 / 移 out-of-scope
- **会话即将结束、用户说"交接"、或讨论到新一轮该干啥** → 刷新 `handoff.md`
- **发现新 bug 未当场修** → `bug.md` OPEN 区追加一条

日期统一用真实当天日期（从环境 currentDate 取）。不要累积"等会儿一起更"，触发即更。

## 参考
- {链接}
```

### plan.md
```markdown
# Plan

## 当前目标
{MVP 或当前 sprint 目标}

## 里程碑

### M1 — {名字}
- [ ] {任务}

## 暂不做
- {out of scope}
```

### progress.md
```markdown
# Progress

按时间倒序记录。每条包含：日期、做了什么、结果、下一步。

---

## {YYYY-MM-DD}
- 项目初始化
- 下一步：{基于对话推断}
```

### decision.md
```markdown
# Decisions

记录重要的架构/选型决策。格式：决策 + Why + 备选方案 + 日期。

---

## {YYYY-MM-DD} · {决策标题}
- **Why**：
- **备选**：
- **代价**：
```

### bug.md
```markdown
# Bugs & Known Issues

格式：状态 | 现象 | 根因 | 修复 | 日期

---

## OPEN
_（暂无）_

## FIXED
_（暂无）_
```

### handoff.md
```markdown
# Handoff

给下一轮 Claude 会话的交接备忘。每次会话结束前更新。

---

## 当前状态（{YYYY-MM-DD}）
- {当前进展}

## 下一轮该做什么
1. 先读 `CLAUDE.md`
2. 看 `plan.md` 找到当前里程碑
3. {具体下一步}

## 环境
- {关键环境信息}

## 注意事项
- {硬约束提醒}
```

## 注意

- **日期用当前真实日期**（从环境上下文 currentDate 取），不要写占位符
- 模板里的 `{...}` 占位符必须替换为真实内容，**不要把花括号原样写进文件**
- 如果用户已经在对话里讲清楚了项目背景，直接填进去；别再反复问
- 文件建完直接 `ls` 一下给用户看结果
