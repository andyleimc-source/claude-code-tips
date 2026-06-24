---
name: inpro
description: Initialize a project with durable Codex collaboration documents — creates AGENTS.md, plan.md, progress.md, decision.md, bug.md, and handoff.md in a target directory. Use when the user says "inpro", "初始化项目", "做项目初始化", or asks to initialize a project's collaboration or shared-memory documentation.
---

# inpro — 项目初始化（Codex）

Create a lightweight, project-local collaboration memory system. `AGENTS.md` is the Codex equivalent of Claude Code's `CLAUDE.md`: they serve the same project-instruction and persistent-context role. When adapting a Claude Code project, translate or merge its `CLAUDE.md` content into `AGENTS.md` rather than treating it as a separate documentation system.

## Target and safety

1. Use the absolute path supplied by the user, otherwise the current working directory. Create it when it does not exist.
2. If `AGENTS.md` already exists, preserve its content and merge the Project Memory section into it. Treat an existing `CLAUDE.md` as the equivalent source document: translate its durable instructions into `AGENTS.md` when adapting the project. Do not retain both as competing instruction files unless the user explicitly needs Claude Code compatibility.
3. Never overwrite existing memory documents. Tell the user which names conflict and ask whether to overwrite, skip, or merge. For `AGENTS.md`, merge the inpro Project Memory section unless the user asks not to.
4. Infer the project name, one-sentence purpose, first milestone, next action, and constraints from the conversation. If no project context exists, ask one concise question before creating files.
5. Do not initialize Git or create commits unless the user explicitly asks. Report the created files after checking them.

## Create these files

Write real values rather than leaving placeholders. Use the actual current date from the environment.

### `AGENTS.md`

Add a `Project Memory` section that links to `plan.md`, `progress.md`, `decision.md`, `bug.md`, and `handoff.md`. Its maintenance rules must require updating the appropriate document after progress, decisions, bugs, scope changes, and session handoffs. Create `glossary.md` once three or more project-specific terms need stable definitions.

### `plan.md`

Include the current goal, milestone checklist, and explicit out-of-scope work.

### `progress.md`

Use reverse-chronological entries. Each entry includes date, work, result, and next action. The initial entry records that collaboration documents were initialized.

### `decision.md`

Record material product, architecture, and tooling decisions with their rationale, alternatives, trade-offs, and date. Add an initial decision to use the inpro documents as durable project memory.

### `bug.md`

Include `OPEN` and `FIXED` sections. Use: status | symptom | root cause | resolution | date.

### `handoff.md`

Record current state, next-session steps, environment details, and active constraints or risks.

## Optional `glossary.md`

Create only once the project has at least three project-specific terms or the conversation reveals conflicting terminology. Make it the authoritative definition source and include term, Chinese name if useful, definition, and example.
