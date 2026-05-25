# ISSUE-005 — BattleState + single-fight loop (3 energy / 5 draw / 10 hand)

**Labels**: `enhancement`, `AFK`, `status:ready-for-agent`
**User Story**: Foundation for US-01, US-02, US-03
**Estimate**: M (2-8h)

## What
Wire emit() into a complete single-fight loop: deck/draw/discard piles, 3 energy regenerated each turn, draw 5 at turn start, hand limit 10, simple enemy with intent (attack N) and `carried_traits`, win/lose detection. End-to-end: a fixed-seed scripted battle (player 80 HP vs single enemy 25 HP, 5-card deck with 1 `flame_brand` trait card) runs to completion deterministically and asserts a hash on the battle log.

## Why
PRD §4.2 locks combat baseline. ADR-001's emit() needs a real state to operate over. The fight loop is the smallest end-to-end vertical slice that exercises Trait → emit → Effect → state → win/lose.

## Acceptance criteria
- [ ] `src/core/battle_state.gd` holds `player_hp, max_hp, energy, deck, hand, discard, enemy, turn`. Resets cooldowns at turn start.
- [ ] `src/core/battle_loop.gd` exposes `start_battle(player, enemy, seed)`, `play_card(card, target)`, `end_turn()`, `is_over() -> {ongoing, won, lost}`.
- [ ] Turn start: regen 3 energy, draw 5, reset trait/reaction cooldowns.
- [ ] Hand limit: discarding extras when reaching 11 (StS rule).
- [ ] Enemy turn: applies intent damage; skipped on death.
- [ ] Empty deck triggers reshuffle from discard.
- [ ] State-charts integration: PlayerTurn / EnemyTurn / Resolution sub-states (godot-state-charts) — minimal HSM correct.
- [ ] `tests/test_battle_loop.gd`: fixed seed (e.g., 42), fixed deck, fixed enemy → battle log hash matches golden file (regression-safe). Asserts player HP > 0 + enemy HP == 0 at end.

## Implementation hints
- Files: `src/core/{battle_state,battle_loop}.gd`, `src/core/fsm/battle.tscn` (state-chart), `tests/test_battle_loop.gd`, `tests/golden/battle_seed_42.hash`
- Reference PRD §4.2 numbers exactly. Use `RandomNumberGenerator` with `seed` property for deterministic shuffles.

## Blocked-by
- ISSUE-003

## Out of scope (this issue)
- 18-fight Run sequence → ISSUE-006
- Post-battle healing → ISSUE-007
- Enemy drop on kill → ISSUE-008
- Hand UI → ISSUE-009
- Enemy intent UI → ISSUE-010

## Source
- PRD §4.2 + §4.7 (state-charts)
- ADR-001
- CONTEXT §6
