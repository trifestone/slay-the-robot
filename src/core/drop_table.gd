## drop_table.gd — ISSUE-008: Trait drop randomisation module.
## RefCounted (no class_name to avoid Slay-The-Robot collision).
extends RefCounted

# Probability tables: index = drop count, value = integer percentage weight.
const PROB_NORMAL_DROP_COUNT := [10, 60, 30]   # 0→10%, 1→60%, 2→30%
const PROB_ELITE_DROP_COUNT  := [0, 0, 100]    # always 2
const PROB_BOSS_DROP_COUNT   := [0, 0, 0, 100] # always 3

const RARITY_NORMAL := {"Common": 75, "Uncommon": 22, "Rare": 3}
const RARITY_ELITE  := {"Common": 40, "Uncommon": 50, "Rare": 10}
const RARITY_BOSS   := {"Common": 0,  "Uncommon": 40, "Rare": 60}

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _pick_from_weights(weights: Array, rng: RandomNumberGenerator) -> int:
	var total: int = 0
	for w in weights:
		total += w
	var roll: int = rng.randi_range(0, total - 1)
	var cumulative: int = 0
	for i in range(weights.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return i
	return weights.size() - 1


func _rarity_table(tier: String) -> Dictionary:
	if tier == "elite":
		return RARITY_ELITE
	if tier == "boss":
		return RARITY_BOSS
	return RARITY_NORMAL


func _drop_count_weights(tier: String) -> Array:
	if tier == "elite":
		return PROB_ELITE_DROP_COUNT
	if tier == "boss":
		return PROB_BOSS_DROP_COUNT
	return PROB_NORMAL_DROP_COUNT


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the count of traits to drop (0..3) by tier.
func roll_drop_count(tier: String, rng: RandomNumberGenerator) -> int:
	var weights: Array = _drop_count_weights(tier)
	return _pick_from_weights(weights, rng)


## Returns a rarity string ("Common"|"Uncommon"|"Rare") sampled by the tier table.
func roll_rarity(tier: String, rng: RandomNumberGenerator) -> String:
	var table: Dictionary = _rarity_table(tier)
	var keys: Array = ["Common", "Uncommon", "Rare"]
	var weights: Array = []
	for k in keys:
		weights.append(table.get(k, 0))
	var idx: int = _pick_from_weights(weights, rng)
	return keys[idx]


## Returns Array of trait_id Strings to drop.
## Samples drop_count via tier table, then per drop picks a random trait_id
## from carried_traits whose rarity matches. Falls back to any carried trait
## if no match found.
func roll_drops(carried_traits: Array, tier: String, rng: RandomNumberGenerator,
				trait_rarity_map: Dictionary) -> Array:
	var count: int = roll_drop_count(tier, rng)
	var result: Array = []
	for _i in range(count):
		var rarity: String = roll_rarity(tier, rng)
		# Collect candidates matching the rolled rarity
		var candidates: Array = []
		for tid in carried_traits:
			var trait_rarity: String = trait_rarity_map.get(tid, "")
			if trait_rarity == rarity:
				candidates.append(tid)
		# Fallback: use entire pool if no rarity match
		if candidates.is_empty():
			candidates = Array(carried_traits)
		if candidates.is_empty():
			continue
		var pick_idx: int = rng.randi_range(0, candidates.size() - 1)
		result.append(candidates[pick_idx])
	return result
