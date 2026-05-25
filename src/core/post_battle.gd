## PostBattle — post-battle heal module (ISSUE-007).
##
## Heal amounts per enemy kind (PRD §4.8):
##   normal → +5 HP, elite → +10 HP, boss → +20 HP
## Heals are clamped to max_hp; the caller receives the actual amount healed.
##
## No class_name declaration — avoids collision with upstream Slay-The-Robot symbols.
extends RefCounted

## Heal amounts per enemy kind (PRD §4.8).
const HEAL_NORMAL: int = 5
const HEAL_ELITE:  int = 10
const HEAL_BOSS:   int = 20


## Returns the heal amount for a given enemy kind ("normal"|"elite"|"boss").
## Does NOT mutate state — caller applies the value with clamp.
func heal_amount(enemy_kind: String) -> int:
	match enemy_kind:
		"elite": return HEAL_ELITE
		"boss":  return HEAL_BOSS
	return HEAL_NORMAL


## Apply post-battle heal to a RunState Dictionary (mutates in place).
## run_state["player_hp"] += heal_amount(kind), clamped to run_state["max_hp"].
## Returns the actual amount healed (after clamp).
func apply_heal(run_state: Dictionary, enemy_kind: String) -> int:
	var amount: int = heal_amount(enemy_kind)
	var hp_before: int = run_state["player_hp"]
	var max_hp: int = run_state["max_hp"]
	var hp_after: int = min(hp_before + amount, max_hp)
	run_state["player_hp"] = hp_after
	return hp_after - hp_before
