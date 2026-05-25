# CONTEXT — 卡牌词条拼装 Roguelike

> 项目文档骨架。本文件由 `grill-with-docs` 流程产出，是后续所有 PRD/Issue/原型的事实源。
> 状态：**v1 — 6 路竞品研究反推修正完成（2026-05-19）**
> 方法论：mattpocock `grill-with-docs`（边逼问边落文档）

## 版本历史

| 版本 | 日期 | 变更 |
|---|---|---|
| v0 | 2026-05-19 | grill-with-docs Q1-Q13 共识达成 |
| v1 | 2026-05-19 | 6 路竞品研究反推修正：Q4 升级为「触发器+效果」结构；Q6 改为触发器栈 + 20-30 特殊反应；Q8 增强为可拆卸入库存（25-30 词条/run） |

---

## 1. 一句话定义

一款 **30-40 分钟单局** 的卡牌 roguelike。玩家扮演**巫女**，每局选 1 种基底卡组（攻击/技能/仪式），**击杀敌人后吞噬其词条**，回营地用**炼金台**为卡牌拼装最多 3 个词条。**80 个词条 + 50-80 个成对化学反应** 构成核心策略空间。**StS 风能量制 + Inscryption 风 sigil 拼装**。目标受众：StS 老玩家。

---

## 2. 设计共识（Q1–Q13）

| # | 维度 | 决议 | 备注 |
|---|---|---|---|
| Q1 | 主题/世界观 | **炼金/巫术** | 元素+物质+咒语词条原子语法；区别于 StS 2 的英雄向、Inscryption 的魔幻现实 |
| Q2 | 战斗主调 | **能量出牌制**（StS 路线） | 每回合 3 能量；血量/抽卡/手牌为独享机制 |
| Q3 | 词条角色 | **核心机制** | 卡牌不存在固定数据库，全部由词条拼出 |
| Q4 | 词条原子粒度 | **触发器 + 效果**（v1 修正） | 每词条 = `{trigger, effect, value}`；池规模 ~80；Inscryption sigil 路线 |
| Q5 | 卡词条槽数 | **固定 3 槽** | UI 三图标可画；组合空间够深；可平衡 |
| Q6 | 词条互动深度 | **触发器栈 + 20-30 特殊反应**（v1 修正） | 默认行为：词条监听事件自然冒泡；仅高光时刻设特殊反应（火+油→爆炸）；不查 80×80 表 |
| Q7 | 拼装位置 | **仅营地** | 战斗外炼金台；战斗内不可改 |
| Q8 | 词条来源 | **击杀吞噬 + 可拆卸入库存**（v1 修正） | 普通 60% 给 1，精英固定 2，Boss 固定 3；可在炼金台拆卸入库存复用；目标 25-30 词条/run |
| Q9 | 卡基底 | **3 种基底卡**（攻击/技能/仪式） | 每张卡 = 1 基底 + 3 槽；其中 1 槽预占基底自带核心词条 |
| Q10 | 初始卡组 | **15-20 张** | 词条调度量 45-60；营地不至于劝退 |
| Q11 | 单局长度 | **30-40 分钟**（轻走型） | Hades 风；快迭代 |
| Q12 | 元进度 | **经典解锁型**（StS 风） | 跑团解锁词条/基底/巫女职业 |
| Q13 | 目标玩家 | **StS 老玩家求词条拼装创新** | r/slaythespire / 卡牌 roguelike Discord |

---

## 3. 设计骨架（核心循环）

```
┌─────────────────────────────────────────────────────┐
│  RUN 一局 (30-40 min)                                │
│                                                       │
│  地图节点 → 战斗(能量制 StS 出牌, 不动词条)           │
│              ↓ 击杀                                   │
│           掉 1 词条 ──┐                               │
│                       ↓                               │
│  营地炼金台 ←───────── 拆/装词条 (3 槽/卡)            │
│  反应预览  ←────── 成对反应表                          │
│              ↓                                        │
│           下场战斗                                     │
│              ↓                                        │
│           Boss → 元进度解锁(新词条/基底/巫女职业)      │
└─────────────────────────────────────────────────────┘
```

---

## 4. 数据模型 v1（触发器栈架构）

```
Card {
  base: Base                     # Attack | Skill | Rite
  slots: [Slot, Slot, Slot]      # 长度恒为 3
}

Slot {
  index: 0 | 1 | 2
  trait: Trait | null            # slot[0] 必为基底自带词条
  locked: bool                   # slot[0] 始终 locked
}

Trait {
  id: string                     # ~80 个
  trigger: TriggerEvent          # OnPlay | OnDraw | OnDiscard | OnKill | OnHit | StartTurn | EndTurn | OnTraitFired
  effect: Effect                 # Damage(N, Element) | Heal(N) | Apply(Buff) | Draw(N) | Spawn(Trait) | ...
  value: int | null              # 数值参数
  axis: {                        # 三轴正交分类（A2 研究反推）
    timing: TriggerEvent
    scope: Self | Card | Hand | Battlefield
    school: Fire | Decay | Moon | Iron | Bone | Void   # 6 学派
  }
  rarity: Common | Uncommon | Rare    # 50/22/8 分布（A4 反推）
  removable: bool                # 营地可拆卸入库存
}

# 反应不再是 80×80 查找表，而是注册式触发器栈
SpecialReaction {                 # 仅 20-30 高光时刻（A2 反推）
  watch_for: [TraitId, TraitId]   # 同卡上同时存在
  override_effect: Effect         # 取代两个原效果
  flavor: string                  # "火 + 油 → 爆炸"
}

Inventory {                       # v1 新增
  unsocketed: [Trait]             # 拆卸下来的词条
  capacity: int                   # 起始 5，元进度可扩
}

Enemy {
  id: string
  intent: Intent                  # StS 风意图
  carried_traits: [Trait]         # 1-3 个；普通 60%/30%/10% 给 1/2/3，精英固定 2，Boss 固定 3
  drop_count: int                 # 普通 1 / 精英 2 / Boss 3
}
```

