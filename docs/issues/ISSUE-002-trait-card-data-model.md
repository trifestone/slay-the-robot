# ISSUE-002 — Trait + Card data model (Hybrid Resource+JSON) with `cooldown_per_turn`

**Labels**: `enhancement`, `AFK`, `status:ready-for-agent`
**User Story**: Foundation for US-01, US-06 (data-model side of every story)
**Estimate**: M (2-8h)

## What
Implement the core data model in Godot 4: `Trait`, `Card`, `Slot`, `SpecialReaction`, `Inventory`, `Enemy` as `Resource` subclasses, with values seeded from JSON files (`data/traits.json`, `data/reactions.json`). Include the M1 `cooldown_per_turn` field on Trait. End-to-end: a fixture loads 5 sample Traits + 1 Card from JSON via Resource and one trait fires correctly via a unit test.

## Why
PRD §4.1 + CONTEXT §4 define the schema. M1 (PRD §4.1 footnote) requires `cooldown_per_turn` to prevent rare-trait fire spam observed in prototype (`void_consume` 15238 times / 1k runs).

## Acceptance criteria
- [ ] `src/data/trait.gd` extends `Resource` with fields: `id, trigger, effect_type, effect_value, axis_timing, axis_scope, axis_school, rarity, cooldown_per_turn, removable, flavor`.
- [ ] `src/data/card.gd` extends `Resource` with `base, slots: Array[Slot]` (length 3).
- [ ] `src/data/slot.gd` extends `Resource` with `index, trait, locked`. `slot[0].locked == true` enforced in setter.
- [ ] `src/data/reaction.gd` extends `Resource` with `watch_for: Array[StringName], timing, override_effect, flavor`.
- [ ] `src/data/inventory.gd` with `unsocketed: Array[Trait]`, `capacity: int`.
- [ ] `src/data/enemy.gd` with `id, intent, carried_traits, drop_count`.
- [ ] `src/data/loader.gd` reads `data/traits.json` (5 sample traits including `flame_brand`, `oil_slick`, `bone_harvest`, `lunar_echo`, `void_consume` from PRD §4.1) and produces typed Resource instances.
- [ ] Validator enforces: traits with `trigger ∈ {OnTraitFired, OnKill}` MUST have `cooldown_per_turn ≥ 1`; raises asserting error otherwise.
- [ ] `tests/test_data_model.gd` covers: JSON load round-trip, slot[0].locked invariant, validator catches missing cooldown on `void_consume`-like trait, sample `flame_brand` Trait fires once when unit test calls a stubbed `apply_effect`.

## Implementation hints
- Files: `src/data/{trait,card,slot,reaction,inventory,enemy,loader}.gd`, `data/traits.json`, `data/reactions.json`, `tests/test_data_model.gd`
- Use enum singletons in `src/core/enums.gd` for `TriggerEvent`, `Element`, `Rarity`, `School`, `Scope`.
- Reference PRD §4.1 Trait field example table; CONTEXT §4 data model.

## Blocked-by
- ISSUE-001

## Out of scope (this issue)
- emit() trigger stack → ISSUE-003
- SpecialReaction matching/firing logic → ISSUE-004
- Battle loop integration → ISSUE-005

## Source
- CONTEXT §4 数据模型 v1
- PRD §4.1 + M1 footnote (cooldown_per_turn)
- PROTOTYPE_REPORT §2.5 / §3 修订项 #2
