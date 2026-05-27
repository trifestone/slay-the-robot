# AI 战斗逻辑 QA 探索与回归修复计划

对象：编码大模型 / 多 Agent 执行系统。

从仓库根目录执行本计划。不要硬编码任何机器相关的绝对路径；除明确标注为 Godot `res://` 或 `user://` 的路径外，本文所有路径均为仓库相对路径。

目标不是只修复几个已知 bug。卡牌表现、胜负判定、敌人死亡逻辑只是人工试玩 demo 时暴露出的少量例子。真正目标是建立一套自动化战斗逻辑 QA 系统，尽可能探索战斗状态空间，发现未知 bug，把每个发现的 bug 转化为确定性回归测试，然后通过有证据的 AI 修复循环完成修复。

## 项目事实

```text
仓库根目录：
.

Godot 工程根目录：
./src

Godot 版本：
4.6.2 stable

已有测试框架：
src/addons/gdUnit4

已有测试：
src/tests/*.gd

核心战斗模块：
src/core/battle_loop.gd
src/core/battle_state.gd
src/core/run.gd
src/core/emit.gd
src/core/reaction_registry.gd
src/core/reaction_predictor.gd
src/core/enemy_factory.gd

已有模拟工具：
src/tools/sim.gd
src/tools/sim_runner.gd
src/tools/sim_diff.gd
```

不要重建测试框架。必须复用现有 GdUnit4 测试套件和 simulation harness。

## 核心测试策略

建立四层测试体系：

```text
1. 规则回归测试
   验证已知玩法规则。

2. 不变量测试
   每个战斗动作后检查战斗状态是否合法。

3. 随机探索 / fuzz 测试
   使用大量 seed、随机牌组、随机敌人、随机合法动作探索未知 bug。

4. AI 修复循环
   将每个发现的失败转化为最小确定性回归测试，然后修复并验证。
```

## P0：战斗不变量

新增：

```text
src/tests/support/invariant_checks.gd
src/tests/support/state_snapshot.gd
src/tests/support/fixture_factory.gd
```

`invariant_checks.gd` 是整个 QA 系统的核心。它必须能被 GdUnit 测试和 simulation 代码复用。

至少覆盖以下不变量：

```text
玩家生命：
- player_hp >= 0
- player_hp <= max_hp
- max_hp > 0
- player_hp == 0 时必须处于 lost 或合理的战斗结束状态

能量：
- energy >= 0
- energy <= max_energy
- max_energy > 0
- 出牌失败不能消耗 energy

牌区：
- hand 不含 null card
- deck 不含 null card
- discard 不含 null card
- hand.size <= 10
- 出牌后卡牌必须离开 hand
- 正常出牌后卡牌必须进入合法区域：discard、exhaust 或 limbo
- 同一张卡牌实例不能同时存在于多个牌区

敌人：
- enemy hp >= 0
- 死亡敌人 hp == 0
- primary_enemy_idx 必须合法
- 除非所有敌人都死亡，否则 primary enemy 必须是活敌人
- 所有敌人死亡时 is_over().won 必须为 true
- 只死亡部分敌人时不应胜利
- 死亡敌人不能行动
- 死亡敌人不能被选为合法目标

战斗阶段：
- ongoing、won、lost 不能互相矛盾
- 战斗结束后 play_card 不能继续修改核心状态
- 战斗结束后 end_turn 不能触发敌人行动
- battle_finished signal 不能重复触发

结算日志：
- trait_fire_log entry 字段完整
- damage_events 中 dmg/block 不能为负数
- fire_depth 在结算结束后必须回到 0
- cooldown_table 在回合切换后应合理重置
- 结算链不能无限递归
```

把不变量接入现有测试：

```text
src/tests/test_battle_loop.gd
src/tests/test_battle_scene.gd
src/tests/test_run_sequence.gd
src/tests/test_sim_harness.gd
```

在这些关键动作后调用不变量：

