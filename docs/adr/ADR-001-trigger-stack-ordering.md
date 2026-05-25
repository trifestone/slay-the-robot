# ADR-001: 触发器栈结算顺序

**状态**：✅ Accepted
**日期**：2026-05-19
**触发**：CONTEXT v1 §5 R6 + PRD v1 §4.2
**作者**：CONTEXT v1 反推 + prototype 1000-run 实证

---

## 背景

CONTEXT v1 §4 数据模型把卡的"3 词条槽 + 8 触发时机"做成**触发器栈架构**：每个事件（OnPlay / OnHit / OnKill / OnTraitFired 等）由 `emit(event, card)` 沿卡的 3 个词条槽传播；同事件可被多个词条监听，特殊反应（20-30 个高光时刻）在 `emit()` 时插队取代两个原效果。

这套设计回避了 80×80 反应查找表的爆炸（CONTEXT R1），但引入两个边界问题（CONTEXT R6）：

1. **同事件多词条结算顺序**：一张卡 3 槽都监听 `OnPlay`，谁先结算？
2. **OnTraitFired 串联深度**：词条 A 触发后 emit `OnTraitFired`，又触发词条 B，B 又 emit... 不防递归就栈溢出。

ADR 三门槛检查：
- 难撤回 ✓（结算顺序写进 emit() 内核，影响所有 80 词条 + 25 反应的语义）
- 反直觉 ✓（"按 slot index 顺序"看似自然，但同卡两 trait 互为前置时数值会因顺序产生不同结果，需明文锁定）
- 真权衡 ✓（深度 ≤ 2 vs 无限深度：前者牺牲极少数"链式 build" 设计空间，换取永不爆栈 + 测试面收敛）

---

## 决策

### 1. 同事件多词条按 slot index 0 → 1 → 2 顺序结算

```python
def emit(state, event, card):
    # 1. 特殊反应优先级最高（同卡两 trait 同时存在 → 取代两原效果）
    for r in state.reactions:
        if r.timing == event and card.has_traits(*r.watch_for):
            apply_effect(r.override_effect)
            return  # 跳过下游

    # 2. 常规：按 slot index 0 → 1 → 2 顺序
    for slot_idx in range(3):
        trait = card.slots[slot_idx]
        if trait and trait.trigger == event:
            if exceeded_cooldown(trait, card):
                continue  # M1: cooldown_per_turn 边界
            apply_effect(trait.effect)
            # 3. 串联触发：OnTraitFired 深度 ≤ 2
            if state.fire_depth < 2:
                state.fire_depth += 1
                emit(state, OnTraitFired, card)
                state.fire_depth -= 1
```

### 2. OnTraitFired 串联深度上限 = 2

- 深度 0：原始 emit (e.g., `OnPlay`)
- 深度 1：OnTraitFired（一次冒泡）
- 深度 2：OnTraitFired 再触发（极少数链式 build）
- 深度 3+：**阻断**（不递归，不抛异常，静默 skip）

### 3. 特殊反应阻断后下游不冒泡

特殊反应命中即 return，**不再** emit `OnTraitFired`。这避免"反应 → 反应"的递归地狱。

---

## 实证

prototype（`prototype/sim.py`）跑 1000 run 验证：

| 指标 | 数值 |
|---|---|
| 累计 emit() 调用数 | **~560,000 次** |
| OnTraitFired 触发数 | ~15,000 次（其中 void_consume rare 词条） |
| fire_depth ≥ 3 阻断次数 | 0（均被深度 ≤ 2 限制） |
| 栈溢出 / 递归异常 | **0 次** |
| 平均单战 emit() | ~80 次 |
| 单 run 1440 emit() 完成时间 | <1ms（Python 无优化） |

**结论**：深度 ≤ 2 设计在 56 万次 emit() 实证下**完全稳定**，且性能开销可忽略（Godot 4 GDScript 实现预期更快 5-10x）。

详见 `prototype/PROTOTYPE_REPORT.md` §2.4。

---

## 后果

### 正面

- **测试面 80 × 80 = 6400 → 80 + 25 = 105**（CONTEXT R1 缓解的核心机制）
- **GDScript 实现简单**：emit() 函数 < 30 行，无需 ECS
- **可重放**：seed 固定 → emit() 序列固定 → 回归测试可哈希 diff（PRD §5.4 R6+）
- **设计空间**：80 词条 × 8 trigger × 3 slot = 1920 + 25 反应 = 充分

### 负面

- **被排除的 build 空间**：链式深度 > 2 的"骨牌式" combo（如 5 个 OnTraitFired 词条接力）做不出来。但这种 build 的"一键秒"特性本就违背 30-40 min 节奏目标，不是损失。
- **slot index 决定顺序**：玩家拼装时需理解"slot 1 装在 slot 2 之前结算"。在 UI 上需用编号 1/2/3 + 箭头明示（PRD US-09 反应预览中已包含）。
- **同卡同 trait 不可重复**（A2 §9.3 规则 1）：避免 slot 0/1 都装 flame_brand 然后 OnTraitFired 链上 5 次回血。已在 4.3 锁定。

### 中性

- 特殊反应必须绑定一个具体 timing（M2 PRD 新加的 `reaction.timing` 字段），与"emit() 时插队"语义自然契合。

---

## 替代方案（被否决）

### A1. 同时刻全部结算（事件总线模式）

所有监听 `OnPlay` 的 trait 在同一原子操作内结算，互不影响顺序。

**否决理由**：
- 无法表达"slot 1 触发 → 改变状态 → slot 2 看到新状态"的链式逻辑
- 反应阻断语义不清：3 个词条同时执行时，反应该跳过哪个？
- 玩家心智模型："3 个槽的卡有 3 步动画"比"一闪而过的爆炸"更易理解

### A2. 深度无限 + 防循环检测

允许 OnTraitFired 任意深度，用 `(card_id, trait_id)` 已触发集合防循环。

**否决理由**：
- 测试面爆炸：深度 3 时同卡 3 trait 互相触发 = 3! = 6 种顺序，需穷举
- prototype 实测深度 ≥ 2 即可覆盖所有有意义的 build（void_consume 已是最链式的 rare）
- "防循环检测" 本身是 silent bug 来源（漏一种环就栈溢出）

### A3. 玩家可调顺序

营地拼装时玩家可手动设 slot 顺序。

**否决理由**：
- UI 复杂度激增（拖拽 vs 排序冲突）
- 80 词条 × 6 排序 = 玩家做不完的微操
- "slot 0 = 基底自带 locked"的语义被破坏

---

## 相关

- CONTEXT v1 §4 数据模型（结构定义）
- CONTEXT v1 §5 R6（风险登记）
- PRD v1 §4.2 战斗循环（结算顺序锁定）
- PRD v1 §4.4 + M2（反应触发时机字段）
- PRD v1 §5.4 R6+（emit 量级测试 fixture）
- prototype/PROTOTYPE_REPORT.md §2.4（实证数据）

---

*ADR 结束。下游：GDScript 实现 `emit()` 时严格按本文 §决策 1-3，配套 GdUnit4 测试由 PRD §5.4 R6 + R6+ 覆盖。*
