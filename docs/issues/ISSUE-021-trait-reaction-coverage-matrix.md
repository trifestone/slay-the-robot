# ISSUE-021 — GdUnit4 trait + reaction coverage matrix (80 traits + 25 reactions)

**Labels**: `enhancement`, `AFK`, `status:ready-for-agent`
**User Story**: PRD §5.1 + §5.4 R1
**Estimate**: L (8h+; split into 21a trait tests / 21b reaction tests / 21c content authoring)

## What
Author the full content (80 traits + 25 reactions in `data/traits.json` + `data/reactions.json`) AND a parameterized GdUnit4 test suite with one passing test per trait (OnX → effect(value) assertion) and per reaction (watch_for match → override_effect, no downstream). End-to-end: `runtest.cmd` reports `105 passed, 0 failed` and CI requires this gate.

## Why
PRD §5.1 + §5.4 R1: trigger-stack architecture collapses test plane to 80 + 25 = 105 cases. Without coverage we lose the central design-bet (CONTEXT R1).

## Acceptance criteria
- [ ] `data/traits.json` contains exactly 80 traits matching: 50 Common / 22 Uncommon / 8 Rare; distributed across 6 schools × 8 timings (sparse but represented in each axis).
- [ ] All `OnTraitFired`/`OnKill` traits have `cooldown_per_turn ≥ 1` (M1 validator pass).
- [ ] `data/reactions.json` contains 20-30 reactions with required `timing` field; ratio 70/20/10 (same-timing / cross-school / inhibit) per PRD §4.3.
- [ ] `tests/test_trait_matrix.gd` parameterized over all 80 trait ids; each verifies the spec'd effect on a stub state.
- [ ] `tests/test_reaction_matrix.gd` parameterized over all reaction ids; each verifies override + downstream-skip.
- [ ] Runs in < 30s headless.
- [ ] Triple-axis coverage report: at least 1 trait per `(school, timing)` cell with 80/192 ≥ 40% population (PRD §4.1 footnote).
- [ ] Localization: zh-CN + en strings for every trait + reaction flavor.

## Implementation hints
- Files: `data/traits.json`, `data/reactions.json`, `tests/test_trait_matrix.gd`, `tests/test_reaction_matrix.gd`, `data/locale/{en,zh_CN}.po`
- Use a generator script to scaffold trait stubs from the (school × timing × effect) template (PRD §7.1 R4) then hand-tune values.

## Blocked-by
- ISSUE-002, ISSUE-003, ISSUE-004

## Out of scope (this issue)
- Art/icon assets per trait (placeholder OK)
- Balance pass (sim-driven, see ISSUE-019)

## Source
- PRD §4.1, §4.3, §4.4, §5.1, §5.4 R1
- CONTEXT §5 R1
