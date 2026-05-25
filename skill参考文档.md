# 已安装的 14 个 Skill 完整用法总览

安装位置：`C:\Users\zuolei01\Documents\MyGame\.agents\skills\`

按用途分三类：**工程类（核心开发流程）**、**协作沟通类**、**元工具类**。

---

## 一、工程类（7 个）

### 1. `setup-matt-pocock-skills` — 必须最先跑一次
**触发**：首次使用任何 mattpocock skill 之前，由 Claude 自动调用（`disable-model-invocation: true`，不响应用户主动喊话）。
**作用**：写入项目级配置——issue tracker（GitHub / GitLab / 本地 markdown / 其他）、triage 标签、领域文档骨架（CONTEXT.md / CONTEXT-MAP.md / docs/adr/）。
**用法**：第一次运行 `triage` / `to-issues` / `to-prd` 时会自动跑；也可手动让 Claude 重新跑以更新配置。
**输出物**：`.agents/skills-config.json`、`docs/CONTEXT.md` 占位、`docs/adr/` 目录。

---

### 2. `tdd` — 红绿重构
**触发**："use TDD"、"写测试先"、"按 TDD"、要做新功能时。
**核心**：
- **垂直切片** > 横向切片：先把"用户输入 → 业务 → 持久化"打通一条最窄的路；不要先把 model 层全写完再写 service。
- 测试只走公共接口，不偶合实现。
- 红 → 绿 → 重构循环，每一步都要能跑。
**用法**：交付一个 user story 时说 "let's TDD this"，Claude 会先写一个会失败的测试 → 最小实现让它绿 → 重构。

---

### 3. `diagnose` — 6 阶段调试
**触发**："这个 bug…"、"为什么 X 不工作"、"diagnose"。
**6 阶段**：
1. **建立反馈循环**（要能稳定复现 / 一键跑测试）
2. **复现** bug，最小化 repro
3. **假设排序**：列 3-5 个可证伪假设，按可能性排
4. **打桩观测**：日志带 `[DEBUG-xxxx]` 唯一前缀，便于事后清理
5. **修复 + 回归测试**：必须留一个 test 锁住
6. **清理 + 复盘**：删 [DEBUG-xxxx] 标签，写 1-2 行 root cause
**与其他 skill 联动**：根因如果是架构问题 → 切到 `improve-codebase-architecture`。

---

### 4. `improve-codebase-architecture` — 架构重构
**触发**："refactor"、"模块太乱"、"想改架构"。
**词汇表**（统一用词避免歧义）：
- **Module / Interface / Implementation**
- **Depth**（深 = 接口窄实现宽，浅 = 接口宽实现薄。优先深模块）
- **Seam**（可替换点）/ **Adapter**（外部依赖隔离层）
- **Leverage**（一处改动覆盖多处需求）/ **Locality**（相关代码物理就近）
**Deletion test**：能删掉吗？不能删 → 多余抽象。
**用法**：贴一段代码或目录，让 Claude 用这套词汇评判 + 给出方案。

---

### 5. `prototype` — 一次性原型
**触发**："prototype"、"先试个玩具"、"快速验证"。
**两个分支**：
- **LOGIC 分支**：终端小程序，专门验证一个状态机/算法
- **UI 分支**：在同一路由下放多个视觉变体并排
**核心**：明确**抛弃式代码**，回答**一个**问题，不准放进生产 codebase。

---

### 6. `to-prd` — 写 PRD
**触发**："写 PRD"、"产品需求文档"。
**模板字段**：Problem Statement / Solution / User Stories / Implementation Decisions / Testing Decisions / Out of Scope / Further Notes。
**特性**：**不做面试**，只综合现有上下文产出 PRD（要面试用 `grill-with-docs` 或 `grill-me`）。

---

### 7. `to-issues` — PRD/Plan 拆 issue
**触发**："拆任务"、"建 issue"、"切成 PR"。
**核心**：每个 issue 是**纵切**（端到端跑通的最小切片），分两类标签：**AFK**（agent 自走）/ **HITL**（要人盯）。
**Issue 模板**：What / Acceptance criteria / Blocked-by。
**前置**：需要 `setup-matt-pocock-skills` 已配好 issue tracker。

---

## 二、协作沟通类（4 个）

### 8. `triage` — issue 分诊
**触发**："triage"、"分诊"、"看下 issue 列表"。
**状态机**（5 个状态 + 2 个分类）：
- 分类：`bug` / `enhancement`
- 状态：`needs-triage` → `needs-info` / `ready-for-agent` / `ready-for-human` / `wontfix`
**强制**：每条评论必须挂 AI disclaimer（声明是 AI 生成）。
**联动**：信息不全 → 调 `grill-with-docs` 跟提单人逼问。

---

### 9. `grill-with-docs` — 边面试边写文档
**触发**："grill"、"逼问设计"、"想清楚再做"。
**特点**：一边问问题，一边把答案**就地写进 CONTEXT.md**；遇到三条都满足的决策（**难撤回 + 反直觉 + 真权衡**）才另开 ADR。
**用法**：贴一份草稿设计或一个含糊的需求，喊 "grill me with docs"。

---

### 10. `grill-me` — 纯逼问
**触发**："grill me"、"挑战我的方案"。
**和 grill-with-docs 区别**：不写文档副作用，只一对一逼问，每个分支挖到底，每个问题给推荐答案。
**规则**：一次只问一个问题；能从 codebase 读出来的就直接读，不问。

---

### 11. `handoff` — 会话交接
**触发**："handoff"、"压缩这次对话"、"另起一个 session"。
**作用**：把当前对话压缩成一份 handoff doc，写到 `mktemp -t handoff-XXXXXX.md`，给下一个 agent 接力。
**关键**：**不复制**已有的 PRD/plan/ADR/diff/commit，只引用路径或 URL；可带参数说明下一阶段重点。
**典型用法**：`/handoff "下一段去做 to-issues 拆 prd"`。

---

## 三、元工具类（3 个）

### 12. `caveman` — 山顶洞人模式
**触发**："caveman"、"山顶洞人"、"少 token"、"be brief"、`/caveman`。
**效果**：≈ 节省 75% token。
**规则**：
- 删冠词 / 客套 / 填充词
- 短同义词（big 不用 extensive）
- 缩写（DB / auth / config / req / res / fn）
- 因果用箭头：`X -> Y`
- 句式：`[thing] [action] [reason]. [next].`
**持久性**：一旦触发，**每个回复都保持**山顶洞人语气，直到说 "stop caveman" / "normal mode"。
**例外**：安全警告 / 不可逆操作 / 多步顺序 / 用户重复发问 → 临时切回正常 → 讲清楚后再 caveman。

---

### 13. `zoom-out` — 拉远视角
**触发**：`disable-model-invocation: true`，主要用 `/zoom-out` 直接喊。
**一句话作用**："Go up a layer, give map of relevant modules and callers"——把视角往上拉一层，给出相关模块和调用者地图。
**典型场景**：陷入某个文件出不来时。

---

### 14. `write-a-skill` — 自己写 skill
**触发**："写一个新 skill"、"build a skill"。
**结构**：
```
skill-name/
├── SKILL.md         # 主指令（< 100 行）
├── REFERENCE.md     # 详细文档（按需）
├── EXAMPLES.md      # 用例（按需）
└── scripts/         # 工具脚本（确定性操作时）
```
**Description 关键约束**（≤ 1024 字符）：
- 第一句：能力是什么
- 第二句：`Use when [具体触发词]`
- 第三人称
**Checklist**：description 含触发词 / SKILL.md < 100 行 / 无时效内容 / 用词一致 / 有具体例子 / 引用只下钻一层。

---

## 推荐工作流（端到端示例）

```
新需求来了
  ├─ /grill-with-docs   → 把需求和设计逼问清楚，写进 CONTEXT.md
  ├─ /to-prd            → 综合产出 PRD
  ├─ /to-issues         → 拆纵切 issue（AFK/HITL）
  └─ 单个 issue 实现：
       ├─ /tdd          → 红绿重构走垂直切片
       ├─ 卡住 → /diagnose
       └─ 越改越乱 → /improve-codebase-architecture
                         └─ 拿不准结构 → /prototype 试一下

跨 session 接力 → /handoff "下一阶段做 X"
issue 多了乱了 → /triage
想压缩输出     → /caveman
```

**先跑一次** `setup-matt-pocock-skills`（触发条件：第一次用 triage/to-issues/to-prd 时会自动），把 issue tracker、triage 标签、CONTEXT.md 骨架配置好，后面流程才顺。
