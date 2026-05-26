## EnemyFactory — minimal tier→enemy resolver for ISSUE-023.
##
## Returns a TraitEnemy + a sane initial HP for Normal / Elite / Boss tiers.
## A full bestiary lookup is out of scope; this stub keeps battles playable
## until the data-driven enemy table lands.
extends RefCounted

const EnemyScript := preload("res://data/enemy.gd")

const NORMAL_HP: int = 25
const ELITE_HP:  int = 50
const BOSS_HP:   int = 100

const NORMAL_INTENT: int = 5
const ELITE_INTENT:  int = 9
const BOSS_INTENT:   int = 14


## Returns { enemy: TraitEnemy, hp: int, intent_damage: int }.
## intent_damage is also stamped onto enemy.intent_damage so battle_loop
## reads the tier-correct value via _get_intent_damage().
func build(tier: String) -> Dictionary:
	var enemy: Resource = EnemyScript.new()
	enemy.carried_traits = []
	match tier:
		"elite":
			enemy.id = "elite_dummy"
			enemy.drop_count = 2
			enemy.intent_damage = ELITE_INTENT
			enemy.intent_block = ELITE_INTENT - 2
			enemy.ai_type = "aggressive"
			enemy.intent_pattern = ["Attack", "Attack", "Block", "Buff"]
			enemy.buff_power = 3
			return {"enemy": enemy, "hp": ELITE_HP, "intent_damage": ELITE_INTENT}
		"boss":
			enemy.id = "boss_dummy"
			enemy.drop_count = 3
			enemy.intent_damage = BOSS_INTENT
			enemy.intent_block = BOSS_INTENT - 4
			enemy.ai_type = "boss"
			enemy.intent_pattern = ["Charge", "Charge", "MegaAttack", "Debuff", "Block"]
			enemy.charge_turns = 2
			enemy.buff_power = 4
			enemy.debuff_power = 2
			return {"enemy": enemy, "hp": BOSS_HP, "intent_damage": BOSS_INTENT}
		_:
			enemy.id = "normal_dummy"
			enemy.drop_count = 1
			enemy.intent_damage = NORMAL_INTENT
			enemy.intent_block = NORMAL_INTENT - 2
			enemy.ai_type = "balanced"
			enemy.intent_pattern = ["Attack", "Block"]
			return {"enemy": enemy, "hp": NORMAL_HP, "intent_damage": NORMAL_INTENT}


## Returns an Array of enemy specs for a tier.
## Layout:
##   normal -> 1 enemy (balanced)
##   elite  -> 2 enemies with coordination (tank + aggressive)
##   boss   -> 1 boss + 2 adds (boss with charge mechanic + tank adds)
## Each entry: { enemy, hp, max_hp, intent_damage }
func build_group(tier: String, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var group: Array = []
	match tier:
		"elite":
			# Elite A: Aggressive (damage dealer) with varied pattern
			group.append(_spec("elite_striker", ELITE_HP, ELITE_INTENT, 2, "aggressive", ["Attack", "Attack", "Buff", "Block"], 3, 0))
			# Elite B: Tank (protects striker) - more defensive
			group.append(_spec("elite_guardian", int(ELITE_HP * 0.7), ELITE_INTENT - 3, 1, "tank", ["Block", "Attack", "Block", "Debuff"], 2, 1))
		"boss":
			# Boss: Complex AI with charge mechanic
			group.append(_spec("boss_core", BOSS_HP, BOSS_INTENT, 3, "boss", ["Charge", "Charge", "MegaAttack", "Debuff", "Block"], 4, 2, 2))
			# Boss adds: Tanks that protect boss
			group.append(_spec("boss_minion_1", int(NORMAL_HP * 0.8), NORMAL_INTENT, 1, "tank", ["Block", "Attack", "Block", "Buff"], 0, 0))
			group.append(_spec("boss_minion_2", int(NORMAL_HP * 0.8), NORMAL_INTENT, 1, "support", ["Debuff", "Attack", "Buff", "Attack"], 0, 0))
		_:
			# Normal: Simple balanced enemy
			group.append(_spec("normal_a", NORMAL_HP, NORMAL_INTENT, 1, "balanced", ["Attack", "Block"], 0, 0))

	# Reshape into multi-enemy entry dictionaries.
	var entries: Array = []
	for spec in group:
		var enemy: Resource = spec["enemy"]
		var block: int = _block_from_traits(enemy)
		entries.append({
			"enemy":         enemy,
			"hp":            int(spec["hp"]),
			"max_hp":        int(spec["hp"]),
			"intent_damage": int(spec["intent_damage"]),
			"block":         block,
			"max_block":     block,
		})
	return entries


## Sum effect_value for any carried trait whose effect_type == "Block".
## Carried traits may be Trait Resources OR id strings (legacy data path);
## strings can't carry an effect_value so they contribute 0.
func _block_from_traits(enemy: Resource) -> int:
	if enemy == null:
		return 0
	var carried: Array = enemy.carried_traits if "carried_traits" in enemy else []
	var total: int = 0
	for t in carried:
		if t == null:
			continue
		if typeof(t) == TYPE_OBJECT and "effect_type" in t and "effect_value" in t:
			if String(t.effect_type) == "Block":
				total += int(t.effect_value)
	return total


func _spec(id: String, hp: int, intent_damage: int, drop_count: int,
		   ai_type: String = "balanced", intent_pattern: Array = [],
		   buff_power: int = 0, debuff_power: int = 0, charge_turns: int = 0) -> Dictionary:
	var enemy: Resource = EnemyScript.new()
	enemy.id             = id
	enemy.intent         = "Attack"
	enemy.ai_type         = ai_type
	enemy.intent_pattern  = intent_pattern.duplicate()
	enemy.intent_damage   = intent_damage
	enemy.intent_block    = intent_damage - 2
	enemy.drop_count      = drop_count
	enemy.buff_power      = buff_power
	enemy.debuff_power    = debuff_power
	enemy.charge_turns     = charge_turns
	enemy.carried_traits  = []
	# Initialize to first pattern intent
	if not intent_pattern.is_empty():
		enemy.intent = String(intent_pattern[0])
	return {"enemy": enemy, "hp": hp, "intent_damage": intent_damage}
