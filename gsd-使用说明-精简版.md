# GSD 使用说明（精简版）

> 适用于 Claude Code / OpenCode / Gemini CLI / Codex。

---

## 1. GSD 是什么

GSD（Get Shit Done）是一套面向 AI 编程代理的开发工作流，用来把开发流程标准化：

- 先澄清需求，再做规划
- 按阶段执行并验证
- 通过原子提交和状态文件保持可追踪

一句话：**把“想法 -> 可交付功能”流程化**。

---

## 2. 安装与验证

## 安装

```bash
npx get-shit-done-cc@latest
```

安装时选择：
- Runtime（Claude/OpenCode/Gemini/Codex）
- 安装位置（Global/Local）

## 验证

- Claude Code / Gemini：`/gsd:help`
- OpenCode：`/gsd-help`
- Codex：`$gsd-help`

## 更新

```bash
npx get-shit-done-cc@latest
```

---

## 3. 最常用流程（建议照这个走）

```text
/gsd:new-project
/gsd:discuss-phase 1
/gsd:plan-phase 1
/gsd:execute-phase 1
/gsd:verify-work 1
```

然后对 phase 2、phase 3 重复上述步骤。

里程碑完成后：

```text
/gsd:audit-milestone
/gsd:complete-milestone
/gsd:new-milestone
```

> 已有项目先执行：`/gsd:map-codebase`

---

## 4. 小任务快速处理

```text
/gsd:quick
```

适用于：小 Bug、小改动、配置调整。

---

## 5. 命令速查

## 核心命令

- `/gsd:new-project`
- `/gsd:discuss-phase [N]`
- `/gsd:plan-phase [N]`
- `/gsd:execute-phase <N>`
- `/gsd:verify-work [N]`
- `/gsd:complete-milestone`
- `/gsd:new-milestone [name]`

## 常用辅助

- `/gsd:progress`（看当前进度）
- `/gsd:resume-work`（恢复上下文）
- `/gsd:settings`（改配置）
- `/gsd:set-profile budget`（降成本）
- `/gsd:map-codebase`（分析现有代码）

---

## 6. 推荐配置（实用）

- 默认先用：`balanced`
- 成本高时切：`budget`
- 对质量要求高时切：`quality`

```text
/gsd:set-profile balanced
/gsd:set-profile budget
/gsd:set-profile quality
```

---

## 7. 常见问题

- **命令不可用**：重启运行时，再执行 `/gsd:help`
- **计划不符合预期**：先 `/gsd:discuss-phase N` 再 `/gsd:plan-phase N`
- **忘了做到哪一步**：执行 `/gsd:progress`
- **长会话效果下降**：`/clear` 后 `/gsd:resume-work`

---

## 8. 一页口诀

```text
新项目：new-project
每阶段：discuss -> plan -> execute -> verify
收尾：audit -> complete-milestone
下一版：new-milestone
小活：quick
```
