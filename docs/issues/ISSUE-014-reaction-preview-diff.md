# ISSUE-014 — Reaction preview diff tooltip during drag (US-09, M5 core UX)

**Labels**: `enhancement`, `HITL`, `status:ready-for-human`
**User Story**: US-09 (PRD §3 反应预览 — 核心 UX)
**Estimate**: L (8h+, consider split: 14a diff renderer / 14b frequency estimator)

## What
While dragging a trait toward a slot, show a floating tooltip with: (1) old effect strikethrough vs new effect green-add diff for that slot; (2) list of reactions that will be GAINED or LOST on this card (each line shows `watch_for + timing + flavor + estimated frequency "~X / battle"`). End-to-end: dragging `oil_slick` onto a card already holding `flame_brand` shows "+ Reaction: 火+油→爆炸 (~1.2 / battle)" before the player commits the drop.

## Why
PRD §4.5 + M5: prototype proved that "auto-pair reactions" gives 60% wins to passive players. Designer intent is to make pairing the player's strategy, so the preview MUST exist and must convey reaction value before commit. Auto-pair UI is explicitly forbidden (PRD §4.5).

## Acceptance criteria
- [ ] `src/ui/camp/reaction_preview.gd` runs a sandboxed reaction-registry diff: `before_set = current_card.reactions(); after_set = (current_card with new trait).reactions()`. Render gained/lost.
- [ ] Frequency estimator: per reaction, estimate `~X / battle` from a quick monte-carlo or table (use 0.3-3 / run target as reasonable bounds).
- [ ] Old vs new effect for that specific slot rendered with strikethrough + green-add typography.
- [ ] Auto-pair button is NOT implemented anywhere (negative test: confirm absence).
- [ ] Preview updates live as drag hovers different slots.
- [ ] Visual review screencap; designer sign-off (this is THE central UX moment).
- [ ] `tests/test_reaction_preview.gd`: known card+drag combos produce expected gained/lost reaction set; estimator is pure function of card+registry.

## Implementation hints
- Files: `src/ui/camp/reaction_preview.{gd,tscn}`, `src/core/reaction_predictor.gd`, `tests/test_reaction_preview.gd`
- Frequency table can be precomputed offline from sim (ISSUE-019) once available; for v0 use rough constants documented in code.

## Blocked-by
- ISSUE-013, ISSUE-004

## Out of scope (this issue)
- Auto-pair convenience (forbidden by PRD §4.5)
- Cross-card reaction prediction (reactions are same-card only per CONTEXT §4)

## Source
- PRD §3 US-09 + §4.5 (M5 footnote — 核心 UX 而非便利功能)
- PROTOTYPE_REPORT §2.5
