# AI Battle QA Exploration and Regression Plan

Audience: coding model / multi-agent execution system.

Run this plan from the repository root. Do not hard-code a machine-specific absolute path; all paths below are repository-relative unless explicitly marked as Godot `res://` or `user://` paths.

The goal is not to fix only a few known bugs. Card behavior, victory checks, and enemy death handling are examples from manual demo play. The real goal is to build an automated battle-logic QA system that explores as much of the combat state space as practical, discovers unknown bugs, turns every discovered bug into a deterministic regression test, and then fixes it through an evidence-driven loop.

## Project Facts

```text
Repository root:
.

Godot project root:
./src

Godot version:
4.6.2 stable

Existing test framework:
src/addons/gdUnit4

Existing tests:
src/tests/*.gd

Core combat modules:
src/core/battle_loop.gd
src/core/battle_state.gd
src/core/run.gd
src/core/emit.gd
src/core/reaction_registry.gd
src/core/reaction_predictor.gd
src/core/enemy_factory.gd

Existing simulation tools:
src/tools/sim.gd
src/tools/sim_runner.gd
src/tools/sim_diff.gd
```

Do not rebuild the test framework. Reuse the existing GdUnit4 suite and simulation harness.

## Core Testing Strategy

Build four layers:

```text
1. Rule regression tests
   Validate known gameplay rules.

2. Invariant tests
   Check battle state legality after every action.

3. Random exploration / fuzz tests
   Explore unknown bugs with many seeds, random decks, random enemies, and random legal actions.

4. AI repair loop
   Convert each discovered failure into a minimal deterministic regression test, then fix and verify.
```

## P0: Battle Invariants

Add:

```text
src/tests/support/invariant_checks.gd
src/tests/support/state_snapshot.gd
src/tests/support/fixture_factory.gd
```

`invariant_checks.gd` is the core of the QA system. It must be reusable from GdUnit tests and simulation code.

Minimum invariant coverage:

```text
Player HP:
- player_hp >= 0
- player_hp <= max_hp
- max_hp > 0
- player_hp == 0 implies lost or a reasonable finished state

Energy:
- energy >= 0
- energy <= max_energy
- max_energy > 0
- failed card play cannot spend energy

Card zones:
- hand contains no null cards
- deck contains no null cards
- discard contains no null cards
- hand.size <= 10
- played card leaves hand
- normally played card enters a legal zone: discard, exhaust, or limbo
- no card instance appears in multiple zones at the same time

Enemies:
- enemy hp >= 0
- dead enemy hp == 0
- primary_enemy_idx is valid
- primary enemy is alive unless all enemies are dead
- all enemies dead implies is_over().won == true
- partial enemy death must not end the battle
- dead enemies cannot act
- dead enemies cannot be selected as legal targets

Battle phase:
- ongoing, won, and lost cannot contradict each other
- after battle finish, play_card must not mutate core state
- after battle finish, end_turn must not trigger enemy action
- battle_finished signal must not fire more than once

Resolution logs:
- trait_fire_log entries have required fields
- damage_events dmg/block values are not negative
- fire_depth returns to 0 after resolution
- cooldown_table resets reasonably on turn change
- resolution chain cannot recurse forever
```

Add invariant calls after important actions in existing tests:

```text
src/tests/test_battle_loop.gd
src/tests/test_battle_scene.gd
src/tests/test_run_sequence.gd
src/tests/test_sim_harness.gd
```

Call invariants after:

```text
start_battle
play_card
end_turn
enemy death
battle finish
run battle
```

## P1: State Snapshots

`state_snapshot.gd` must convert `BattleState` and `RunState` into stable dictionaries/JSON for failure artifacts.

Include:

```text
seed
turn
phase
player_hp
max_hp
energy
max_energy
primary_enemy_idx
is_over result

enemies:
  id
  hp
  max_hp
  intent_damage
  block
  alive/dead

hand:
  size
  card ids or trait ids

deck size
discard size
trait_fire_log tail
damage_events tail
battle_log tail 30 lines
```

On failure, write snapshots to:

```text
user://qa_failures/
user://qa_snapshots/
```

## P2: Fixture Factory

`fixture_factory.gd` should centralize helpers currently duplicated across tests:

```text
make_trait(id, trigger, effect_type, effect_value)
make_card(traits)
make_deck(cards)
make_enemy(id, hp, intent_damage)
make_enemy_group(count, hp_profile)
make_run_state(seed, deck, hp)
```

Keep fixtures deterministic and small.

## P3: Random Battle Fuzz

Add:

```text
src/tests/test_battle_fuzz.gd
src/tests/test_battle_property_randomized.gd
src/tests/test_run_fuzz.gd
```

The fuzz goal is not fixed expected outcomes. It is illegal state discovery.

