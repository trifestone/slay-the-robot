# ISSUE-024 — VFX layer: subscribe AnimSignaler signals → play .tscn FX

**Labels**: `enhancement`, `HITL`, `status:ready-for-agent`
**User Story**: Glue layer for US-03 / US-05 (makes ISSUE-011's anims actually play)
**Estimate**: S (1-2h)

## What
ISSUE-011 ships pure-logic `AnimSignaler` (signals: `reaction_triggered`, `trait_fired`, `enemy_killed`) and three VFX scenes (`devour_kill.tscn`, `reaction_burst.tscn`, `heal_pop.tscn`) but **nothing connects them** — the signals fire into the void. This ticket adds `VFXLayer`, a transparent Control inside `BattleScene` that subscribes to a shared `AnimSignaler` and instantiates the right .tscn at the right screen position when a signal fires.

End-to-end: in the new `BattleScene` from ISSUE-023, when a card with a Damage trait is played, `emit_with_signals` fires `trait_fired("flame_brand", card, 0)` → `VFXLayer` plays `reaction_burst.tscn` over the enemy widget. When the enemy dies, `notify_enemy_killed(enemy, drops)` fires `enemy_killed` → `devour_kill.tscn` plays + a "trait acquired" toast.

## Why
The three VFX .tscn files ship from ISSUE-011 but are orphaned — they play if instanced manually but no live caller does so. Players currently see plain HP-number changes without any feedback animation, breaking the US-03 "看反应" promise. This is small (S) but blocks the visual review gate of ISSUE-023.

## Acceptance criteria
- [ ] `src/ui/battle/vfx_layer.{gd,tscn}` — Control, full-rect, mouse_filter=IGNORE, child of `BattleScene` rendered above EnemyUI/HandUI.
- [ ] Public API: `bind(signaler: Node, enemy_ui: Control) -> void` — connects all 3 `AnimSignaler` signals to internal handlers and stores `enemy_ui` for hit positioning.
- [ ] Handler `_on_reaction_triggered(reaction_id, card)` → instantiates `vfx/reaction_burst.tscn`, parents under VFXLayer, places it at `_enemy_ui.global_position + ENEMY_CENTER_OFFSET`, lets it play to end (`tree_exited` queue_frees itself if not self-managed).
- [ ] Handler `_on_trait_fired(trait_id, card, depth)` → instantiates `vfx/reaction_burst.tscn` with a different tint (or the existing trait tint table from 011b) so reactions are visibly distinct from regular trait fires. If 011b doesn't differentiate, this ticket adds a `mode: String` to the burst scene's `play(mode)` API.
- [ ] Handler `_on_enemy_killed(enemy, drops)` → instantiates `vfx/devour_kill.tscn` over the enemy. Emits `signal drops_announced(drops: Array)` so `BattleScene` can show the trait-acquired toast.
- [ ] Heal pop hook: `VFXLayer.play_heal(amount: int, target: Control)` — invoked by `BattleScene` from camp returns or post-battle heal (ISSUE-007). Plays `vfx/heal_pop.tscn`.
- [ ] No leaks: each FX scene self-frees via `AnimationPlayer.animation_finished` → `queue_free()`. VFXLayer never accumulates children across battles.
- [ ] `tests/test_vfx_layer.gd` (GdUnit4): build a stub `AnimSignaler`, emit each of the 3 signals, assert that VFXLayer added exactly one child of the matching scene class. Use `await get_tree().process_frame` so deferred adds resolve.
- [ ] Visual review screencap: an in-engine recording of one card play producing reaction_burst + a kill producing devour_kill + a camp-return producing heal_pop.

## Implementation hints
- Files:
  - `src/ui/battle/vfx_layer.{gd,tscn}`
  - `src/tests/test_vfx_layer.gd`
  - **(if 011b doesn't already)** small extension to `vfx/reaction_burst.gd` adding `play(mode: String)` to support the trait_fired/reaction_triggered tint difference.
- Position math: `_enemy_ui.get_global_rect().get_center()`; offset constant `ENEMY_CENTER_OFFSET = Vector2(0, -32)` keeps the burst over the sprite, not the trait row.
- Signal connections live in `bind()` not `_ready()` so the layer can be re-bound across battles in the same session.
- Disconnect all three signals on `tree_exiting` — VFXLayer is freed when BattleScene is freed; keeps the linter happy.
- Heal pop is invoked by `BattleScene` directly (not via `AnimSignaler`) because heal happens at camp scene level — keep that path explicit and don't add a `heal_applied` signal to AnimSignaler just for one caller.

## Blocked-by
- ISSUE-011 (AnimSignaler + 3 VFX .tscn)
- ISSUE-023 (BattleScene host)

## Out of scope (this issue)
- New VFX scenes (only wires up the three from 011b).
- Damage number popups → defer to a polish ticket.
- Audio cues → separate audio ticket.

## Source
- PRD §3 US-03 / US-05
- ISSUE-011 acceptance "VFX scene exists" + tests/test_vfx_scenes.gd (proves the scenes load, not that anyone consumes them)
