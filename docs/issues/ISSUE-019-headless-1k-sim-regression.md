# ISSUE-019 — Headless 1k-run sim regression harness + CSV diff vs prototype baseline

**Labels**: `enhancement`, `AFK`, `status:ready-for-agent`
**User Story**: PRD §5.2 (Testing — 平衡模拟器)
**Estimate**: M (2-8h)

## What
Implement `sim.gd` driving 1000 headless runs (per PR) and 10000 (nightly) using ISSUE-006 run engine with auto-play heuristic. Outputs CSV with win-rate, trait pick distribution, reaction frequency, gold spend, average battle turns. Diff against `prototype/sim_results.csv` baseline; CI fails on >5% drift in win-rate or any reaction breaching 0.3-3 / run band. End-to-end: `godot --headless -s tools/sim.gd --runs 1000 --seed-base 1` produces `sim_results.csv` and `sim_diff.txt`.

## Why
PRD §5.2 + CONTEXT §6 lock the sim as the balance backbone. The Python prototype is the regression baseline (PROTOTYPE_REPORT §4): porting + diffing it confirms the GDScript implementation matches semantics.

## Acceptance criteria
- [ ] `tools/sim.gd` headless entry point with CLI args `--runs N --seed-base S --out path`.
- [ ] Auto-play heuristic: greedy "pair-into-reaction" socket policy + simple "highest-damage" play policy (mirror prototype).
- [ ] CSV columns: `run_id, seed, outcome, battles_won, hp_left, gold, traits_collected, reactions_triggered, total_turns`.
- [ ] Aggregation report (`sim_summary.txt`): win-rate, per-trait pick_count, per-reaction fire_count, mean ± stddev.
- [ ] Diff harness: compares against `prototype/sim_results.csv` baseline; threshold rules:
  - win-rate within ±5% (prototype 59.1% → 54-64%)
  - per-reaction fire_count / run within 0.3-3 band (PRD §5.2)
  - any breach → exit code 2 + `sim_diff.txt` with offending rows
- [ ] `tests/test_sim_harness.gd`: 10-run smoke pass; deterministic given fixed seed-base.
- [ ] Documentation: `tools/sim.gd` header comment with runbook.

## Implementation hints
- Files: `tools/{sim,sim_diff}.gd`, `prototype/sim_results.csv` (baseline reference, do NOT modify), `tests/test_sim_harness.gd`
- 1k runs target wall-time < 60s on dev box (use Godot 4 GDScript; profile if slow).

## Blocked-by
- ISSUE-006, ISSUE-008

## Out of scope (this issue)
- Full GitHub Actions wiring → defer
- 80-trait population (still operating on the 5-10 sample traits at this stage)
- Visual UI for results

## Source
- PRD §5.2 平衡模拟器
- PROTOTYPE_REPORT §1, §4 下游路径
- CONTEXT §6 (headless sim command)
