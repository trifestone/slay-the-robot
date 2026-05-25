# ISSUE-018 — Run end + meta progression unlock + heal anim + witch lore + min reward (US-12+13+13b+14+15)

**Labels**: `enhancement`, `HITL`, `status:ready-for-human`
**User Story**: US-12, US-13, US-13b (anim polish), US-14, US-15
**Estimate**: L (8h+, must split: 18a death/win screens / 18b unlock state machine / 18c lore unlocks)

## What
Stitch the run-end UX layer: (a) death/win screen with summary stats; (b) meta-progression state file (`user://meta.json`) tracking witch XP, unlocked traits/bases/witches, lore fragments; (c) victory screen showing "+N XP, unlocked X" popups (US-12); (d) min-reward guarantee (≥ 1 XP fragment + 1 codex entry) even if first-battle death (US-15); (e) post-battle heal animation polish for ISSUE-007 numbers (US-13b); (f) witch lore unlock at thresholds (1st win, 5 wins, themed-build win — US-14). End-to-end: complete a run (win or lose), the meta file updates correctly, screens display, restart preserves unlocks but resets in-run state.

## Why
PRD §3 US-12/13/13b/14/15 + §4.6 元进度. This is the retention loop — everything else can ship without it but the game has no progression hook.

## Acceptance criteria
- [ ] `src/meta/{meta_state,unlock_table,lore_store}.gd` + `user://meta.json` save format.
- [ ] Unlock thresholds match PRD §4.6 table (run 1 = +1 trait + 1 lore fragment; run 5 = 2nd witch + ~10 traits + 1 base + lore; run 20 = 3 witches + 25 traits; run 50 = full pool).
- [ ] Death screen: shows run summary; "in-run progress lost, meta preserved" copy; restart button.
- [ ] Win screen: XP counter, unlock popups (sequenced animations).
- [ ] First-battle death still grants ≥ 1 XP fragment + 1 codex entry (US-15).
- [ ] Lore fragments unlock at: first win (`win_count == 1`), 5 wins, themed-build win (e.g., "all-Fire deck cleared a boss" detection — instrument run data).
- [ ] Post-battle heal: tween + number pop animation (polish of ISSUE-007's silent +N).
- [ ] Visual review screencaps for death/win/heal-anim.
- [ ] `tests/test_meta_state.gd`: thresholds trigger unlocks; min-reward fires on early death; save/load round-trip; in-run reset correctness.

## Implementation hints
- Files: `src/meta/`, `src/ui/end/{death_screen,win_screen,unlock_popup}.{gd,tscn}`, `src/vfx/heal_pop.tscn`, `tests/test_meta_state.gd`
- This is the largest ticket; split as suggested above. Keep meta-state machine pure-data (testable AFK) and only the screens HITL.

## Blocked-by
- ISSUE-006, ISSUE-007, ISSUE-017

## Out of scope (this issue)
- Lore content authoring (placeholder fragments OK; final writer pass post-v0)
- Cosmetic XP bar styling beyond functional clarity
- Difficulty modes (Asc1) → PRD §4.6 says "run 20 unlock", deferred to v0.5

## Source
- PRD §3 US-12, US-13, US-13b, US-14, US-15
- PRD §4.6 元进度 + §4.8 战后回血
- A3 §设计建议 2/3/4
