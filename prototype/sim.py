"""
Headless 战斗模拟器 — 卡牌词条拼装 Roguelike Prototype
Python 抛弃式实现（A6 反推：Godot 4.x 是最终目标，但 prototype 用 Python 加速验证数据模型）

验证目标：
1. 触发器栈架构（CONTEXT §4 战斗结算伪代码）能跑通
2. 单 run 数值起点（A4 §1.6）：玩家 80 HP / 普 12-25 / 精 40-60 / boss 100-180
3. 胜率落在 50-60%（PRD §5.2 平衡基线）
4. 词条选取分布、反应触发频次能产出 CSV

跑 1000 run 输出 sim_results.csv。
"""

from __future__ import annotations
import random
import csv
import sys
from dataclasses import dataclass, field
from enum import Enum
from collections import Counter, defaultdict
from typing import Callable

# =====================================================================
# 1. 数据模型（CONTEXT §4 v1）
# =====================================================================


class TriggerEvent(Enum):
    OnPlay = "OnPlay"
    OnDraw = "OnDraw"
    OnDiscard = "OnDiscard"
    OnKill = "OnKill"
    OnHit = "OnHit"
    StartTurn = "StartTurn"
    EndTurn = "EndTurn"
    OnTraitFired = "OnTraitFired"


class School(Enum):
    Fire = "Fire"
    Decay = "Decay"
    Moon = "Moon"
    Iron = "Iron"
    Bone = "Bone"
    Void = "Void"


class Rarity(Enum):
    Common = "Common"
    Uncommon = "Uncommon"
    Rare = "Rare"


class BaseType(Enum):
    Attack = "Attack"
    Skill = "Skill"
    Rite = "Rite"


@dataclass
class Trait:
    id: str
    trigger: TriggerEvent
    school: School
    rarity: Rarity
    value: int
    # effect 用 callable 表达；prototype 不做 ECS,直接函数闭包
    effect: Callable[["BattleState", "Card", int], None]
    flavor: str = ""

    def __hash__(self) -> int:
        return hash(self.id)


@dataclass
class SpecialReaction:
    """20-30 高光时刻：火+油→爆炸 类（PRD §4.4）"""

    watch_for: tuple[str, str]  # 同卡上同时存在的两个 trait id
    override: Callable[["BattleState", "Card"], None]
    flavor: str = ""


@dataclass
class Card:
    base: BaseType
    slots: list[Trait | None] = field(default_factory=lambda: [None, None, None])
    energy_cost: int = 1

    def all_traits(self) -> list[Trait]:
        return [t for t in self.slots if t is not None]

    def has_traits(self, a_id: str, b_id: str) -> bool:
        ids = {t.id for t in self.all_traits()}
        return a_id in ids and b_id in ids


@dataclass
class Enemy:
    name: str
    hp: int
    max_hp: int
    intent_damage: int
    carried_traits: list[Trait] = field(default_factory=list)
    is_elite: bool = False
    is_boss: bool = False


# =====================================================================
# 2. 战斗状态（trigger stack 实现核心）
# =====================================================================


@dataclass
class BattleState:
    player_hp: int
    enemy: Enemy
    energy: int = 3
    hand: list[Card] = field(default_factory=list)
    deck: list[Card] = field(default_factory=list)
    discard: list[Card] = field(default_factory=list)
    reactions: list[SpecialReaction] = field(default_factory=list)
    # 统计:本回合反应触发次数 / 本 run 词条触发分布
    reaction_log: list[str] = field(default_factory=list)
    trait_fire_log: list[str] = field(default_factory=list)
    # 触发器栈深度（CONTEXT §6 R6: OnTraitFired 深度 ≤ 2）
    fire_depth: int = 0


def emit(state: BattleState, event: TriggerEvent, card: Card):
    """触发器栈核心 — CONTEXT §4 战斗结算伪代码"""
    # 特殊反应优先级最高（同卡两 trait 同时存在 → 取代两原效果）
    for r in state.reactions:
        a, b = r.watch_for
        if card.has_traits(a, b):
            state.reaction_log.append(r.flavor)
            r.override(state, card)
            return  # 跳过下游词条结算

    # 常规：按 slot 0→1→2 顺序结算（ADR-001）
    for trait in card.all_traits():
        if trait.trigger == event:
            state.trait_fire_log.append(trait.id)
            trait.effect(state, card, trait.value)
            # 串联触发：OnTraitFired 深度 ≤ 2
            if state.fire_depth < 2:
                state.fire_depth += 1
                emit(state, TriggerEvent.OnTraitFired, card)
                state.fire_depth -= 1


def play_card(state: BattleState, card: Card):
    if state.energy < card.energy_cost:
        return False
    state.energy -= card.energy_cost
    emit(state, TriggerEvent.OnPlay, card)
    state.discard.append(card)
    return True


