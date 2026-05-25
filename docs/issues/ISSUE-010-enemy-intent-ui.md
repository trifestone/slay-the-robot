# ISSUE-010 — Enemy intent UI + carried_traits display (US-02)

**Labels**: `enhancement`, `HITL`, `status:ready-for-human`
**User Story**: US-02 (PRD §3 看意图)
**Estimate**: M (2-8h)

## What
Display StS-style next-turn intent (icon + numeric value) above each enemy and show their `carried_traits` icons (1-3) as a small badge cluster — both readable at a glance so the player can decide "kill which one for which reward". End-to-end: in a battle with 1 elite enemy, the player sees the intent ("Attack 12") and its 2 carried trait icons; tooltip on intent shows full description.

## Why
PRD §3 US-02 requires both decisions ("survive this turn" and "for-reward target priority") to be supported by visible information.

## Acceptance criteria
- [ ] `src/ui/enemy_ui.gd` renders: enemy sprite, HP bar, intent (icon+number), carried_traits row (max 3 small icons).
- [ ] Intent tooltip on hover shows verbose explanation.
- [ ] Carried-trait icon hover shows trait name + flavor.
- [ ] Multi-enemy layout (test with 3 enemies on screen).
- [ ] Visual review screenshot in `docs/visual/us-02-intent.png`.
- [ ] `tests/test_enemy_ui.gd`: intent number updates when state changes; carried_traits row reflects enemy data.

## Implementation hints
- Files: `src/ui/{enemy_ui,intent_widget}.gd`, `src/ui/enemy_ui.tscn`, `tests/test_enemy_ui.gd`
- Intent icons: Attack/Block/Buff/Debuff/Multi (5 base sprites cover StS baseline).

## Blocked-by
- ISSUE-005, ISSUE-008

## Out of scope (this issue)
- Kill / 吞噬 animation → ISSUE-011
- Multi-enemy targeting UX (single-target click is fine for v0 fight)
- Boss-specific intent flavor

## Source
- PRD §3 US-02
- A1 §2.1 (StS 明牌意图)
- CONTEXT §4 Enemy.carried_traits