```text
start_battle
play_card
end_turn
enemy death
battle finish
run battle
```

## P1：状态快照

`state_snapshot.gd` 必须能把 `BattleState` 和 `RunState` 转成稳定 Dictionary / JSON，用作失败证据。

必须包含：

```text
seed
turn
phase
player_hp
max_hp
energy
max_energy
primary_enemy_idx
is_over result

enemies:
  id
  hp
  max_hp
  intent_damage
  block
  alive/dead

hand:
  size
  card ids 或 trait ids

deck size
discard size
trait_fire_log tail
damage_events tail
battle_log tail 30 lines
```

失败时写入：

```text
user://qa_failures/
user://qa_snapshots/
```

## P2：测试 Fixture 工厂

`fixture_factory.gd` 用于集中管理当前测试中重复的 helper：

```text
make_trait(id, trigger, effect_type, effect_value)
make_card(traits)
make_deck(cards)
make_enemy(id, hp, intent_damage)
make_enemy_group(count, hp_profile)
make_run_state(seed, deck, hp)
```

Fixture 必须保持确定性、小型、可复现。

## P3：随机战斗 Fuzz

新增：

```text
src/tests/test_battle_fuzz.gd
src/tests/test_battle_property_randomized.gd
src/tests/test_run_fuzz.gd
```

Fuzz 的目标不是验证固定结果，而是发现非法状态。

`test_battle_fuzz.gd` 应执行：

```text
1. 生成 seed。
2. 生成玩家 HP。
3. 生成 5-20 张卡牌的牌组。
4. 每张卡随机组合 1-3 个 trait。
5. 生成 1-3 个敌人。
6. 反复选择随机合法动作：
   - play_card
   - end_turn
   - choose target
7. 每个动作后运行 invariant checks。
8. 记录失败 seed、动作序列、失败不变量和状态快照。
```

只能选择合法动作：

```text
energy 足够才允许 play_card
card 在 hand 中才允许 play_card
target 必须是活敌人
战斗结束后停止继续行动，只验证锁定状态
```

每个 fuzz 失败必须生成可复现 artifact：

```json
{
  "seed": 12345,
  "initial_state": {},
  "actions": [
    "start_battle",
    "play_card hand[2] target[0]",
    "end_turn",
    "play_card hand[0] target[1]"
  ],
  "failed_invariant": "dead enemy attacked",
  "snapshot": "user://qa_snapshots/fuzz_12345.json"
}
```

## P4：Seed Replay 测试

为 fuzz 失败新增确定性 replay 支持。

当 fuzz 发现失败：

```text
1. 保存 seed 和动作序列。
2. 生成或手写一个确定性的 GdUnit 测试。
3. 在修复前确认该 replay 测试失败。
4. 修复代码。
5. 永久保留该 replay 测试。
```

这一步的目的：把探索发现的 bug 转化为永久回归覆盖。

## P5：轻量模型测试

新增：

```text
src/tests/test_battle_model_properties.gd
```

不要实现另一个完整游戏。只建立一个轻量模型，追踪：

```text
player_hp
energy
hand_count
alive_enemy_count
battle_finished
```

检查高层一致性：

```text
如果模型认为所有敌人死亡，真实 is_over().won 必须为 true。
如果模型认为 energy 不足，真实 play_card 不能成功。
如果模型认为战斗已经结束，真实状态不能因玩家动作继续变化。
如果模型认为敌人死亡，真实敌人不能攻击。
```

## P6：变形测试 / Metamorphic Tests

新增：

```text
src/tests/test_battle_metamorphic.gd
```

这些测试验证关系，而不是硬编码结果：

```text
相同 seed 和相同动作序列必须产生相同结果。
相同 seed 和相同动作序列必须产生相同 battle_log hash。
同一张 Damage 卡打 10 HP 敌人和 20 HP 敌人时，造成的伤害值应一致。
只改变敌人 max_hp 不应改变玩家起手牌。
只改变玩家 max_hp 不应改变敌人初始 intent。
相同洗牌 seed 必须产生相同起手牌顺序。
```

