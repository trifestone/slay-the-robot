# ISSUE-001 — Bootstrap: fork Slay-The-Robot template + headless smoke test

**Labels**: `enhancement`, `AFK`, `status:ready-for-agent`
**User Story**: Foundation (no direct US; enables US-01 through US-16)
**Estimate**: S (≤2h)

## What
Fork the DesirePathGames/Slay-The-Robot Godot 4 template into `src/`, run a `godot --headless` smoke test, and land a green GdUnit4 hello-world test so the project has a verifiable end-to-end pipeline (engine → headless → test runner) on day 1.

## Why
PRD §4.7 + CONTEXT §6 lock the engine + template + test stack. Every subsequent vertical slice depends on this skeleton. Without it, no other issue can self-verify.

## Acceptance criteria
- [ ] `src/` contains the forked Slay-The-Robot template at a pinned commit (record SHA in `src/UPSTREAM.md`).
- [ ] `godot --headless --display-driver headless --audio-driver Dummy --quit` exits 0.
- [ ] GdUnit4 is added as an addon under `src/addons/gdUnit4/`.
- [ ] `tests/test_hello.gd` contains a `assert_int(1+1).is_equal(2)` test and runs green via `runtest.cmd` (or shell equivalent).
- [ ] `.gitignore` excludes `.godot/`, `.import/`, build artifacts.
- [ ] No mock-only paths; the slice runs end-to-end on the real Godot 4.x runtime.

## Implementation hints
- Files: `src/project.godot`, `src/addons/gdUnit4/`, `src/UPSTREAM.md`, `tests/test_hello.gd`
- Use Godot 4.5+ (per CONTEXT §6 GdUnit4 1.1k★ Godot 4.5–4.7 compat). Pin engine version in `src/UPSTREAM.md`.
- Reference PRD §4.7 technology table and CONTEXT §6.

## Blocked-by
- none

## Out of scope (this issue)
- License header / NOTICE check → ISSUE-022
- CI workflow (GitHub Actions) → deferred until issue suite stabilizes
- Any Trait/Card data → ISSUE-002

## Source
- CONTEXT §6 (技术栈 v1)
- PRD §4.7 (技术栈表)
- PROTOTYPE_REPORT §4 (下游路径第 1 条)
