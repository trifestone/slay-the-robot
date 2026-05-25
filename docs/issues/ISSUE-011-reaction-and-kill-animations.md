# ISSUE-011 — Reaction trigger + 吞噬 kill animation (US-03 + US-05)

**Labels**: `enhancement`, `HITL`, `status:ready-for-human`
**User Story**: US-03, US-05 (PRD §3)
**Estimate**: M (2-8h)

## What
Add VFX/audio to the two highest-feel moments: (a) reaction trigger highlights the card face + plays an explosion-style SFX when a special reaction fires; (b) on kill, enemy dissolves into black smoke that streams into the witch silhouette and trait-acquired toast pops up. End-to-end: a fixture battle with `[flame_brand, oil_slick]` card vs an enemy holding 2 carried_traits triggers both animations sequentially; the player visually understands "I configured this and it paid off".

## Why
PRD §3 US-03 and US-05 both require sensory confirmation. Without these, the trigger-stack architecture feels invisible — the prototype already proved the math works (PROTOTYPE_REPORT), so the ROI is in feel.

## Acceptance criteria
- [ ] `src/vfx/reaction_burst.gd` + `.tscn` plays on emit() reaction match (signal from emit_core).
- [ ] `src/vfx/devour_kill.gd` + `.tscn` plays on enemy death; trait-acquired toast follows.
- [ ] SFX placeholder (`audio/sfx/reaction.ogg`, `audio/sfx/devour.ogg`) — final art deferred but real placeholder needed for review.
- [ ] Both animations < 1.2s total (no UX blocker).
- [ ] Visual review screencap in `docs/visual/us-03-reaction.gif` + `docs/visual/us-05-devour.gif`.
- [ ] `tests/test_anim_signals.gd`: signals emit at correct timing relative to state transitions; animations play headlessly via `AnimationPlayer.play()` (no actual rendering needed).

## Implementation hints
- Files: `src/vfx/{reaction_burst,devour_kill}.{gd,tscn}`, `audio/sfx/{reaction,devour}.ogg`, `tests/test_anim_signals.gd`
- Hook into emit_core signal `reaction_triggered(reaction, card)` and run.gd `enemy_killed(enemy)` signal.
- Designer/audio sign-off required.

## Blocked-by
- ISSUE-004, ISSUE-008, ISSUE-009

## Out of scope (this issue)
- Final art / sound design → post-v0 polish
- Reaction preview tooltip → ISSUE-012 (battle hover) / ISSUE-014 (camp diff)
- Per-element-school reaction VFX variants (one universal burst is OK for v0)

## Source
- PRD §3 US-03, US-05
- A5 §设计建议 (吞噬色彩心理)