这类测试很适合发现 RNG 泄漏、状态泄漏、UI/Core 耦合 bug。

## P7：Simulation 回归强化

强化：

```text
src/tools/sim.gd
src/tools/sim_runner.gd
src/tools/sim_diff.gd
```

Simulation 不应只看胜率。

新增计数器：

```text
crash_count
invariant_violation_count
stuck_count
max_turns_exceeded_count
invalid_state_count
dead_enemy_action_count
post_finish_mutation_count
negative_energy_count
negative_hp_count
duplicate_card_zone_count
```

在 simulation 中，每个战斗动作后都调用 invariant checks。

如果 simulation 发现失败，写入：

```text
user://qa_failures/seed_XXXXX.json
```

包含：

```text
seed
battle index
action sequence
failure type
state snapshot
battle_log tail
```

同时修复当前 `sim_runner.gd` 中的盲点：

```text
reactions_triggered 不能硬编码为 0。
total_turns 不能用 battles_won 代替。
```

建议在 `Run.play_battle()` 返回值中增加：

```gdscript
{
  "won": won_battle,
  "hp_left": run_state["player_hp"],
  "battle_log_size": state.battle_log.size(),
  "turns": state.turn,
  "reaction_fire_count": _count_reactions(state.trait_fire_log)
}
```

Reaction 计数规则：

```text
entry["source"] == "reaction"
```

## P8：QA 命令入口

新增：

```text
tools/qa/run_fast.ps1
tools/qa/run_fuzz.ps1
tools/qa/run_sim.ps1
tools/qa/run_regression.ps1
tools/qa/write_regression_artifact.py
```

`run_fast.ps1`：

```powershell
Set-Location "$PSScriptRoot/../../src"
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests
exit $LASTEXITCODE
```

`run_sim.ps1`：

```powershell
Set-Location "$PSScriptRoot/../../src"

godot --headless --path . -s tools/sim.gd -- --runs 1000 --seed-base 1 --out user://sim_results.csv
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

godot --headless --path . -s tools/sim_diff.gd -- --actual user://sim_results.csv --baseline res://prototype/sim_results.csv --out user://sim_diff.txt
exit $LASTEXITCODE
```

`run_regression.ps1` 顺序：

```text
1. 运行现有全量 GdUnit 测试。
2. 运行 battle fuzz。
3. 运行 run fuzz。
4. 运行 1000-run sim。
5. 运行 sim_diff。
6. 生成 .omc/state/regression/R###.json。
```

## P9：OMC 回归产物

每轮 QA 必须写入：

```text
.omc/state/regression/R###.json
```

全绿示例：

```json
{
  "round_n": 1,
  "started_at": "ISO8601",
  "finished_at": "ISO8601",
  "tests_total": 0,
  "tests_failed": 0,
  "fuzz_seeds_run": 1000,
  "fuzz_failures": 0,
  "sim_runs": 1000,
  "sim_failures": 0,
  "failed_test_ids": [],
  "failed_seeds": [],
  "error_fingerprints": [],
  "failure_artifacts": [],
  "verdict": "green"
}
```

失败 artifact 必须包含：

```text
失败 seed
动作序列
失败不变量
snapshot 路径
最小 replay 测试路径
疑似文件
复现命令
```

## P10：AI 修复循环

当 fuzz 或 simulation 发现 bug，不要直接 patch 代码。

使用以下循环：

```text
1. debugger 读取 seed、动作序列、snapshot、battle_log。
2. test-engineer 将该 seed 和动作序列转化为最小 GdUnit replay 测试。
3. verifier 确认 replay 测试在修复前失败。
4. executor 修复生产代码。
5. verifier 运行：
   - 新增 replay 测试
   - 相关 focused tests
   - 全量 GdUnit suite
   - fuzz/sim regression
6. code-reviewer 检查 diff 范围和回归风险。
```

