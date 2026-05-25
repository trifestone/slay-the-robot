# ISSUE-012 — Hover hand preview: trait+reaction stack with damage estimate (US-04)

**Labels**: `enhancement`, `HITL`, `status:ready-for-human`
**User Story**: US-04 (PRD §3 看反应预览)
**Estimate**: M (2-8h)

## What
On hover-hold (~300ms) of a hand card, show a floating tooltip that displays the trigger stack ordered slot 0→1→2, each step's effect with predicted damage/state, and any reactions that will fire (with their `timing`). End-to-end: hovering a `[flame_brand, oil_slick, lunar_echo]` card shows: "1) Reaction: 火+油→爆炸 (12 Fire + 4 AOE). 2) [skipped — reaction overrode]. 3) lunar_echo: Draw 1 (EndTurn)." against the current enemy + state.

## Why
PRD §3 US-04 + CONTEXT R6: complex chains need pre-resolution clarity. ADR-001's slot ordering must be discoverable without reading docs.

## Acceptance criteria
- [ ] `src/ui/hover_preview.gd` builds a preview by running emit() in a sandboxed copy of state, capturing the log.
- [ ] Tooltip lists each step: slot index, trait name, effect, predicted target HP.
- [ ] Reaction overrides clearly marked ("Replaced by Reaction: 火+油→爆炸").
- [ ] Damage estimate accounts for current enemy buffs/debuffs (vulnerable, etc.).
- [ ] 300ms hover delay (configurable).
- [ ] Visual review screencap.
- [ ] `tests/test_hover_preview.gd`: sandbox-emit returns same log as a real emit() on a clone state; no side effects on real state.

## Implementation hints
- Files: `src/ui/hover_preview.gd`, `src/ui/hover_preview.tscn`, `tests/test_hover_preview.gd`
- Sandbox = `state.duplicate(true)` then run emit() and discard.

## Blocked-by
- ISSUE-009, ISSUE-004

## Out of scope (this issue)
- Camp drag-drop diff preview → ISSUE-014 (the M5 core UX)
- Multi-target preview branching (single primary-target only for v0)

## Source
- PRD §3 US-04
- CONTEXT §6 R6 (触发顺序边界)
- ADR-001 §决策 1