def deal_to_enemy(state: BattleState, dmg: int):
    state.enemy.hp = max(0, state.enemy.hp - dmg)


# =====================================================================
# 3. 占位词条池（10 词条覆盖 6 学派 / 触发时机正交格）
# =====================================================================


def _trait_flame(state, card, v):
    deal_to_enemy(state, v)


def _trait_oil(state, card, v):
    # 占位:给敌人加状态 = 直接累计后续伤害加成
    state.enemy.hp -= 0  # 不直接打;让 reaction 接管


def _trait_bone_harvest(state, card, v):
    # 占位:抽 1 张
    if state.deck:
        state.hand.append(state.deck.pop())


def _trait_lunar_echo(state, card, v):
    # EndTurn 抽 v 张
    for _ in range(v):
        if state.deck:
            state.hand.append(state.deck.pop())


def _trait_void_consume(state, card, v):
    # OnTraitFired 回血 v(每 emit 上限保护通过 fire_depth)
    state.player_hp = min(80, state.player_hp + v)


def _trait_iron_guard(state, card, v):
    # 占位:格挡 = 直接给玩家加 v HP 上限内
    state.player_hp = min(80, state.player_hp + v)


def _trait_decay_bite(state, card, v):
    deal_to_enemy(state, v)


def _trait_frost(state, card, v):
    deal_to_enemy(state, v)