规则：

```text
fuzz 发现 bug
=> deterministic replay test
=> code fix
=> permanent regression coverage
```

## OMC Agent 分工

```text
qa-tester:
运行 run_regression.ps1，收集 failed seeds 和 artifacts。

test-engineer:
编写 invariants、fuzz tests、metamorphic tests、replay tests。

debugger:
使用 seed、动作序列、snapshot、logs 定位根因。

executor:
修复 battle_loop、battle_state、emit、run、battle_scene 或相关代码。

code-reviewer:
检查修复是否聚焦、是否保持 deterministic、是否只是 UI workaround。

verifier:
重新运行 regression，更新 GREEN_GATE / NO_PROGRESS_LIMIT 状态。

writer:
撰写 handoff，记录发现的 bug、已固化 seed、剩余风险。
```

## Matt Pocock Skills 使用要求

按语义使用这些工作流，即使本地 skill 名称不同也要遵守：

```text
tdd:
所有修复必须从失败测试开始。

diagnose:
修复前必须最小化 fuzz 失败，禁止猜测。

grill-with-docs:
当行为与 docs/prd/v0.md、docs/adr/ADR-001、docs/issues/*.md 冲突时，先对齐文档。

grill-me:
规则不清楚时提交澄清问题，不要自行发明产品行为。

handoff:
每轮 QA 结束后记录新增测试、发现的 bug、已修复 seed、未解决风险。
```

## 澄清协议

以下情况不要猜：

```text
某个 fuzz failure 可能是设计行为而非 bug。
overkill 伤害是否应溢出到下一个敌人不明确。
玩家和敌人同时死亡时胜负优先级不明确。
死亡敌人在当前结算链中是否触发死亡效果或掉落不明确。
战斗结束后动画是否可继续播放但状态禁止变化不明确。
trait 文案和实际效果冲突。
```

写入：

```text
.omc/state/clarifications/pending/Q###.json
```

## 执行顺序

严格按以下顺序执行：

```text
P0:
创建 invariant_checks.gd、state_snapshot.gd、fixture_factory.gd。

P1:
把 invariants 接入现有 battle_loop、battle_scene、run_sequence 测试。

P2:
新增 battle fuzz：随机合法动作 + 每步 invariant checks。

P3:
新增 deterministic seed replay 支持。

P4:
新增 metamorphic tests：determinism、状态关系、battle_log hash。

P5:
强化 sim_runner：记录 invariant failures、stuck detection、invalid state detection、failed seed artifacts。

P6:
新增 tools/qa/run_regression.ps1 和 R###.json 输出。

P7:
运行探索测试并收集 failing seeds。

P8:
把每个 failing seed 转化为最小 GdUnit regression test。

P9:
修复 bug。

P10:
运行全量回归。连续两轮 green 后才停止。
```

## 退出条件

```text
GREEN_GATE:
连续两轮满足：
- full GdUnit passes
- battle fuzz passes
- run fuzz passes
- simulation passes
- sim_diff passes

NO_PROGRESS_LIMIT:
连续三轮满足：
- failed seeds 相同
- error fingerprints 相同
- 没有有效代码变更

达到 NO_PROGRESS_LIMIT 时暂停，并输出人工介入报告。
```

## 最终交付物

输出：

```text
1. 新增的自动化探索测试文件。
2. 不变量列表。
3. Fuzz 策略。
4. 发现的 bug。
5. 每个 bug 对应的 failed seed。
6. 每个 failed seed 对应的 GdUnit replay test。
7. 修复文件。
8. 最新 .omc/state/regression/R###.json。
9. 最终回归命令和结果。
```

成功标准不是“几个已知 bug 被修好了”。成功标准是：

```text
项目现在能持续自动探索战斗状态空间，发现未知战斗逻辑 bug，将每个 bug 转化为确定性回归覆盖，并通过已验证的 AI 循环完成修复。
```
