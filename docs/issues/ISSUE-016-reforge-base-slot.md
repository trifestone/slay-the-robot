# ISSUE-016 — Reforge base slot (100 gold + 1 rare item) (US-16)

**Labels**: `enhancement`, `HITL`, `status:ready-for-human`
**User Story**: US-16 (PRD §3 重构卡组)
**Estimate**: M (2-8h)

## What
Camp action allowing the player to reforge a card's base slot (slot[0]) — change from Attack→Skill or Attack→Rite, etc. — at cost 100 gold + 1 rare-tier consumable, once per card per run. End-to-end: in camp, click "Reforge" on a card, pay cost, choose new base, slot[0] trait swaps to the new base's signature trait.

## Why
PRD §3 US-16 + §4.5 (reforge row). Lets mid-run pivots happen instead of being stuck with the starter base.

## Acceptance criteria
- [ ] Camp UI exposes a "Reforge" affordance per card.
- [ ] Cost gating: 100 gold + 1 `rare_item` (consumable item type).
- [ ] Once-per-card-per-run flag (`card.reforged: bool`).
- [ ] Choosing new base updates `card.base` and replaces slot[0]'s trait with the new base's signature trait. Slot[0] remains locked.
- [ ] Slots 1/2 traits preserved (the whole point — PRD US-16 wording).
- [ ] Confirmation dialog (this is destructive).
- [ ] `tests/test_reforge.gd`: cost deducted, base swapped, slot[0] new trait, slots 1/2 untouched, second reforge blocked.

## Implementation hints
- Files: `src/ui/camp/reforge_dialog.{gd,tscn}`, `src/core/reforge.gd`, `tests/test_reforge.gd`
- "Rare item" type comes from event/boss drops — add a placeholder spawn so test can run end-to-end.

## Blocked-by
- ISSUE-013

## Out of scope (this issue)
- Rare-item drop tables → handled in ISSUE-008 expansion (assume 1 fixed drop on first boss for now)
- Multiple reforges per card

## Source
- PRD §3 US-16 + §4.5 reforge row
