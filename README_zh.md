# Slay the Robots

一款基于 Godot 4.6 的 Roguelike 卡牌构筑游戏，核心机制为 **词条组合（trait-composition）**。
每张卡牌由若干可复用的小型 *词条*（伤害 / 格挡 / 灼烧 / 共振 / ……）组合而成，
词条在结算过程中可彼此触发反应，从而衍生出涌现式连锁组合。

本项目 fork 自 [Slay-The-Robot](https://github.com/DesirePathGames/Slay-The-Robot)，
原始模板归属与第三方组件清单见 [`NOTICE`](./NOTICE)。

> English README: [README.md](./README.md)

---

## 设计目标

- **少而精**：依靠词条之间的相互反应，少量基础元件即可生出大量组合。
- **可读性**：每一次反应链都可被悬浮预览，玩家在出牌前即可看清完整结算路径。
- **强可测**：核心战斗循环、RNG、词条反应、UI 组合全部覆盖单元测试，目前 285 用例全绿。
- **数据驱动**：卡牌 / 词条 / 敌人 / 掉落表均以 Godot `Resource` 形式定义，便于策划单独迭代。

---

## 技术栈

| 项目      | 说明                                     |
| --------- | ---------------------------------------- |
| 引擎      | Godot 4.6.2 stable                       |
| 语言      | GDScript                                 |
| 测试框架  | GdUnit4 v6.1.3（已 vendored 至 `src/addons/gdUnit4/`） |
| 运行平台  | Windows / Linux / macOS（依 Godot 支持） |

---

## 目录结构

```
.
├── docs/              # 设计文档（PRD / ADR / 工单 / 调研 / 法务）
│   ├── prd/           # 产品需求文档
│   ├── adr/           # 架构决策记录
│   ├── issues/        # ISSUE-XXX 工单
│   └── research/      # 早期调研笔记
├── src/               # Godot 工程根目录（Godot 编辑器请打开此文件夹）
│   ├── core/          # 战斗循环、词条、反应、确定性 RNG
│   ├── data/          # 卡牌 / 词条 / 敌人 / 掉落 Resource
│   ├── ui/            # 场景与视图脚本
│   ├── vfx/           # 粒子场景（反应迸发、击杀吞噬等）
│   ├── tests/         # GdUnit4 测试套件
│   └── addons/        # 第三方 addon（gdUnit4 等）
├── prototype/         # 独立的玩法原型实验
├── tools/             # 一次性脚本（数据校验、生成器）
└── NOTICE             # 第三方组件归属声明
```

---

## 快速上手

### 1. 安装 Godot

前往 <https://godotengine.org/download/> 下载 **Godot 4.6.2 stable**。

### 2. 打开工程

在 Godot 编辑器中，将 **`src/`** 目录作为工程根打开（**不是仓库根目录**）。

### 3. 运行

按 `F5` 或点击编辑器右上角的「运行」按钮即可开始游戏。

---

## 运行测试

整套 GdUnit4 用例可通过命令行无头执行：

```bash
cd src
godot --headless --path . \
  -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -a tests
```

当前 **285 个用例 / 28 个套件** 覆盖：

- 战斗循环（出牌、回合、能量、HP 同步）
- 词条反应矩阵（火 / 腐 / 月 / 铁 / 骨 / 虚 六系两两交互）
- 确定性 RNG（同种子保证完全可复现）
- UI 组合（手牌 / 敌人 / 悬浮预览 / VFX 信号）
- VFX 场景（反应迸发、吞噬击杀、伤害飘字、回血浮动）

HTML 测试报告输出到 `src/reports/report_N/`。

---

## 核心概念速览

- **词条（Trait）**：最小可复用效果单元，描述「在某种触发器上做某件事」。
- **反应（Reaction）**：词条触发后，其他词条可监听并叠加额外效果，形成反应链。
- **卡牌（Card）**：由 1～3 个词条槽位组成。槽位决定结算顺序。
- **敌人随身词条（Carried Trait）**：敌人也带有词条，被击杀后按掉落表概率掉落给玩家。
- **共振 / 抵消**：玩家与敌人词条同时存在时，会产生互相加成或抵消，体现策略深度。

详细规则请阅读 [`docs/prd/v0.md`](./docs/prd/v0.md) 与 [`docs/adr/`](./docs/adr/)。

---

## 当前进度

早期开发原型阶段。

| 模块                  | 状态     |
| --------------------- | -------- |
| 核心战斗循环          | ✅ 完成 |
| 词条反应系统          | ✅ 完成 |
| 单房间战斗 UI         | ✅ 完成 |
| 多敌人目标选择        | ✅ 完成 |
| 回合结算面板          | ✅ 完成 |
| 攻击 / 受击 / 抵抗 VFX | ✅ 完成 |
| 地图节点选择          | 🟡 进行中 |
| 营地（装备 / 拆除）   | 🟡 进行中 |
| 商店                  | 🟡 进行中 |
| 事件                  | ⬜ 未开始 |
| 元进度（解锁 / 升阶）  | ⬜ 未开始 |

完整工单列表见 [`docs/issues/`](./docs/issues)。

---

## 开发约定

- **提交粒度**：一个 ISSUE 一个工单分支，merge 前必须保持全测试通过。
- **新增功能**：先在 `docs/issues/` 起草 ISSUE-XXX；UI 改动需附 PRD 引用。
- **数据资源**：所有新增卡牌 / 词条 / 敌人放入 `src/data/`，并跑 `src/validate_*.py` 校验。
- **VFX**：粒子场景统一放 `src/vfx/`，通过 `AnimSignaler` 信号驱动，避免 UI 直接调用 VFX。

---

## 许可证

MIT —— 详见 [`src/LICENSE`](./src/LICENSE)。
上游模板及全部第三方组件归属请参阅 [`NOTICE`](./NOTICE)。
