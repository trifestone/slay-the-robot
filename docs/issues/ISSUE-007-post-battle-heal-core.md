# ISSUE-007 — Post-battle healing core circuit (M3: +5/+10/+20)

**Labels**: `enhancement`, `AFK`, `status:ready-for-agent`
**User Story**: US-13b (PRD §3 战后回血 — 核心循环)
**Estimate**: S (≤2h)

## What
Implement automatic post-battle HP restoration: +5 after normal / +10 after elite / +20 after boss, capped at maxHP. End-to-end: ISSUE-006's run sequence applies the correct heal value after each victory and `run.player_hp` reflects it; a fixture run with low HP survives only because of healing.

## Why
M3 prototype reverberation (PRD §4.8 callout): without post-battle heal the win rate collapses to 0%. This is core circuit, not a convenience feature. US-13b directly maps to this.

## Acceptance criteria
- [ ] `src/core/post_battle.gd` exposes `heal(player, enemy_kind)` returning the correct amount (5/10/20).
- [ ] Wired into ISSUE-006 run.gd between battles for victory branch only.
- [ ] HP clamp at `max_hp`; assertion in test.
- [ ] `tests/test_post_battle_heal.gd`: 18-battle sequence with deterministic damage → asserts cumulative heal of 12×5 + 3×10 + 3×20 = 150 HP applied (subtracting clamp losses).
- [ ] No animation; that's HITL (ISSUE-018 handles death-screen + heal animation polish).

## Implementation hints
- Files: `src/core/post_battle.gd`, `tests/test_post_battle_heal.gd`
- Add a hook signal `battle_won(enemy_kind)` from ISSUE-006 run.gd to keep coupling thin.

## Blocked-by
- ISSUE-006

## Out of scope (this issue)
- Heal animation / VFX → ISSUE-018
- Camp 30% maxHP heal node → not v0 issue (camp slice)
- Shop heal item → not v0 issue (camp slice)

## Source
- PRD §4.8 战后回血表 + M3 footnote
- PROTOTYPE_REPORT §2.1 / §3 修订项 M3
- US-13b (PRD §3)