### 战斗结算（触发器栈伪代码）

```python
def play_card(card, target):
    event = OnPlay(card, target)
    for trait in card.all_traits():
        if trait.trigger.matches(event):
            apply_effect(trait.effect)
            emit(OnTraitFired(trait))   # 串联触发

# 特殊反应在 emit() 时插队
def emit(event):
    for reaction in special_reactions:
        if reaction.matches(event, current_card):
            apply_effect(reaction.override_effect)
            return  # 跳过下游
    propagate(event)
```

---

## 5. 风险登记（v1 修正后）

| # | 风险 | 来源 | 缓解策略 |
|---|---|---|---|
| R1 | 词条 × 词条交互平衡 | Q4+Q6 | 触发器栈架构后测试面从 80×80=6400 降到 80 + 25 反应；headless 跑 1 万局基线 |
| R2 | 仅营地拼装 → 战斗内决策可能"换皮 StS" | Q7 | 敌人意图 × 词条触发时机制造张力（A1 反推保留 StS 基线，把创新预算押在词条） |
| R3 | 单局 30-40 分钟 + 25-30 词条/run → 拼装节奏不够爽 | Q8+Q11 | 普通怪 60% 必给 1 词条 + 营地拆卸入库存；首个 boss 后扩 5 库存槽 |
| R4 | 80 词条 + 25 反应 + 三轴标签 = ≥150 条文案 + 数值 | Q4+A4 | 系统化模板（trigger×effect×school 三段式）+ 50/22/8 稀有度模板 |
| R5 | 巫女主题与 StS 2 重叠 | Q1 | 「吞噬式黑魔法」叙事差异化（A5：Cult of the Lamb 视觉路线） |
| R6 | 触发器栈递归/同时触发顺序边界 | v1 数据模型 | OnTraitFired 限定深度 = 2；同事件多词条按 slot index 0→1→2 顺序结算（写入 ADR-001）|

---

## 6. 技术栈（v1 锁定 — A6 反推）

- **引擎**：Godot 4.x（GDScript 主，C# 备）
- **数据层**：**Hybrid Resource + JSON** — Trait/Card 用 Godot Resource（编辑器内可视化、热重载），数值表与本地化用 JSON（外部工具/平衡脚本可读写）
- **战斗 FSM**：[godot-state-charts](https://github.com/derkork/godot-state-charts)（1.5k★ HSM 库），用于 PlayerTurn/EnemyTurn/Resolution 子状态机
- **架构模式**：Action / Interceptor / Validator 三层（参考 [DesirePathGames/Slay-The-Robot](https://github.com/DesirePathGames/Slay-The-Robot) 模板，220★，建议 fork 作为基底）
- **测试**：[GdUnit4](https://github.com/MikeSchulze/gdUnit4)（GDScript 原生单测 + 集成测试）
- **平衡模拟器**：headless 模式
  ```bash
  godot --headless --display-driver headless --audio-driver Dummy -s sim.gd
  ```
  目标：跑 10k run 输出胜率 / 词条选取分布 / 反应触发频次 CSV
- **确定性 RNG**：模板自带 seeded RNG，重放/回归测试必备
- **CI**：GitHub Actions + headless Godot Docker image

---

## 7. 流程状态

| 阶段 | 状态 | 输出 |
|---|---|---|
| 1. grill-with-docs（需求逼问） | ✅ 完成（2026-05-19） | CONTEXT.md v0 |
| 2. 6 路竞品研究（并行 agent） | ✅ 完成（2026-05-19） | `docs/research/A1` ~ `A6.md` |
| 3. CONTEXT v1 反推修正 | ✅ 完成（2026-05-19） | 本文件 v1 |
| 4. /to-prd | ✅ 完成（2026-05-19） | `docs/prd/v0.md` v1（已合并 prototype 反推 M1-M5） |
| 5. /prototype（headless 战斗模拟器） | ✅ 完成（2026-05-19） | `prototype/sim.py`（Python 抛弃式）+ `PROTOTYPE_REPORT.md` |
| 5b. ADR-001（触发器栈结算顺序） | ✅ Accepted（2026-05-19） | `docs/adr/ADR-001-trigger-stack-ordering.md` |
| 6. /to-issues | 🔄 待启动 | issue tracker |
| 7. /tdd + executor 实现 | ⏳ | `src/`（Godot 4.x GDScript）|

---

## 8. ADR 索引

| ADR | 主题 | 状态 |
|---|---|---|
| ADR-001 | 触发器栈结算顺序（slot 0→1→2，OnTraitFired 深度 ≤ 2）| ✅ Accepted（2026-05-19，prototype 1000-run / 56 万 emit / 0 错误实证）|

其余 13 个 grill 决议属"主流路线选择"，未达 ADR 三门槛（难撤回 + 反直觉 + 真权衡）。

`docs/adr/ADR-001-trigger-stack-ordering.md` 已落地。