`test_battle_fuzz.gd` should:

```text
1. Generate a seed.
2. Generate player HP.
3. Generate a 5-20 card deck.
4. Generate cards with 1-3 random traits.
5. Generate 1-3 enemies.
6. Repeatedly choose a random legal action:
   - play_card
   - end_turn
   - choose target
7. Run invariant checks after every action.
8. Record failed seed, action sequence, failed invariant, and state snapshot.
```

Only choose legal actions:

```text
play_card only if energy is sufficient
play_card only if card is in hand
target only if enemy is alive
after battle finish, stop actions and verify lock behavior
```

Every fuzz failure must produce a reproducible artifact:

```json
{
  "seed": 12345,
  "initial_state": {},
  "actions": [
    "start_battle",
    "play_card hand[2] target[0]",
    "end_turn",
    "play_card hand[0] target[1]"
  ],
  "failed_invariant": "dead enemy attacked",
  "snapshot": "user://qa_snapshots/fuzz_12345.json"
}
```

## P4: Seed Replay Tests

Add deterministic replay support for fuzz failures.

When fuzz finds a failure:

```text
1. Save seed and action sequence.
2. Generate or manually add a deterministic GdUnit test.
3. Confirm the replay test fails before any fix.
4. Fix code.
5. Keep the replay test permanently.
```

This converts exploration bugs into permanent regression coverage.

## P5: Lightweight Model Tests

Add:

```text
src/tests/test_battle_model_properties.gd
```

Do not implement a second full game. Use a minimal model tracking:

```text
player_hp
energy
hand_count
alive_enemy_count
battle_finished
```

Check high-level consistency:

```text
If the model says all enemies are dead, real is_over().won must be true.
If the model says energy is insufficient, real play_card must not succeed.
If the model says the battle is finished, real state must not mutate from player actions.
If the model says an enemy is dead, real enemy cannot attack.
```

## P6: Metamorphic Tests

Add:

```text
src/tests/test_battle_metamorphic.gd
```

These tests validate relationships instead of hard-coded outcomes:

```text
Same seed and same actions produce identical result.
Same seed and same actions produce identical battle_log hash.
Same damage card deals the same damage to 10 HP and 20 HP enemies.
Changing enemy max_hp must not change the player's initial hand.
Changing player max_hp must not change enemy initial intent.
Same shuffle seed produces same opening hand order.
```

These are high-value for finding RNG leaks, state leaks, and UI/core coupling bugs.

## P7: Simulation Regression

Strengthen:

```text
src/tools/sim.gd
src/tools/sim_runner.gd
src/tools/sim_diff.gd
```

The simulation should track more than win rate.

Add counters:

```text
crash_count
invariant_violation_count
stuck_count
max_turns_exceeded_count
invalid_state_count
dead_enemy_action_count
post_finish_mutation_count
negative_energy_count
negative_hp_count
duplicate_card_zone_count
```

Call invariant checks after every battle action inside simulation.

When simulation fails, write:

```text
user://qa_failures/seed_XXXXX.json
```

Include:

```text
seed
battle index
action sequence
failure type
state snapshot
battle_log tail
```

Also fix the current `sim_runner.gd` blind spots:

```text
reactions_triggered must not be hard-coded to 0.
total_turns must not use battles_won as a proxy.
```

Recommended `Run.play_battle()` return additions:

```gdscript
{
  "won": won_battle,
  "hp_left": run_state["player_hp"],
  "battle_log_size": state.battle_log.size(),
  "turns": state.turn,
  "reaction_fire_count": _count_reactions(state.trait_fire_log)
}
```

Count reactions with:

```text
entry["source"] == "reaction"
```

## P8: QA Commands

Add:

```text
tools/qa/run_fast.ps1
tools/qa/run_fuzz.ps1
tools/qa/run_sim.ps1
tools/qa/run_regression.ps1
tools/qa/write_regression_artifact.py
```

`run_fast.ps1`:

```powershell
Set-Location "$PSScriptRoot/../../src"
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests
exit $LASTEXITCODE
```

`run_sim.ps1`:

```powershell
Set-Location "$PSScriptRoot/../../src"

godot --headless --path . -s tools/sim.gd -- --runs 1000 --seed-base 1 --out user://sim_results.csv
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

godot --headless --path . -s tools/sim_diff.gd -- --actual user://sim_results.csv --baseline res://prototype/sim_results.csv --out user://sim_diff.txt
exit $LASTEXITCODE
```

`run_regression.ps1` order:

```text
1. Run existing full GdUnit suite.
2. Run battle fuzz.
3. Run run fuzz.
4. Run 1000-run sim.
5. Run sim_diff.
6. Generate .omc/state/regression/R###.json.
```

## P9: OMC Regression Artifact

Each QA round must write:

