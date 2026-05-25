# A6: Godot 4 实现可行性 + 开源参考

> 目标：评估 Godot 4 实现卡牌 roguelike（3 词条槽 + 80 词条 + 50-80 反应对 + StS 风战斗 + 营地炼金台 + 元进度 + headless 模拟器）的可行性，并选定推荐技术栈。
> 调研日期：2026-05-19

---

## Part 1: 开源 Godot 卡牌项目调研

### 1.1 Godot StS-clone / Deckbuilder 框架

| 项目 | Stars | 最后更新 | 语言 | 评估 |
|---|---|---|---|---|
| **guladam/deck_builder_tutorial** | 416 | 2024-10-16 | GDScript | 教学项目，结构清晰；StS 复刻最常用模板 |
| **DesirePathGames/Slay-The-Robot** | 220 | 2026-01-02 | GDScript | 完整框架，Action / Interceptor / Validator 三件套，JSON 驱动卡牌 |
| **db0/hypnagonia** | (Topic 上) | 活跃 | GDScript | 已发行游戏 "Therapy through Nightmares"，复杂 buff / 状态系统参考 |
| **sundowns/deckbuilder-template** | - | - | GDScript | 模板级别，开箱即用 boilerplate |
| **chesedcore/Catena** | 0 | 8 天前 | GDScript | 新框架，"layered framework"，未成熟 |
| **josh5210/Auto_Battler_Game2** | 4 | 2025-04 | GDScript | StS 灵感的自动战斗原型，规模小 |

**详细评估：**

#### guladam/deck_builder_tutorial（416★，最高质量教学）

- **代码质量**：高。MIT 许可，100% GDScript，目录划分严谨：
  ```
  battles/   characters/   common_cards/   custom_resources/
  effects/   enemies/      global/         scenes/
  relics/    statuses/
  scenes/{battle, battle_reward, campfire, card_target_selector,
          card_ui, enemy, event_rooms, map, player, shop, ui}
  ```
- **缺陷**：纯 Resource 数据，**无 headless 测试**，无单元测试。
- **可借鉴**：
  - `card_ui/` 拖拽 + 目标选择（card_target_selector）—— 直接抄
  - `statuses/` buff 框架的 Resource + 信号实现
  - `scenes/campfire` 营地交互（与本项目炼金台思路接近）
  - `custom_resources/` 用 Resource 表达 Card / Enemy / Status 的范式

#### DesirePathGames/Slay-The-Robot（220★，最完整框架）

- **代码质量**：高。MIT，完整 3-Act 结构 + Ascension + Mod 支持。
- **可借鉴的具体模块**：
  - **Action 系统**：可重用 Action 脚本驱动战斗、商店、事件 —— 与本项目"3 词条槽 → 反应触发"高度契合，可直接套
  - **Interceptors**：动态修改 Action（status / relic 都用同一机制）—— 反应对（50-80 个）的天然实现框架
  - **Validators**：条件逻辑驱动 UI 与可玩性约束 —— 词条互斥校验
  - **Deterministic RNG with DI**：headless 模拟器的关键需求，已有现成方案
  - **SerializableData**：自动存读档基类
  - **JSON 驱动卡牌**：导出属性，"几乎可以复刻 StS 全部卡牌"
- **缺陷**：暂无 release，需要从 main 分支 fork 自己改。

### 1.2 拖拽 UI

无独立流行的"卡牌拖拽 UI 插件"。Godot 4 内置 `Control.set_drag_preview()` + `_get_drag_data()` / `_can_drop_data()` / `_drop_data()` 已经足够。
建议直接抄 `guladam/deck_builder_tutorial/scenes/card_ui/` 的实现（Tween + 信号）。

### 1.3 状态机插件

| 项目 | Stars | 最后更新 | 评估 |
|---|---|---|---|
| **derkork/godot-statecharts** | 1.5k | 2026-03-24（v0.22.4） | **强烈推荐**。HSM 层级状态机，节点化声明、guard、delayed transition、调试可视化。GDScript + C# 双支持。资产库可装。 |

- **可借鉴**：直接当依赖用，不用自己写。战斗状态机（PlayerTurn → Resolve → EnemyIntent → EnemyTurn → ...）以及敌人 AI 的"意图"状态非常适合 HSM。
- **关键优势**：声明式、避免"状态爆炸"问题；inactive state 不跑 frame，性能友好。

### 1.4 ECS 插件

