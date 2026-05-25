# ISSUE-013 — Camp UI: inventory + drag-drop mount + dismantle to inventory (US-06+US-07+US-08)

**Labels**: `enhancement`, `HITL`, `status:ready-for-human`
**User Story**: US-06, US-07, US-08 (PRD §3 营地拼装)
**Estimate**: L (8h+; OK to split into 13a inventory grid / 13b drag-drop / 13c dismantle)

## What
Build the camp scene: deck panel showing 15-20 cards each with 3 slot states; inventory grid with capacity (5→10→15→20 per boss progression); drag-drop a trait from inventory onto an empty/filled slot ("哒" snap audio); right-click or button to dismantle a slot trait back to inventory at cost 50 gold + 1 dismantle point. End-to-end: from a state with 8 cards (some half-built) and 4 inventory traits, the player can mount, swap, and dismantle, with gold and dismantle points consumed correctly.

## Why
PRD §3 US-06/07/08 + §4.5 营地与库存. This is the "塑形" loop the entire pitch hangs on (PRD §1).

## Acceptance criteria
- [ ] `src/ui/camp/{camp_scene,deck_panel,card_camp_ui,inventory_grid}.gd` + `.tscn`s.
- [ ] Slot[0] visually locked (not droppable, not dismantle-able).
- [ ] Drag uses `Control.get_drag_data` / `_can_drop_data` / `_drop_data` (PRD §4.7).
- [ ] Drop on non-slot rebounds (snap-back animation).
- [ ] Cost panel shows current gold / dismantle points / inventory capacity.
- [ ] Replace-cost = 30 gold (covering existing trait); empty-slot mount = free.
- [ ] Inventory cap-respect: full inventory blocks dismantle with toast.
- [ ] Same-card duplicate-trait BLOCKED (A2 §9.3 rule 1; CONTEXT §4): drop validator rejects with toast.
- [ ] Visual review screencap; designer sign-off.
- [ ] `tests/test_camp_logic.gd`: mount empty (free), replace (30g), dismantle (50g + 1 point), block on full inventory, block on duplicate trait, slot[0] immutable.

## Implementation hints
- Files as above; `src/state/camp_state.gd` for in/out commit transactions.
- Reference guladam/deck_builder_tutorial (PRD §4.7) for drag baseline.
- Audio placeholder `audio/sfx/snap.ogg`.

## Blocked-by
- ISSUE-002, ISSUE-008

## Out of scope (this issue)
- Reaction preview diff tooltip during drag → ISSUE-014 (M5 core UX)
- Reforge base slot (100 gold + rare item) → ISSUE-016
- Shop → ISSUE-015

## Source
- PRD §3 US-06, US-07, US-08
- PRD §4.5 营地与库存
- CONTEXT §2 Q7, Q8 v1
