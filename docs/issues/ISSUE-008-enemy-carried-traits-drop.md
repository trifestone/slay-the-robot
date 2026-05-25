# ISSUE-008 — Enemy `carried_traits` + drop on kill (rarity table 75/22/3)

**Labels**: `enhancement`, `AFK`, `status:ready-for-agent`
**User Story**: US-05 (data side; animation = ISSUE-011)
**Estimate**: M (2-8h)

## What
Implement enemy trait carrying + drop-on-kill: normal 60/30/10 for 1/2/0 traits; elite fixed 2; boss fixed 3. Drops sampled by rarity table (PRD §4.3): normal 75/22/3, elite 40/50/10, boss 0/40/60. End-to-end: a seeded run logs traits collected; over 100 sims the empirical distribution matches PRD ±5%.

## Why
PRD §4.3 (词条池规模与稀有度) locks the economy. Without correct drop semantics the inventory + camp loop is meaningless.

## Acceptance criteria
- [ ] `src/core/drop_table.gd`: `roll_drops(enemy_kind, rng) -> Array[Trait]`.
- [ ] Drops respect: drop_count distribution per kind + per-drop rarity sampling.
- [ ] Enemy data (`enemies.json` from ISSUE-006) lists `carried_traits` pool to draw from.
- [ ] Inventory accepts dropped traits; capacity check (initial 5, overflow currently auto-drops oldest until UI exists — log warning).
- [ ] `tests/test_drop_table.gd`: 1000 seeded normal-enemy rolls → drop_count distribution within ±3% of 60/30/10; rarity within ±3% of 75/22/3.
- [ ] Wired into ISSUE-006 victory branch.

## Implementation hints
- Files: `src/core/drop_table.gd`, `src/core/inventory_manager.gd`, `tests/test_drop_table.gd`
- Use deterministic RNG seeded by `(run_seed, battle_index)` for reproducibility.

## Blocked-by
- ISSUE-006

## Out of scope (this issue)
- Inventory UI → ISSUE-013
- Kill / 吞噬 animation → ISSUE-011
- Trait unsocket flow → ISSUE-013

## Source
- PRD §4.3 (drop tables) + CONTEXT §4 Enemy
- US-05 (data side)