| 项目 | Stars | 最后更新 | 评估 |
|---|---|---|---|
| **csprance/GECS** | 526 | 2026-05-14（v8.0.0） | 成熟。Query 缓存 + 编辑器组件可视化 + 调试 viewer + 多人模块。 |

- **结论**：对本项目**不推荐**。卡牌 roguelike 实体数量少（玩家 1 + 敌人 1-3 + 卡 30-80），ECS 的优势（数据局部性、批处理）发挥不出来；Godot 节点 + Resource 组合已能优雅解决，引入 ECS 反而增加心智负担和与 godot-state-charts 的整合成本。**仅在敌人/buff/卡数量超千级才考虑。**

### 1.5 测试框架对比

| 框架 | Stars | 版本支持 | Headless CLI | 备注 |
|---|---|---|---|---|
| **bitwes/Gut** | 2.5k | Godot 4.6.x（v9.6.0） | 良好（`gut_cmdln.gd` + `-gexit` + JUnit XML） | 老牌、社区大、文档全 |
| **MikeSchulze/gdUnit4** | 1.1k | Godot 4.5–4.7 | 优秀（CLI + HTML + JUnit） | 内嵌 inspector、scene 测试模拟输入、fluent 语法 |

两者都能跑 headless CI。GUT 资料更多，GdUnit4 现代化。**功能上 GdUnit4 更强（mock/spy、scene 模拟），但 GUT 学习曲线更平。**

---

## Part 2: 架构选型

### 2.1 Resource-based（GDScript Resource 表 Card / Trait）

| 维度 | 评估 |
|---|---|
| 数据热重载 | **中**：编辑器内改 `.tres` 即时生效；运行时 `ResourceLoader.load(...)` 需要手动重置缓存 |
| 模拟器兼容性 | **中**：Resource 可在 `--headless` 下加载，但加载需要 SceneTree（即使没 UI）；纯数据计算 OK |
| 版本控制 | **中**：`.tres` 是文本格式，能 diff，但 Godot 会重排字段、UID 变动 → diff 噪声较大 |
| 优点 | 强类型、IDE 补全、@export 在编辑器可视化、引用其它 Resource 自然 |
| 缺点 | 嵌套 Resource `duplicate()` 容易共享子资源踩坑（必须用 `DeepDuplicateMode.ALL`）；批量改 80 词条数值要点 80 个文件 |

### 2.2 JSON-based（数据外置）

| 维度 | 评估 |
|---|---|
| 数据热重载 | **强**：JSON 文件 watch + 重读即可，无引擎缓存 |
| 模拟器兼容性 | **强**：headless 下 `FileAccess.open()` + `JSON.parse_string()`，零依赖 |
| 版本控制 | **强**：JSON diff 友好；策划批量改一个文件就能调全部词条 |
| 优点 | 平衡性迭代极快；数据驱动；可被外部工具（Excel 导出脚本）生成 |
| 缺点 | 失去强类型；引用关系需用字符串 ID 维护；编辑器无可视化（要自己写工具） |

### 2.3 Hybrid（Resource for 模板 + JSON for 数值）

| 维度 | 评估 |
|---|---|
| 数据热重载 | **强**：Resource 定义 schema（卡的"形状"），JSON 提供数值 / 名字 / 描述 |
| 模拟器兼容性 | **强**：模拟器只读 JSON 跑数学；UI 只用 Resource 渲染 |
| 版本控制 | **强**：JSON 数值改动 diff 干净；Resource 模板很少变 |
| 优点 | 兼顾类型安全和热改 |
| 缺点 | 需要写 loader（JSON → 注入到 Resource 实例）；初期成本高 |

**结论：Hybrid 最优，特别适合 80 词条 + 50-80 反应对的体量。**

---

## Part 3: 已知坑点

### 3.1 信号系统对深嵌套 UI 的限制

- 信号不支持 `bubble`，深层 Control（卡 → 槽 → 容器 → 手牌）需要逐层 emit 或用全局总线
- 推荐：autoload 一个 `EventBus.gd`，UI 事件全部发到总线再分发，不要让 hand → card → trait_slot 链式连
- `Callable` 绑定参数要小心：bound 参数不易解绑，导致内存泄漏

### 3.2 AnimatedSprite2D vs AnimationPlayer