def _trait_water(state, card, v):
    state.player_hp = min(80, state.player_hp + v // 2)


def _trait_strike(state, card, v):
    deal_to_enemy(state, v)


TRAIT_POOL = [
    Trait("flame_brand", TriggerEvent.OnPlay, School.Fire, Rarity.Common, 4, _trait_flame, "灼焰烙印"),
    Trait("oil_slick", TriggerEvent.OnPlay, School.Fire, Rarity.Common, 1, _trait_oil, "渗油"),
    Trait("bone_harvest", TriggerEvent.OnKill, School.Bone, Rarity.Uncommon, 1, _trait_bone_harvest, "骨收"),
    Trait("lunar_echo", TriggerEvent.EndTurn, School.Moon, Rarity.Uncommon, 1, _trait_lunar_echo, "月之回响"),
    Trait("void_consume", TriggerEvent.OnTraitFired, School.Void, Rarity.Rare, 2, _trait_void_consume, "虚空吞噬"),
    Trait("iron_guard", TriggerEvent.OnPlay, School.Iron, Rarity.Common, 3, _trait_iron_guard, "铁卫"),
    Trait("decay_bite", TriggerEvent.OnPlay, School.Decay, Rarity.Common, 5, _trait_decay_bite, "腐噬"),
    Trait("frost_bite", TriggerEvent.OnPlay, School.Moon, Rarity.Common, 4, _trait_frost, "霜啃"),
    Trait("water_drop", TriggerEvent.OnPlay, School.Decay, Rarity.Common, 4, _trait_water, "水滴"),
    Trait("strike_basic", TriggerEvent.OnPlay, School.Iron, Rarity.Common, 6, _trait_strike, "强袭"),
]

TRAIT_BY_ID = {t.id: t for t in TRAIT_POOL}

# 5 占位反应（PRD §4.4 示例）
def _react_explosion(state, card):
    deal_to_enemy(state, 12)
    deal_to_enemy(state, 4)  # 范围溅射占位


def _react_freeze(state, card):
    deal_to_enemy(state, 8)
    state.enemy.intent_damage = 0


def _react_plague(state, card):
    deal_to_enemy(state, 15)


def _react_purify(state, card):
    state.player_hp = min(80, state.player_hp + 3)


def _react_soulbone(state, card):
    if state.deck:
        state.hand.append(state.deck.pop())
    deal_to_enemy(state, 6)


REACTION_POOL = [
    SpecialReaction(("flame_brand", "oil_slick"), _react_explosion, "火 + 油 → 爆炸"),
    SpecialReaction(("frost_bite", "water_drop"), _react_freeze, "寒 + 水 → 冰封"),
    SpecialReaction(("decay_bite", "oil_slick"), _react_plague, "毒 + 腐 → 瘟疫"),
    SpecialReaction(("iron_guard", "water_drop"), _react_purify, "铁 + 水 → 净化"),
    SpecialReaction(("bone_harvest", "void_consume"), _react_soulbone, "骨收 + 灵吸 → 骸魂"),
]


# =====================================================================
# 4. Run 生成（PRD §4.8 节奏）
# =====================================================================


def make_initial_deck(rng: random.Random) -> list[Card]:
    """初始卡组 15-20 张（CONTEXT Q10），slot[0] 锁基底自带"""
    deck = []
    # 10 Attack + 5 Skill + 3 Rite（PRD §4.5）
    for _ in range(10):
        c = Card(BaseType.Attack, energy_cost=1)
        c.slots[0] = TRAIT_BY_ID["strike_basic"]
        deck.append(c)
    for _ in range(5):
        c = Card(BaseType.Skill, energy_cost=1)
        c.slots[0] = TRAIT_BY_ID["iron_guard"]
        deck.append(c)
    for _ in range(3):
        c = Card(BaseType.Rite, energy_cost=2)
        c.slots[0] = TRAIT_BY_ID["lunar_echo"]
        deck.append(c)
    rng.shuffle(deck)
    return deck


def populate_starter_traits(deck: list[Card], rng: random.Random):
    """模拟首战前已装 5 个起手词条（PRD §4.5 营地拼装的 PoC 简化版）"""
    starter_pool = [TRAIT_BY_ID[i] for i in ("flame_brand", "decay_bite", "frost_bite", "oil_slick", "water_drop")]
    socketable = [c for c in deck if c.base == BaseType.Attack]
    rng.shuffle(socketable)
    for trait, card in zip(starter_pool, socketable):
        card.slots[1] = trait


def gen_enemy(rng: random.Random, kind: str) -> Enemy:
    """A4 §1.6 数值起点"""
    if kind == "boss":
        hp = rng.randint(100, 180)
        intent = rng.randint(15, 25)
        carried_n = 3
    elif kind == "elite":
        hp = rng.randint(40, 60)
        intent = rng.randint(8, 14)
        carried_n = 2
    else:  # normal
        hp = rng.randint(12, 25)
        intent = rng.randint(5, 9)
        carried_n = rng.choices([0, 1, 2], weights=[10, 60, 30])[0]

    carried = rng.sample(TRAIT_POOL, k=min(carried_n, len(TRAIT_POOL)))
    return Enemy(
        name=f"{kind}_{hp}",
        hp=hp,
        max_hp=hp,
        intent_damage=intent,
        carried_traits=carried,
        is_elite=kind == "elite",
        is_boss=kind == "boss",
    )


# =====================================================================
# 5. 战斗循环
# =====================================================================


def fight(state: BattleState, rng: random.Random, max_turns: int = 20) -> bool:
    """返回 True = 玩家赢"""
    full_deck = state.deck.copy()
    rng.shuffle(full_deck)
    state.deck = full_deck
    state.hand = []
    state.discard = []

    for turn in range(max_turns):
        # StartTurn
        state.energy = 3
        # 抽 5
        for _ in range(5):
            if not state.deck:
                state.deck = state.discard
                state.discard = []
                rng.shuffle(state.deck)
            if state.deck:
                state.hand.append(state.deck.pop())

        for card in state.hand:
            emit(state, TriggerEvent.StartTurn, card)

        # 简易 AI: 按 cost 升序贪心出
        state.hand.sort(key=lambda c: c.energy_cost)
        played = []
        for card in list(state.hand):
            if play_card(state, card):
                played.append(card)
        for c in played:
            state.hand.remove(c)

        if state.enemy.hp <= 0:
            for trait in state.enemy.carried_traits:
                # 占位:OnKill 触发(模拟器不真持有,记录触发即可)
                state.trait_fire_log.append(f"kill_{trait.id}")
            return True

        # EndTurn
        for card in state.hand:
            emit(state, TriggerEvent.EndTurn, card)

        # Enemy hits
        state.player_hp -= state.enemy.intent_damage
        if state.player_hp <= 0:
            return False

        # 弃手
        state.discard.extend(state.hand)
        state.hand = []

    return state.enemy.hp <= 0


# =====================================================================
# 6. Run 模拟（18 战 / 3 幕）
# =====================================================================


def run_battle_sequence(seed: int) -> dict:
    rng = random.Random(seed)
    deck = make_initial_deck(rng)
    populate_starter_traits(deck, rng)
    player_hp = 80
    inventory: list[Trait] = []

    # 反应配对查询表(用于镶嵌时优先配对可反应的 trait)
    pair_for: dict[str, list[str]] = defaultdict(list)
    for r in REACTION_POOL:
        a, b = r.watch_for
        pair_for[a].append(b)
        pair_for[b].append(a)

    # 18 战:12 普 + 3 精 + 3 boss(分 3 幕,每幕末 1 精 + 1 boss)
    sequence = []
    for act in range(3):
        for _ in range(4):
            sequence.append("normal")
        sequence.append("elite")
        sequence.append("boss")

    traits_acquired: list[str] = []
    reaction_total = Counter()
    trait_fires = Counter()
    battles_won = 0
    final_outcome = "won"

    for fight_idx, kind in enumerate(sequence):
        enemy = gen_enemy(rng, kind)
        state = BattleState(
            player_hp=player_hp,
            enemy=enemy,
            deck=deck.copy(),
            reactions=REACTION_POOL.copy(),
        )
        won = fight(state, rng)
        reaction_total.update(state.reaction_log)
        trait_fires.update(state.trait_fire_log)

        if not won:
            final_outcome = "lost"
            break

        battles_won += 1
        # 战后回血占位:每战 +5 HP(模拟营地恢复,A4 的 30% HP 治疗近似)
        player_hp = min(80, state.player_hp + 5)
        # 吞噬词条 → 入库存(简化:全收)
        for t in enemy.carried_traits:
            inventory.append(t)
            traits_acquired.append(t.id)
        # 营地拼装策略:优先把库存 trait 镶到"已有反应配对"的卡上
        if (fight_idx + 1) % 2 == 0:
            mounted = []
            for trait in inventory:
                best_card = None
                # 找一张已经有反应配对 trait 的卡的空槽
                for card in deck:
                    if any(s and s.id in pair_for.get(trait.id, []) for s in card.slots):
                        if card.slots[1] is None or card.slots[2] is None:
                            best_card = card
                            break
                # 否则随便找空槽
                if best_card is None:
                    for card in deck:
                        if card.slots[1] is None or card.slots[2] is None:
                            best_card = card
                            break
                if best_card:
                    if best_card.slots[1] is None:
                        best_card.slots[1] = trait
                    elif best_card.slots[2] is None:
                        best_card.slots[2] = trait
                    mounted.append(trait)
            for t in mounted:
                inventory.remove(t)

    return {
        "seed": seed,
        "outcome": final_outcome,
        "battles_won": battles_won,
        "final_hp": player_hp,
        "traits_acquired_count": len(traits_acquired),
        "traits_acquired": traits_acquired,
        "reactions_triggered": dict(reaction_total),
        "trait_fires": dict(trait_fires),
    }


# =====================================================================
# 7. 1000 run 模拟入口
# =====================================================================


def main(n_runs: int = 1000):
    print(f"[sim] 跑 {n_runs} 局，seed = 0..{n_runs-1}")
    results = []
    win_count = 0
    trait_pick_dist = Counter()
    reaction_freq = Counter()
    trait_fire_dist = Counter()
    final_hp_sum = 0
    battles_won_sum = 0

    for seed in range(n_runs):
        r = run_battle_sequence(seed)
        results.append(r)
        if r["outcome"] == "won":
            win_count += 1
        trait_pick_dist.update(r["traits_acquired"])
        reaction_freq.update(r["reactions_triggered"])
        trait_fire_dist.update(r["trait_fires"])
        final_hp_sum += r["final_hp"]
        battles_won_sum += r["battles_won"]

    win_rate = win_count / n_runs
    avg_battles = battles_won_sum / n_runs
    avg_hp = final_hp_sum / n_runs

    print(f"[sim] 胜率 = {win_rate*100:.1f}%  目标区间 50-60%")
    print(f"[sim] 平均通关战数 = {avg_battles:.1f} / 18")
    print(f"[sim] 平均结算 HP = {avg_hp:.1f}")
    print(f"[sim] 词条选取 top5: {trait_pick_dist.most_common(5)}")
    print(f"[sim] 反应触发 top5: {reaction_freq.most_common(5)}")

    # 写 CSV
    out_dir = "C:/Users/zuolei01/Documents/MyGame/prototype"
    with open(f"{out_dir}/sim_results.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["seed", "outcome", "battles_won", "final_hp", "traits_acquired_count"])
        for r in results:
            w.writerow([r["seed"], r["outcome"], r["battles_won"], r["final_hp"], r["traits_acquired_count"]])

    with open(f"{out_dir}/trait_distribution.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["trait_id", "pick_count", "fire_count"])
        for tid in TRAIT_BY_ID:
            w.writerow([tid, trait_pick_dist.get(tid, 0), trait_fire_dist.get(tid, 0)])

    with open(f"{out_dir}/reaction_frequency.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["reaction_flavor", "trigger_count", "per_run"])
        for r in REACTION_POOL:
            cnt = reaction_freq.get(r.flavor, 0)
            w.writerow([r.flavor, cnt, f"{cnt/n_runs:.2f}"])

    print(f"[sim] CSV 写入: {out_dir}/")
    print(f"[sim] 自检:")
    print(f"  [{'OK' if 50 <= win_rate*100 <= 60 else 'FAIL'}] 胜率达标={50 <= win_rate*100 <= 60} (实际 {win_rate*100:.1f}%)")
    print(f"  [OK] trigger stack 未爆栈(fire_depth <= 2 全程无递归错误)")


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    main(n)
