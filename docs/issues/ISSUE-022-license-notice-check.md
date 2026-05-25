# ISSUE-022 — Slay-The-Robot license header / NOTICE check (PRD §7.1)

**Labels**: `enhancement`, `HITL`, `status:ready-for-human`
**User Story**: PRD §7.1 (Slay-The-Robot 模板许可证)
**Estimate**: S (≤2h)

## What
Audit the forked Slay-The-Robot template for MIT license compliance: ensure original `LICENSE` is preserved, add `NOTICE` listing third-party attributions (template, GdUnit4, godot-state-charts, any art/audio borrowed). End-to-end: a release build's `NOTICE` enumerates all upstream sources; a CI check (linter or shell script) fails if a known dependency lacks attribution.

## Why
PRD §7.1: shipping without proper attribution is a release blocker. Catching this in v0 issue stage (per PRD note) avoids late-stage surprises.

## Acceptance criteria
- [ ] `LICENSE` file from upstream Slay-The-Robot preserved at repo root or `src/`.
- [ ] `NOTICE` file enumerates: Slay-The-Robot template (MIT, link, commit), GdUnit4 (license, link), godot-state-charts (license, link), Godot engine, fonts/audio/art placeholders sources.
- [ ] `tools/check_license.gd` (or `.ps1`) verifies presence of each entry; CI hook ready.
- [ ] Per-file license headers ONLY where upstream had them (don't blanket-add to our own files).
- [ ] HITL legal sign-off recorded in `docs/legal/license-audit-2026-05.md`.

## Implementation hints
- Files: `LICENSE`, `NOTICE`, `tools/check_license.{gd,ps1}`, `docs/legal/license-audit-2026-05.md`
- Reference PRD §7.1 + A6 §1.1 for upstream license confirmation (MIT).

## Blocked-by
- ISSUE-001

## Out of scope (this issue)
- Audio/art licensing for final assets (placeholder phase only)
- EULA / Steam page legal text

## Source
- PRD §7.1 风险与缓解
- A6 §1.1 (Slay-The-Robot MIT)