- **AnimatedSprite2D**：精灵帧动画专用，CPU 便宜，但只能换帧
- **AnimationPlayer**：能驱动任意属性（位置、shader 参数、调用方法），更灵活
- **卡牌动画推荐 AnimationPlayer + Tween 混用**：UI 出牌、抽牌、目标指引用 Tween 写代码；敌人受击、buff 闪光用 AnimationPlayer
- 不要把 AnimationPlayer 用在 60+ 卡的手牌上 —— 实例化成本高，Tween 更轻

### 3.3 C# 与 GDScript 互操作

- **跨边界调用昂贵**：C# 访问 Godot Object 属性要 marshalling；string ↔ NodePath 隐式转换更贵
- **mobile：C# 在 Android/iOS 4.2+ 实验性支持，限制多；Web 不支持**
- **构建链复杂**：改 export 变量必须 rebuild assembly，编辑器内体验差
- **结论**：本项目主语言用 GDScript；仅在确实需要的地方（如 headless 模拟器跑 1 万局的核心计算热点）考虑用 C#，且尽量减少跨边界调用

### 3.4 序列化坑（Resource 嵌套）

- `Resource.duplicate(true)` 的"deep"实际是浅级 deep —— 子 Resource 仍可能共享
- 用 `Resource.duplicate_deep(DeepDuplicateMode.ALL)` 或自己实现深拷贝
- 元进度持久化推荐：**纯 JSON 存档**（不存 Resource 引用），加载后手动重建；避免 `.tres` 路径变动后存档失效
- 卡牌实例的"运行时状态"（升级、临时 buff）不要塞回静态 Resource —— 会污染模板

### 3.5 Mobile 性能

- Control 节点 + Tween 在中端机 60fps 没问题，但**手牌阴影、模糊、CanvasItem material** 是性能杀手
- 建议：阴影用静态预渲染纹理，不要 BackBufferCopy
- 1 万局 headless 模拟纯逻辑（不渲染），手机 CPU 也能跑（数百毫秒级），但平衡性测试更适合 PC CI

---

## Part 4: 推荐技术栈

> 400 字以内的最终推荐。

1. **数据层 — Hybrid（Resource 作 schema + JSON 存数值）**：用 `CardData.gd` / `TraitData.gd` / `ReactionData.gd` 三个 Resource 类定义结构和@export 字段；80 词条和 50-80 反应对存为 `data/traits.json` / `data/reactions.json`，启动时 loader 注入到 Resource 实例。模板少改、数值高频改、diff 友好、模拟器零依赖。

2. **战斗层 — godot-state-charts（1.5k★）**：直接装 v0.22.4，用 HSM 表达 PlayerTurn / Resolve / EnemyIntent / EnemyTurn / Win / Lose；敌人意图作子状态。声明式、无状态爆炸。**不要**自己手写 FSM。

3. **UI 层 — Control + Tween + 自写拖拽**：Godot 4 内置 `_get_drag_data` / `_drop_data` 三件套足够；炼金台预览用 Resource.duplicate(ALL) + 影子 UI；撤销栈用 Command 模式（每个炼金操作一个 Resource）。无须插件。

4. **测试 — GdUnit4（1.1k★）**：现代化、scene 模拟、CLI + JUnit。GUT 也行但 GdUnit4 mock/spy 更好。

5. **headless 模拟器 — `godot --headless --display-driver headless --audio-driver Dummy -s sim.gd`**：sim.gd 继承 SceneTree，纯 JSON + 战斗逻辑（不依赖 UI），跑 1 万局 + 写 CSV。Action / Interceptor 模式从 Slay-The-Robot 抄。Deterministic RNG 注入是关键。

6. **模板推荐**：
   - **主框架抄 `DesirePathGames/Slay-The-Robot`** —— Action / Interceptor / Validator / 确定性 RNG 都现成，最贴近本项目"3 词条 → 反应触发"的需求
   - **UI / 营地交互抄 `guladam/deck_builder_tutorial`** —— `card_ui` 和 `campfire` 直接复用思路

---

## 附：参考链接

- guladam/deck_builder_tutorial — https://github.com/guladam/deck_builder_tutorial
- DesirePathGames/Slay-The-Robot — https://github.com/DesirePathGames/Slay-The-Robot
- derkork/godot-statecharts — https://github.com/derkork/godot-statecharts
- csprance/GECS — https://github.com/csprance/GECS
- bitwes/Gut — https://github.com/bitwes/Gut
- MikeSchulze/gdUnit4 — https://github.com/MikeSchulze/gdUnit4
- Godot Command Line — https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- Godot Resource Class — https://docs.godotengine.org/en/stable/classes/class_resource.html
- Godot C# Basics — https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html
