# ISSUE-003 — emit() trigger stack core (ADR-001 implementation)

**Labels**: `enhancement`, `AFK`, `status:ready-for-agent`
**User Story**: Foundation for US-03, US-04 (trigger semantics)
**Estimate**: M (2-8h)

## What
Implement `emit(state, event, card)` in GDScript exactly per ADR-001: same-event multi-trait resolves slot 0→1→2, OnTraitFired chain depth ≤ 2, special-reaction-on-emit takes precedence and skips downstream, `cooldown_per_turn` enforced per `(card.id, trait.id)` per turn. End-to-end: a fixture card with 3 traits monitoring `OnPlay` produces a deterministic effect log when `emit(OnPlay)` is called.

## Why
ADR-001 is `Accepted`; prototype proved 560k emits / 0 errors. This is the kernel every subsequent feature uses. PRD §4.2 locks the order; PRD §5.4 R6+ requires emit-level fixtures.

## Acceptance criteria
- [ ] `src/core/emit.gd` exposes `emit(state, event, card) -> void` matching ADR-001 §决策 1-3 pseudocode.
- [ ] State carries `fire_depth: int`, `trait_fire_log: Array`, `cooldown_table: Dictionary`. Reset hooks per battle and per turn.
- [ ] `OnTraitFired` chain depth strictly ≤ 2 (depth-3 silent skip, no exception, asserted in test).
- [ ] When a SpecialReaction matches `(timing, watch_for ⊂ card.traits)`, its `override_effect` runs, `return` exits emit (no downstream traits, no OnTraitFired bubble).
- [ ] Cooldown: traits with `cooldown_per_turn = N` fire at most N times per turn per card.
- [ ] `tests/test_emit_core.gd` covers (PRD §5.4 R6 fixtures):
  - 3 traits on one card, slot 0→1→2 ordering asserted on log
  - OnTraitFired depth exactly 2 fires; depth 3 blocked
  - Reaction match in emit blocks downstream + no OnTraitFired
  - `void_consume` (cooldown 1) fires once across 5 OnPlay events in same turn
- [ ] No mock-only paths: traits/cards/reactions are loaded from ISSUE-002 Resources.

## Implementation hints
- Files: `src/core/emit.gd`, `src/core/battle_state.gd` (stub for state), `tests/test_emit_core.gd`
- Use the ADR-001 pseudocode literally; do not improvise control flow.
- Effects can be stubbed as `apply_effect(state, effect)` writing into a log — full effect resolution arrives with ISSUE-005.

## Blocked-by
- ISSUE-002

## Out of scope (this issue)
- SpecialReaction `timing` field semantics → covered here for emit, but reaction registry/loader of full 25 set → ISSUE-004
- Battle loop / energy / hand → ISSUE-005
- emit() ~80/battle scale fixture → ISSUE-020

## Source
- ADR-001 §决策 1-3
- PRD §4.2, §5.4 R6
- CONTEXT §4 战斗结算伪代码, §5 R6
- PROTOTYPE_REPORT §2.4
