## Run — orchestrates an 18-battle roguelike run (ISSUE-006).
##
## 3 acts × (4 normal + 1 elite + 1 boss) = 18 battles in fixed order.
## Player HP/deck/gold/traits carry over between battles.
## Death stops the run immediately.
##
## Public API:
##   start_run(seed, starting_deck, starting_hp) -> Dictionary  (RunState)
##   play_battle(run_state, battle_idx)          -> Dictionary  {won, hp_left, battle_log_size}
##   play_full_run(run_state)                    -> Dictionary  (mutated run_state + summary)
##
## RunState keys:
##   seed, player_hp, max_hp, deck, gold, traits_collected,
##   battles_won, current_battle, outcome
extends RefCounted

const BattleLoopScript        := preload("res://core/battle_loop.gd")
const EnemyScript             := preload("res://data/enemy.gd")
const PostBattleScript        := preload("res://core/post_battle.gd")
const DropTableScript         := preload("res://core/drop_table.gd")
const InventoryManagerScript  := preload("res://core/inventory_manager.gd")

# ---------------------------------------------------------------------------
# HP scaling per act / tier  (PRD §4.8 mid-act values)
# ---------------------------------------------------------------------------
const ACT_HP := [
	# act 0 (act 1)
	{"normal": 15, "elite": 45,  "boss": 110},
	# act 1 (act 2)
	{"normal": 20, "elite": 55,  "boss": 140},
	# act 2 (act 3)
	{"normal": 25, "elite": 60,  "boss": 180},
]

# Gold awarded per kill tier
const GOLD_NORMAL: int = 5
const GOLD_ELITE:  int = 15
const GOLD_BOSS:   int = 30

# Battle order within one act: 4 normal (indices 0-3), 1 elite (4), 1 boss (5)
const ACT_PATTERN := ["normal", "normal", "normal", "normal", "elite", "boss"]

# ---------------------------------------------------------------------------
# Enemy data — loaded once, grouped by tier
# ---------------------------------------------------------------------------

var _enemies_by_tier: Dictionary = {}  # "normal"|"elite"|"boss" -> Array of Dicts

func _ensure_enemies_loaded() -> void:
	if not _enemies_by_tier.is_empty():
		return
	var path := "res://data/enemies.json"
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "run.gd: cannot open %s" % path)
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	assert(parsed != null and parsed is Array, "run.gd: enemies.json parse failed")

	_enemies_by_tier = {"normal": [], "elite": [], "boss": []}
	for entry in parsed:
		var tier: String = entry.get("tier", "normal")
		if _enemies_by_tier.has(tier):
			_enemies_by_tier[tier].append(entry)


## Build a TraitEnemy Resource from a raw dict entry.
func _make_enemy_resource(entry: Dictionary) -> Resource:
	var e: Resource = EnemyScript.new()
	e.id         = entry.get("id", "unknown")
	e.intent     = entry.get("intent", "Attack")
	e.drop_count = entry.get("drop_count", 1)
	# carried_traits stored as ids (Array of String) — ISSUE-008 will resolve to Resources
	e.carried_traits = Array(entry.get("carried_traits", []))
	return e


# ---------------------------------------------------------------------------
# Run state helpers
# ---------------------------------------------------------------------------

## Returns a fresh RunState Dictionary.
func _make_run_state(seed: int, starting_deck: Array, starting_hp: int) -> Dictionary:
	return {
		"seed":              seed,
		"player_hp":         starting_hp,
		"max_hp":            starting_hp,
		"deck":              starting_deck.duplicate(),
		"gold":              0,
		"traits_collected":  [],
		"battles_won":       0,
		"current_battle":    0,
		"outcome":           "ongoing",
		"heal_log":          [],
		"inventory":         [],
		"warnings":          [],
		"trait_rarity_map":  {},
	}


## Map a global battle index (0-17) to {act, slot, tier, hp}.
func _battle_info(battle_idx: int) -> Dictionary:
	var act: int  = battle_idx / 6          # 0, 1, or 2
	var slot: int = battle_idx % 6          # 0-5 within act
	var tier: String = ACT_PATTERN[slot]
	var hp: int = ACT_HP[act][tier]
	return {"act": act, "slot": slot, "tier": tier, "hp": hp}


## Pick an enemy for a given act+tier, cycling deterministically by RNG.
func _pick_enemy(tier: String, rng: RandomNumberGenerator) -> Dictionary:
	_ensure_enemies_loaded()
	var pool: Array = _enemies_by_tier[tier]
	assert(pool.size() > 0, "run.gd: no enemies for tier '%s'" % tier)
	var idx: int = rng.randi_range(0, pool.size() - 1)
	return pool[idx]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Initialise a new run. Returns a RunState Dictionary.
