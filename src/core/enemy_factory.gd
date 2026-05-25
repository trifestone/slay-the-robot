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
	enemy.intent = "Attack"
	enemy.carried_traits = []
	match tier:
		"elite":
			enemy.id = "elite_dummy"
			enemy.drop_count = 2
			enemy.intent_damage = ELITE_INTENT
			return {"enemy": enemy, "hp": ELITE_HP, "intent_damage": ELITE_INTENT}
		"boss":
			enemy.id = "boss_dummy"
			enemy.drop_count = 3
			enemy.intent_damage = BOSS_INTENT
			return {"enemy": enemy, "hp": BOSS_HP, "intent_damage": BOSS_INTENT}
		_:
			enemy.id = "normal_dummy"
			enemy.drop_count = 1
			enemy.intent_damage = NORMAL_INTENT
			return {"enemy": enemy, "hp": NORMAL_HP, "intent_damage": NORMAL_INTENT}


## Returns an Array of enemy specs for a tier.
## Layout:
##   normal -> 1 enemy
##   elite  -> 2 enemies (smaller HP each so total ~= 1.5x normal duo)
##   boss   -> 1 boss + 2 adds
## Each entry: { enemy, hp, max_hp, intent_damage }
func build_group(tier: String, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var group: Array = []
	match tier:
		"elite":
			group.append(_spec("elite_a", ELITE_HP, ELITE_INTENT, 2))
			# Second elite is a weaker bruiser so the duo is fair to fight.
			group.append(_spec("elite_b", int(ELITE_HP * 0.6), ELITE_INTENT - 2, 1))
		"boss":
			group.append(_spec("boss_core", BOSS_HP, BOSS_INTENT, 3))
			group.append(_spec("boss_add_1", int(NORMAL_HP * 0.8), NORMAL_INTENT, 1))
			group.append(_spec("boss_add_2", int(NORMAL_HP * 0.8), NORMAL_INTENT, 1))
		_:
			group.append(_spec("normal_a", NORMAL_HP, NORMAL_INTENT, 1))
	# Reshape into multi-enemy entry dictionaries. block is computed from
	# carried_traits (sum of effect_value for traits whose effect_type == "Block")
	# so resist/抵消 VFX has a real number to spend.
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


func _spec(id: String, hp: int, intent_damage: int, drop_count: int) -> Dictionary:
	var enemy: Resource = EnemyScript.new()
	enemy.id             = id
	enemy.intent         = "Attack"
	enemy.intent_damage  = intent_damage
	enemy.drop_count     = drop_count
	enemy.carried_traits = []
	return {"enemy": enemy, "hp": hp, "intent_damage": intent_damage}
