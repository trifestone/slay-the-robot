# ISSUE-004 — SpecialReaction registry with timing field (M2)

**Labels**: `enhancement`, `AFK`, `status:ready-for-agent`
**User Story**: Foundation for US-03, US-04, US-09
**Estimate**: S (≤2h)

## What
Add a `SpecialReaction` registry that loads the 5 sample reactions from `data/reactions.json` (PRD §4.4 example table), enforces M2 (each reaction binds a specific `TriggerEvent` via `timing`), and integrates with the emit() core so reactions only fire when `event == reaction.timing`. End-to-end: a card with `[flame_brand, oil_slick]` played triggers the `OnPlay` Damage(12, Fire)+AOE(4) override exactly once per turn (per-reaction cooldown identical mechanism to trait cooldown).

## Why
PRD §4.4 + M2 footnote: prototype showed 4 reactions firing 10-13 times/run (4-10× over budget). Binding `timing` collapses fire frequency to spec (0.3-3/run target).

## Acceptance criteria
- [ ] `data/reactions.json` contains the 5 PRD §4.4 example reactions with `watch_for, timing, override_effect, flavor`.
- [ ] `src/core/reaction_registry.gd` loads reactions via Resource at startup; provides `match(event, card) -> SpecialReaction | null`.
- [ ] emit() (ISSUE-003) consults registry only when `reaction.timing == event` (M2).
- [ ] Per-reaction cooldown: same reaction id fires at most once per turn per card (`reaction_cooldown_table`).
- [ ] Validator: reaction without `timing` field fails to load with clear error.
- [ ] `tests/test_reactions.gd`:
  - `[flame_brand, oil_slick]` on `OnPlay` → fires Damage(12) + AOE(4), suppresses both originals
  - Same card played twice in one turn → reaction fires once, second OnPlay falls back to bare trait effects
  - `[purify_light, venom_touch]` (Cancel reaction) tested for both-effects suppressed + heal(3) applied
  - Reaction with mismatched `timing` (registry lookup with `OnHit` when reaction is `OnPlay`) does NOT fire

## Implementation hints
- Files: `src/core/reaction_registry.gd`, `data/reactions.json`, `tests/test_reactions.gd`
- Hook into ISSUE-003's `emit()` via injected registry (so emit_core can test in isolation).

## Blocked-by
- ISSUE-003

## Out of scope (this issue)
- Reaction preview UI → ISSUE-014
- Full 20-30 reaction content → ISSUE-021 (coverage matrix)
- Reaction trigger animation → ISSUE-011

## Source
- PRD §4.4 + M2 footnote
- CONTEXT §4 SpecialReaction
- PROTOTYPE_REPORT §2.2 / §3 修订项 M2
