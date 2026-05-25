# ISSUE-020 — emit() ~80/battle scale fixture + log-hash diff (M4)

**Labels**: `enhancement`, `AFK`, `status:ready-for-agent`
**User Story**: PRD §5.4 R6+ (M4 prototype reverberation)
**Estimate**: S (≤2h)

## What
Add a focused fixture that hits the emit() core at the prototype-observed scale: 5-card deck × 3-trait full slots × 5 plays/turn × 5 turns ≈ 70-100 emits per battle. Records `(card.id, trait.id, depth, event)` log per emit and hashes it; the test asserts no exceptions, total fire count within ±10% of expectation, and hash matches a golden value. End-to-end: `godot --headless -s tests/run_emit_scale.gd` finishes < 1s with green output.

## Why
PRD §5.4 R6+ + M4 prototype reverberation: 1k runs × ~80 emits × 18 fights ≈ 560k emits with 0 errors in Python — the GDScript port must demonstrate equivalent stability and silent-regression detection.

## Acceptance criteria
- [ ] `tests/test_emit_scale.gd` constructs the fixture (5 cards × 3 traits, 5 plays × 5 turns).
- [ ] Asserts: `state.emit_count` within 70-100; `state.fire_count` within ±10% of analytical expectation; no exception raised; `fire_depth` peak ≤ 2.
- [ ] Log hash: `(card.id + trait.id + depth + event)` lines hashed to SHA-256; golden hash stored in `tests/golden/emit_scale.hash`.
- [ ] Cooldown sub-test: a card with `void_consume` (cooldown 1) plays 5 times in turn → exactly 1 fire of `void_consume`.
- [ ] Failing run produces a diff against the golden hash for triage.

## Implementation hints
- Files: `tests/test_emit_scale.gd`, `tests/golden/emit_scale.hash`
- Reuse ISSUE-003's emit() core directly. Keep fixture self-contained (no battle UI).

## Blocked-by
- ISSUE-003

## Out of scope (this issue)
- Full 1k-run sim → ISSUE-019
- Per-trait coverage matrix → ISSUE-021

## Source
- PRD §5.4 R6+ + M4 footnote
- PROTOTYPE_REPORT §2.4
- ADR-001 §实证
