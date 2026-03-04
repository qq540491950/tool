# GSD（Get Shit Done）使用说明（简体中文）

> 基于仓库 `gsd-build/get-shit-done` 的 `README.md` 与 `docs/USER-GUIDE.md` 整理。
> 适用于 Claude Code、OpenCode、Gemini CLI、Codex。

---

## 1. 工具简介

GSD 是一套面向 AI 编程代理的工程化工作流，核心目标是：

- 减少长会话导致的上下文衰减（Context Rot）
- 用“需求 → 规划 → 执行 → 验证”的闭环提升稳定性
- 通过多代理协作与原子提交提高可追溯性

简单理解：你描述目标，GSD 帮你把开发过程标准化并自动推进。

---

## 2. 安装与更新

## 2.1 交互式安装（推荐）

```bash
npx get-shit-done-cc@latest
```

安装时会提示选择：

1. **Runtime**：Claude Code / OpenCode / Gemini CLI / Codex / All
2. **Location**：Global（全局）或 Local（当前项目）

## 2.2 验证安装

- Claude Code / Gemini CLI：`/gsd:help`
- OpenCode：`/gsd-help`
- Codex：`$gsd-help`

> 注意：Codex 使用 skills 方式安装（`skills/gsd-*/SKILL.md`），不是 custom prompts。

## 2.3 非交互安装（CI / Docker / 脚本）

```bash
# Claude Code
npx get-shit-done-cc --claude --global
npx get-shit-done-cc --claude --local

# OpenCode
npx get-shit-done-cc --opencode --global

# Gemini CLI
npx get-shit-done-cc --gemini --global

# Codex
npx get-shit-done-cc --codex --global
npx get-shit-done-cc --codex --local

# 全部运行时
npx get-shit-done-cc --all --global
```

## 2.4 更新

```bash
npx get-shit-done-cc@latest
```

---

## 3. 推荐运行方式

GSD 建议在尽量少打断的权限模式下使用（减少频繁确认）：

```bash
claude --dangerously-skip-permissions
```

如果不使用该参数，可在 `.claude/settings.json` 中配置精细权限规则（allow/deny）。

---

## 4. 核心工作流（标准流程）

> 如果是已有代码库（Brownfield），建议先执行 `/gsd:map-codebase`。

## 步骤 1：初始化项目

```text
/gsd:new-project
```

系统会完成：问题澄清 → 研究 → 需求拆分 → 路线图生成。

产物示例：

- `PROJECT.md`
- `REQUIREMENTS.md`
- `ROADMAP.md`
- `STATE.md`
- `.planning/research/`

## 步骤 2：讨论阶段细节

```text
/gsd:discuss-phase 1
```

用于锁定实现偏好（UI、交互、API 风格、错误处理、边界情况等）。

产物示例：`1-CONTEXT.md`

## 步骤 3：规划阶段

```text
/gsd:plan-phase 1
```

执行研究、任务拆分、计划校验（通常生成 2~3 个原子任务计划）。

产物示例：

- `1-RESEARCH.md`
- `1-01-PLAN.md`、`1-02-PLAN.md` ...

## 步骤 4：执行阶段

```text
/gsd:execute-phase 1
```

特性：

- 按依赖分波次执行（Wave）
- 可并行执行独立计划
- 每个任务原子提交（便于回滚和审计）

## 步骤 5：人工验收

```text
/gsd:verify-work 1
```

验证“是否真的可用”，而不仅是“代码存在且测试通过”。

## 步骤 6：里程碑收尾与下一里程碑

```text
/gsd:complete-milestone
/gsd:new-milestone
```

---

## 5. 快速模式（小任务）

```text
/gsd:quick
```

适用场景：

- 小 Bug 修复
- 配置调整
- 一次性小功能

特点：

- 保留 GSD 的状态追踪和提交优势
- 比完整流程更快
- 产物在 `.planning/quick/`

---

## 6. 常用命令速查

## 6.1 主流程命令