```text
.omc/state/regression/R###.json
```

Green example:

```json
{
  "round_n": 1,
  "started_at": "ISO8601",
  "finished_at": "ISO8601",
  "tests_total": 0,
  "tests_failed": 0,
  "fuzz_seeds_run": 1000,
  "fuzz_failures": 0,
  "sim_runs": 1000,
  "sim_failures": 0,
  "failed_test_ids": [],
  "failed_seeds": [],
  "error_fingerprints": [],
  "failure_artifacts": [],
  "verdict": "green"
}
```

Failure artifacts must include:

```text
failed seed
action sequence
failed invariant
snapshot path
minimal replay test path
suspected files
reproduction command
```

## P10: AI Repair Loop

When fuzz or simulation finds a bug, do not directly patch code.

Use this loop:

```text
1. debugger reads seed, action sequence, snapshot, and battle_log.
2. test-engineer turns that seed and action sequence into a minimal GdUnit replay test.
3. verifier confirms the replay test fails.
4. executor fixes production code.
5. verifier runs:
   - the new replay test
   - related focused tests
   - full GdUnit suite
   - fuzz/sim regression
6. code-reviewer checks diff scope and regression risk.
```

Rule:

```text
fuzz discovers bug
=> deterministic replay test
=> code fix
=> permanent regression coverage
```

## OMC Agent Roles

```text
qa-tester:
Run run_regression.ps1 and collect failed seeds/artifacts.

test-engineer:
Write invariants, fuzz tests, metamorphic tests, and replay tests.

debugger:
Use seed, action sequence, snapshot, and logs to isolate root cause.

executor:
Fix battle_loop, battle_state, emit, run, battle_scene, or related code.

code-reviewer:
Check that the fix is scoped, deterministic, and not just a UI workaround.

verifier:
Re-run regression and update GREEN_GATE / NO_PROGRESS_LIMIT state.

writer:
Write handoff with discovered bugs, fixed seeds, and remaining risks.
```

## Matt Pocock Skill Usage

Use these workflows by meaning, even if local skill names differ:

```text
tdd:
All fixes must start from a failing test.

diagnose:
Minimize fuzz failures before fixing. Do not guess.

grill-with-docs:
When behavior conflicts with docs/prd/v0.md, docs/adr/ADR-001, or docs/issues/*.md, align with docs first.

grill-me:
When rules are unclear, file a clarification question. Do not invent product behavior.

handoff:
Record new tests, discovered bugs, fixed seeds, and unresolved risks after each QA loop.
```

## Clarification Protocol

Do not guess in these cases:

```text
A fuzz failure might be intended design rather than a bug.
Overkill damage behavior is unclear.
Simultaneous player/enemy death priority is unclear.
Dead enemies may or may not trigger death effects or drops during the current chain.
Animations may continue after battle end, but state mutation rules are unclear.
Trait text and actual effect conflict.
```

Write:

```text
.omc/state/clarifications/pending/Q###.json
```

## Execution Order

Strict order:

```text
P0:
Create invariant_checks.gd, state_snapshot.gd, fixture_factory.gd.

P1:
Wire invariants into existing battle_loop, battle_scene, and run_sequence tests.

P2:
Add battle fuzz: random legal actions plus invariant checks after every step.

P3:
Add deterministic seed replay support.

P4:
Add metamorphic tests for determinism, state relationships, and battle_log hash.

P5:
Strengthen sim_runner with invariant failures, stuck detection, invalid state detection, and failed seed artifacts.

P6:
Add tools/qa/run_regression.ps1 and R###.json output.

P7:
Run exploration tests and collect failing seeds.

P8:
Turn every failing seed into a minimal GdUnit regression test.

P9:
Fix bugs.

P10:
Run full regression. Stop only after two consecutive green rounds.
```

## Exit Conditions

```text
GREEN_GATE:
Two consecutive rounds where:
- full GdUnit passes
- battle fuzz passes
- run fuzz passes
- simulation passes
- sim_diff passes

NO_PROGRESS_LIMIT:
Three consecutive rounds where:
- failed seeds are identical
- error fingerprints are identical
- no effective code changes were made

If NO_PROGRESS_LIMIT is reached, pause and write a human intervention report.
```

## Final Deliverables

Report:

```text
1. Added automated exploration test files.
2. Invariant list.
3. Fuzz strategy.
4. Bugs discovered.
5. Failed seeds for each bug.
6. GdUnit replay test for each failed seed.
7. Files fixed.
8. Latest .omc/state/regression/R###.json.
9. Final regression command and result.
```

Success is not "a few known bugs were fixed". Success is:

```text
The project can continuously explore combat state space, discover unknown battle-logic bugs, turn each bug into deterministic regression coverage, and repair through a verified AI loop.
```
