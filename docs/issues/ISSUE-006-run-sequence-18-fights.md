# ISSUE-006 — 18-fight Run sequence (12 normal + 3 elite + 3 boss / 3 acts)

**Labels**: `enhancement`, `AFK`, `status:ready-for-agent`
**User Story**: Foundation for US-11, US-12, US-13
**Estimate**: M (2-8h)

## What
Stitch ISSUE-005 fights into a full Run: 3 acts × (4 normal + 1 elite + 1 boss) = 18 battles in fixed order (no map yet). End-to-end: headless `run.gd` plays a deterministic seeded run with sample deck, prints per-battle outcome and final win/loss, exits 0.

## Why
PRD §4.8 locks the 18-fight cadence and act structure. This slice gives the simulator harness (ISSUE-019) something to scale. The map UI itself is a later HITL slice (ISSUE-017).

## Acceptance criteria
- [ ] `src/core/run.gd` orchestrates 18 ordered battles with act-scaling enemy HP (PRD §4.8: normal 12-25 / elite 40-60 / boss 100-180 — pick mid-act values per act).
- [ ] Run state: player carries HP/deck/inventory/gold across battles. Death stops the run.
- [ ] Each battle invokes ISSUE-005 BattleLoop with the appropriate enemy archetype.
- [ ] `enemies.json` data file with 6 normal + 3 elite + 3 boss archetypes (HP, intent profile, `carried_traits`).
- [ ] Headless entry `tools/run_one.gd`: takes `--seed N`, runs, prints CSV row `seed, outcome, battles_won, hp_left, gold, traits_collected`.
- [ ] `tests/test_run_sequence.gd`: fixed seed → completes 18 battles without crash; deterministic battles_won count.

## Implementation hints
- Files: `src/core/run.gd`, `data/enemies.json`, `tools/run_one.gd`, `tests/test_run_sequence.gd`
- Don't introduce camp logic here — between-battle is just "heal hook + drop hook" stubs that ISSUE-007 + ISSUE-008 wire up.

## Blocked-by
- ISSUE-005

## Out of scope (this issue)
- Post-battle healing values → ISSUE-007
- Enemy carried_traits drop logic → ISSUE-008
- Tree map UI → ISSUE-017
- Run-end / death screen UI → ISSUE-018

## Source
- PRD §4.8 单局节奏
- CONTEXT §3 设计骨架
