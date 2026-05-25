# ISSUE-023 — Battle scene assembly + run_root integration

**Labels**: `enhancement`, `HITL`, `status:ready-for-agent`
**User Story**: Glue layer for US-01..US-05 (binds 009/010/011/012 into a playable battle)
**Estimate**: M (2-8h)

## What
Until now `run_root.gd._resolve_battle()` was a placeholder that called `core/run.gd.play_battle()` and showed a toast — there was no scene that actually composes HandUI / EnemyUI / HoverPreview / EndTurnButton on screen and drives a real `BattleLoop`. This ticket builds that scene and wires it into the run loop so a player can pick a map node, see a battle, play cards, and return to the map.

End-to-end: from the StS map (ISSUE-017), clicking a Normal/Elite/Boss node swaps `Stage` to `BattleScene`, the player plays through one fight, on resolution the scene emits `battle_finished({won, hp_left, drops})` and `run_root` returns to the map with HP/gold updated.

## Why
ISSUE-009 (hand), 010 (enemy), 011 (anims), 012 (preview) shipped as standalone widgets with bind() APIs but no composing parent. The placeholder `_resolve_battle()` runs a deterministic core battle invisibly. Without an assembly ticket, the visible battle layer never materialises, and players can't actually play the cards they pick up in camp/shop.

## Acceptance criteria
- [ ] `src/ui/battle/battle_scene.{gd,tscn}` — Control root, anchored full-rect.
- [ ] Children: `EnemyUI` (top-center), `HandUI` (bottom), `HoverPreviewView` (right side, hidden until hover), `EndTurnButton` (bottom-right), `VFXLayer` (transparent overlay), `EnergyLabel` (top-left).
- [ ] Public API: `setup(run_state: Resource, tier: String, locale: String) -> void`.
- [ ] Internal: instantiates a fresh `BattleState` via `BattleLoop.start_battle(player_hp, max_hp, deck, enemy, seed)` using `run_state.player_hp / max_hp / deck` and an enemy resolved by `tier` (Normal=25 HP / Elite=50 HP / Boss=100 HP placeholder until ISSUE-008b expands the bestiary).
- [ ] `AnimSignaler` instance held by the scene; `emit_with_signals` is the single emit channel for OnPlay/StartTurn/EndTurn so VFX gets uniform notifications. Direct `EmitScript.emit` calls are forbidden inside this scene.
- [ ] Card click → call `BattleLoop.play_card(state, card, null)`, then re-bind HandUI + update EnemyUI HP. If `is_over(state)` flips, emit `battle_finished` with `{won, hp_left, drops}`.
- [ ] EndTurnButton press → `BattleLoop.end_turn(state)` then refresh hand + enemy + energy. Same `is_over` check.
- [ ] Card hover → call `HoverPreview.resolve(state, card)`, push the result into `HoverPreviewView.show_for(preview)`.
- [ ] Signal: `signal battle_finished(result: Dictionary)` — `{won: bool, hp_left: int, drops: Array}`.
- [ ] `run_root.gd._resolve_battle(tier, node_label)` rewritten: instantiate `BattleScene`, `_swap_stage(scene)`, `scene.battle_finished.connect(_on_battle_finished)`, `scene.call_deferred("setup", _run_state, tier, _locale)`. The placeholder call to `core/run.gd.play_battle()` is removed; the new path is the only battle path.
- [ ] `_on_battle_finished(result)` writes hp / gold back onto `_run_state`, sets `outcome="lost"` if `won==false`, increments `_battle_idx`, then calls `_check_outcome_and_continue()`.
- [ ] `tests/test_battle_scene.gd` (GdUnit4): builds a scripted state (5-card deck w/ 1 `flame_brand`, 25 HP enemy, seed=42), drives `BattleScene.setup()`, plays a card via the public hand→loop bridge, asserts: enemy HP decreased, HandUI re-renders, `battle_finished` fires once after a forced victory.
- [ ] Visual review screencap (HITL gate): full battle scene with one enemy + 5-card hand + hover tooltip showing.

## Implementation hints
- Files:
  - `src/ui/battle/battle_scene.{gd,tscn}`
  - `src/ui/battle/end_turn_button.{gd,tscn}` (small but needs its own focus/disabled rules)
  - `src/ui/battle/hover_preview_view.{gd,tscn}` if not already shipped from 012b
  - `src/ui/battle/vfx_layer.{gd,tscn}` (just an empty Control where ISSUE-024 will add its scenes)
  - `src/tests/test_battle_scene.gd`
- The hand lives in `HandUI._row` (HBoxContainer of `card_ui.tscn`). `card_ui.gd` already exposes a `card_clicked(card)` signal — connect it in `BattleScene._ready()` after `_hand.bind()`.
- Enemy intent value: `BattleLoop._get_intent_damage(state)` is private. Expose a public mirror (`enemy_intent_damage(state) -> int`) or have `BattleScene` read `state.enemy.intent_damage` directly.
- Tier → enemy resource: stub a `core/enemy_factory.gd` returning a `TraitEnemy` with `hp` + `intent` per tier. Real factory comes with ISSUE-008b.
- Drops: when `is_over.won` flips, call `core/drop_table.gd.roll_drops(state, rng)` (already shipped from ISSUE-008) and pass into `result.drops`.
- Use `call_deferred("setup", ...)` from `run_root` so `@onready` vars resolve.
- Keep `_swap_stage(scene)` semantics — when battle ends, run_root frees the scene before showing the map again, so no signal-listener cleanup needed in `BattleScene`.

## Blocked-by
- ISSUE-005 (battle_loop)
- ISSUE-009 (HandUI)
- ISSUE-010 (EnemyUI)
- ISSUE-012 (HoverPreview)
- ISSUE-017 (Tree map)

## Out of scope (this issue)
- VFX overlay scenes themselves → ISSUE-024
- Multi-enemy battles → defer to v0.5 (PRD §4.2 baseline is single-enemy)
- Card cost variability beyond 1-energy stub → cards data pass (post-v0)
- Targeting reticle for multi-target cards → cards data pass

## Source
- PRD §4.2 single-fight loop
- INDEX.md “Open notes” — assembly gap between 005/009/010/011/012 and 017
- run_root.gd:140 placeholder TODO