func start_run(seed: int, starting_deck: Array, starting_hp: int = 80) -> Dictionary:
	_ensure_enemies_loaded()
	var state: Dictionary = _make_run_state(seed, starting_deck, starting_hp)
	# Build trait rarity map once from traits.json (read String directly, bypass loader enum).
	var tpath := "res://data/traits.json"
	var tfile := FileAccess.open(tpath, FileAccess.READ)
	if tfile != null:
		var ttext := tfile.get_as_text()
		tfile.close()
		var tparsed = JSON.parse_string(ttext)
		if tparsed != null and tparsed is Array:
			for entry in tparsed:
				var tid: String = entry.get("id", "")
				var rarity: String = entry.get("rarity", "Common")
				if tid != "":
					state["trait_rarity_map"][tid] = rarity
	return state


## Play battle at battle_idx (0-17) using current run_state.
## Mutates run_state in place. Returns {won, hp_left, battle_log_size}.
func play_battle(run_state: Dictionary, battle_idx: int) -> Dictionary:
	var info: Dictionary = _battle_info(battle_idx)

	# Per-run seeded RNG: advance state deterministically
	var rng := RandomNumberGenerator.new()
	rng.seed = run_state["seed"] + battle_idx * 1000

	var entry: Dictionary = _pick_enemy(info["tier"], rng)
	var enemy: Resource   = _make_enemy_resource(entry)

	var loop: Object = BattleLoopScript.new()
	# battle seed: combine run seed + battle index for determinism
	var battle_seed: int = run_state["seed"] ^ (battle_idx * 6364136223846793005 + 1442695040888963407)
	# keep seed in positive int32 range to avoid RNG issues
	battle_seed = (battle_seed & 0x7FFFFFFF) + 1

	var state: Object = loop.start_battle(
		run_state["player_hp"],
		run_state["max_hp"],
		run_state["deck"],
		enemy,
		battle_seed
	)
	# Override enemy_hp with act-scaled value. Multi-enemy plumbing keeps
	# state.enemies authoritative, so push the override into the entry too.
	state.enemy_hp = info["hp"]
	state.sync_primary_hp_into_entry()
	if state.enemies != null and not state.enemies.is_empty():
		var idx: int = int(state.primary_enemy_idx)
		var primary_entry: Dictionary = state.enemies[idx]
		primary_entry["max_hp"] = int(info["hp"])
		state.enemies[idx] = primary_entry

	# --- Greedy AI player loop ---
	var safety: int = 0
	while loop.is_over(state)["ongoing"] and safety < 200:
		safety += 1
		var hand_copy: Array = state.hand.duplicate()
		for card in hand_copy:
			if state.energy > 0 and loop.is_over(state)["ongoing"]:
				loop.play_card(state, card, null)
		if loop.is_over(state)["ongoing"]:
			loop.end_turn(state)

	var result: Dictionary = loop.is_over(state)
	var won_battle: bool   = result["won"]

	# --- Update run state ---
	run_state["player_hp"]      = state.player_hp
	run_state["current_battle"] = battle_idx + 1

	if won_battle:
		run_state["battles_won"] += 1
		# Collect traits via RNG drop table (ISSUE-008)
		var drop_rng := RandomNumberGenerator.new()
		drop_rng.seed = run_state["seed"] + battle_idx * 1009 + 7
		var dropped: Array = DropTableScript.new().roll_drops(
			entry.get("carried_traits", []), info["tier"], drop_rng, run_state["trait_rarity_map"])
		var inv_mgr: Object = InventoryManagerScript.new()
		for tid in dropped:
			run_state["traits_collected"].append(tid)
			inv_mgr.add(run_state["inventory"], run_state["warnings"], tid)
		# Award gold
		match info["tier"]:
			"normal": run_state["gold"] += GOLD_NORMAL
			"elite":  run_state["gold"] += GOLD_ELITE
			"boss":   run_state["gold"] += GOLD_BOSS

	# Post-battle hook — ISSUE-007 heal wired here
	_post_battle_hook(run_state, won_battle, info["tier"])

	# Check death
	if run_state["player_hp"] <= 0:
		run_state["outcome"] = "lost"

	return {
		"won":            won_battle,
		"hp_left":        run_state["player_hp"],
		"battle_log_size": state.battle_log.size(),
	}


## Play all 18 battles (or until death). Returns the mutated run_state.
func play_full_run(run_state: Dictionary) -> Dictionary:
	for i in range(18):
		if run_state["outcome"] != "ongoing":
			break
		play_battle(run_state, i)

	# If all 18 completed and still alive, mark won
	if run_state["outcome"] == "ongoing":
		run_state["outcome"] = "won"

	return run_state


# ---------------------------------------------------------------------------
# Post-battle hook stub
# ---------------------------------------------------------------------------

## Post-battle hook — ISSUE-007 heal, ISSUE-008 drop randomization.
func _post_battle_hook(run_state: Dictionary, won_battle: bool, tier: String) -> void:
	if won_battle:
		var healed: int = PostBattleScript.new().apply_heal(run_state, tier)
		run_state["heal_log"].append({"tier": tier, "healed": healed})
	# ISSUE-008: drop randomization wires here
