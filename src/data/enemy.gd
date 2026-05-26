## TraitEnemy Resource — describes an enemy's identity and the traits it carries.
## Named TraitEnemy to avoid collision with the upstream Slay-the-Robot Enemy class.
class_name TraitEnemy
extends Resource

## Unique identifier, e.g. "skeleton_grunt".
@export var id: String = ""

## Current intent string: "Attack" | "Block" | "Buff" | "Debuff" | "Charge" (StS-style).
@export var intent: String = "Attack"

## Intent pattern — sequence of intents this enemy cycles through.
## Example: ["Attack", "Attack", "Block"] means Attack twice, then Block.
## If empty, uses single random intent each turn.
@export var intent_pattern: Array = []  # Array[String]

## Current position in intent_pattern (for cycling).
var _pattern_index: int = 0

## AI behavior type for multi-enemy coordination.
## "balanced": Standard mix of attack/defense.
## "tank": Prefers Block, protects allies.
## "aggressive": Higher damage, rarely blocks.
## "support": Buffs allies or debuffs player.
## "boss": Complex patterns with charge mechanics.
@export var ai_type: String = "balanced"  # balanced | tank | aggressive | support | boss

## Traits this enemy carries (dropped on kill per drop_count).
@export var carried_traits: Array = []  # Array[Trait]

## How many traits this enemy drops on death.
## Normal: 1, Elite: 2, Boss: 3.
@export var drop_count: int = 1

## Base damage for Attack intent.
@export var intent_damage: int = 5

## Block amount for Block intent.
@export var intent_block: int = 5

## Buff power (e.g., strength gained).
@export var buff_power: int = 2

## Debuff power (e.g., vulnerability applied).
@export var debuff_power: int = 1

## Charge turns for boss special attacks.
## 0 = no charge, 1+ = needs N turns to charge before unleashing.
@export var charge_turns: int = 0

## Current charge counter.
var _charge_counter: int = 0

## Current strength buff (increases damage dealt).
var strength: int = 0

## Current vulnerable debuff (increases damage taken).
var vulnerable: int = 0

## Current weak debuff (decreases damage dealt).
var weak: int = 0

## Enemy's own block (like player_block).
var block: int = 0


## Advance to next intent in pattern (or random if no pattern).
## Call at end of enemy turn.
func advance_intent(rng: RandomNumberGenerator = null) -> void:
	if intent_pattern.is_empty():
		# No pattern — pick based on AI type
		intent = _pick_random_intent(rng)
	else:
		# Cycle through pattern
		_pattern_index = (_pattern_index + 1) % intent_pattern.size()
		intent = String(intent_pattern[_pattern_index])

	# Handle charge mechanic
	if intent == "Charge":
		_charge_counter += 1
		if charge_turns > 0 and _charge_counter >= charge_turns:
			intent = "MegaAttack"  # Ready to unleash
			_charge_counter = 0


## Reset to first intent in pattern (called on battle start).
func reset_intent() -> void:
	_pattern_index = 0
	_charge_counter = 0
	strength = 0
	vulnerable = 0
	weak = 0
	block = 0
	if not intent_pattern.is_empty():
		intent = String(intent_pattern[0])


## Pick random intent based on AI type weights.
func _pick_random_intent(rng: RandomNumberGenerator = null) -> String:
	var intents: Array = []
	var weights: Array = []

	match ai_type:
		"tank":
			intents = ["Attack", "Block", "Buff"]
			weights = [0.3, 0.5, 0.2]  # 50% block
		"aggressive":
			intents = ["Attack", "Attack", "Buff"]
			weights = [0.7, 0.2, 0.1]  # 70% attack
		"support":
			intents = ["Attack", "Buff", "Debuff"]
			weights = [0.3, 0.35, 0.35]  # Buffs and debuffs
		"boss":
			intents = ["Attack", "Block", "Buff", "Debuff", "Charge"]
			weights = [0.35, 0.2, 0.2, 0.15, 0.1]  # Varied
		_:	# balanced
			intents = ["Attack", "Block", "Buff"]
			weights = [0.5, 0.3, 0.2]

	return _weighted_random(intents, weights, rng)


func _weighted_random(options: Array, weights: Array, rng: RandomNumberGenerator = null) -> String:
	var total: float = 0.0
	for w in weights:
		total += w

	var roll: float
	if rng != null:
		roll = rng.randf() * total
	else:
		roll = randf() * total

	var cumulative: float = 0.0
	for i in range(options.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return String(options[i])

	return String(options[options.size() - 1])