- `/gsd:new-project [--auto]`
- `/gsd:discuss-phase [N] [--auto]`
- `/gsd:plan-phase [N] [--auto]`
- `/gsd:execute-phase <N>`
- `/gsd:verify-work [N]`
- `/gsd:audit-milestone`
- `/gsd:complete-milestone`
- `/gsd:new-milestone [name]`

## 6.2 导航命令

- `/gsd:progress`：查看当前进度与下一步
- `/gsd:help`：查看命令与说明
- `/gsd:update`：更新 GSD
- `/gsd:join-discord`：加入社区

## 6.3 阶段管理

- `/gsd:add-phase`
- `/gsd:insert-phase [N]`
- `/gsd:remove-phase [N]`
- `/gsd:list-phase-assumptions [N]`
- `/gsd:plan-milestone-gaps`

## 6.4 会话与工具

- `/gsd:pause-work` / `/gsd:resume-work`
- `/gsd:settings`
- `/gsd:set-profile <profile>`
- `/gsd:add-todo [desc]`
- `/gsd:check-todos`
- `/gsd:debug [desc]`
- `/gsd:health [--repair]`
- `/gsd:reapply-patches`
- `/gsd:map-codebase`

---

## 7. 配置说明（`.planning/config.json`）

示例结构：

```json
{
  "mode": "interactive",
  "granularity": "standard",
  "model_profile": "balanced",
  "planning": {
    "commit_docs": true,
    "search_gitignored": false
  },
  "workflow": {
    "research": true,
    "plan_check": true,
    "verifier": true,
    "nyquist_validation": true
  },
  "git": {
    "branching_strategy": "none",
    "phase_branch_template": "gsd/phase-{phase}-{slug}",
    "milestone_branch_template": "gsd/{milestone}-{slug}"
  }
}
```

关键项说明：

- `mode`：`interactive`（交互确认）/ `yolo`（自动推进）
- `granularity`：`coarse` / `standard` / `fine`
- `model_profile`：`quality` / `balanced` / `budget`
- `workflow.*`：控制研究、计划校验、执行后验证等开关
- `git.branching_strategy`：`none` / `phase` / `milestone`

---

## 8. 推荐实践

1. **已有项目先 `map-codebase`**，再 `new-project`
2. **每个 phase 先 discuss 再 plan**，减少误解
3. **长会话中适时 `/clear`**，再用 `/gsd:resume-work` 恢复
4. **小改动优先 `/gsd:quick`**，避免重流程
5. **根据预算切换 profile**（`/gsd:set-profile budget`）

---

## 9. 安全建议

建议在 Claude 权限中将敏感文件加入 deny，例如：

- `.env` / `.env.*`
- `**/secrets/*`
- `**/*credential*`
- `**/*.pem`
- `**/*.key`

这样可从源头避免敏感信息被读取。

---

## 10. 常见问题（FAQ）

### Q1：安装后命令不可用？
- 重启运行时（Claude/OpenCode/Gemini/Codex）
- 检查对应目录下命令或 skills 是否存在
- 执行 `/gsd:help` 验证

### Q2：规划结果不符合预期？
- 先执行 `/gsd:discuss-phase N`
- 用 `/gsd:list-phase-assumptions N` 预览 AI 假设

### Q3：执行后发现问题？
- 使用 `/gsd:verify-work N` 做结构化验收与问题定位
- 或用 `/gsd:quick` 做定向修复

### Q4：成本过高？
- `/gsd:set-profile budget`
- 在 `/gsd:settings` 里关闭部分 workflow 代理

---

## 11. 目录结构（参考）

```text
.planning/
  PROJECT.md
  REQUIREMENTS.md
  ROADMAP.md
  STATE.md
  config.json
  MILESTONES.md
  research/
  codebase/
  phases/
  todos/
  debug/
```

---

## 12. 一页流程速记

```text
新项目：/gsd:new-project
每个阶段：/gsd:discuss-phase N -> /gsd:plan-phase N -> /gsd:execute-phase N -> /gsd:verify-work N
收尾：/gsd:audit-milestone -> /gsd:complete-milestone
下一版本：/gsd:new-milestone
```

---
