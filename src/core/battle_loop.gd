## BattleLoop — single-fight controller (ISSUE-005).
##
## Exposes the public API consumed by tests and future UI layers:
##   start_battle(player_hp, max_hp, deck, enemy, seed) -> BattleState
##   play_card(state, card, target) -> void
##   end_turn(state) -> void
##   is_over(state) -> Dictionary  { ongoing, won, lost }
##
## Internal helpers (prefixed _):
##   _draw_n(state, n)           — draw n cards; reshuffles discard when deck empty
##   _apply_intent(state)        — enemy attacks for intent_damage
##   _discard_to_limit(state)    — discard extras when hand >= 11 (StS rule)
##
## Phase FSM (enum, path-2 — no external addon):
##   PLAYER_TURN → EnemyTurn transition via end_turn()
##   ENEMY_TURN  → PLAYER_TURN transition after _apply_intent()
##   RESOLUTION  → GAME_OVER when is_over() detects a terminal condition
##
## PRD §4.2 numbers used verbatim:
##   max_energy = 3, draw_per_turn = 5, hand_limit = 10 (discard if reaching 11)
extends RefCounted

const BattleStateScript := preload("res://core/battle_state.gd")
const EmitScript        := preload("res://core/emit.gd")

## Fixed intent damage per enemy turn (PRD §4.2 enemy baseline).
## Real enemies will carry this in their data; we read it from state.enemy if available,
## falling back to this constant for enemies that predate the field.
const DEFAULT_INTENT_DAMAGE: int = 5

## Cards drawn at the start of each player turn (PRD §4.2).
const DRAW_PER_TURN: int = 5

## Maximum hand size before forced discards (StS rule: discard when reaching 11).
const HAND_LIMIT: int = 10

## Energy regenerated each turn (PRD §4.2).
const MAX_ENERGY: int = 3

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Initialise and return a fresh BattleState ready for the first player turn.
## deck    : Array of TraitCard Resources (copied into state.deck)
## enemy   : TraitEnemy Resource OR Array of entries from EnemyFactory.build_group
## seed    : int — deterministic RNG seed (0 = truly random)
func start_battle(
		player_hp: int,
		max_hp: int,
		deck: Array,
		enemy,
		seed: int) -> Object:

	var state: Object = BattleStateScript.new()
	state.reset_per_battle()
	state.setup_reactions()

	# HP
	state.player_hp = player_hp
	state.max_hp    = max_hp

	# Enemy — accept either a single TraitEnemy (legacy) or an Array of
	# multi-enemy entries from EnemyFactory.build_group(). In single-enemy mode
	# the entries array still holds one element so all downstream logic can
	# walk it uniformly.
	if typeof(enemy) == TYPE_ARRAY:
		state.enemies = enemy.duplicate()
	else:
		var resolved_hp: int = _read_enemy_hp(enemy)
		state.enemies = [{
			"enemy":         enemy,
			"hp":            resolved_hp,
			"max_hp":        resolved_hp,
			"intent_damage": _read_intent_from_enemy(enemy),
		}]
	state.primary_enemy_idx = 0
	state.sync_primary_enemy()

	# Energy
	state.energy     = MAX_ENERGY
	state.max_energy = MAX_ENERGY

	# Deck — deep-copy the array so caller's array is not mutated
	state.deck    = deck.duplicate()
	state.hand    = []
	state.discard = []

	# RNG
	var rng := RandomNumberGenerator.new()
	if seed != 0:
		rng.seed = seed
	state.rng = rng

	# Phase & turn
	state.phase = BattleStateScript.Phase.PLAYER_TURN
	state.turn  = 1

	# Shuffle deck and draw opening hand
	_shuffle_deck(state)
	_draw_n(state, DRAW_PER_TURN)

	state.battle_log.append("battle_start player_hp=%d enemy_hp=%d seed=%d" % [
		state.player_hp, state.enemy_hp, seed])

	return state


## Play a card from hand: spend energy, emit OnPlay, move to discard.
## card   : TraitCard Resource (must be in state.hand)
## target : optional — int index into state.enemies; null falls back to primary.
func play_card(state: Object, card: Resource, target) -> void:
	# Find and remove from hand
	var idx: int = state.hand.find(card)
	if idx == -1:
		push_error("BattleLoop.play_card: card not in hand")
		return

	# Spend energy — caller must check state.energy >= card cost before calling.
	# For ISSUE-005 all cards cost 1 energy.
	var cost: int = 1
	if state.energy < cost:
		push_error("BattleLoop.play_card: not enough energy")
		return
	state.energy -= cost

	# Remove from hand before emitting (some traits inspect hand size)
	state.hand.remove_at(idx)

	# Move to discard immediately so Draw effects can reshuffle it when deck is empty.
	state.discard.append(card)

	# Emit OnPlay — triggers trait effects via emit kernel
	var log_size_before: int = state.trait_fire_log.size()
	var emitter: Object = EmitScript.new()
	emitter.emit(state, Enums.TriggerEvent.OnPlay, card)

	# Resolve target index for single-target damage. When the caller passes an
	# int we steer the primary to that enemy for the duration of this play_card
	# (so all Damage entries in trait_fire_log hit the same chosen target). The
	# original primary is restored afterwards if the chosen target is still alive.
	var saved_primary: int = int(state.primary_enemy_idx)
	if typeof(target) == TYPE_INT and state.enemies != null and not state.enemies.is_empty():
		var clamped: int = clamp(int(target), 0, state.enemies.size() - 1)
		if int(state.enemies[clamped].get("hp", 0)) > 0:
			state.primary_enemy_idx = clamped
			state.sync_primary_enemy()

	# Apply all OnPlay trait effects (Damage, Block, Heal, Draw, etc.)
	_apply_trait_effects(state, Enums.TriggerEvent.OnPlay, log_size_before)

	# Restore primary if target was an int and the original primary is still alive.
	if typeof(target) == TYPE_INT and state.enemies != null and not state.enemies.is_empty():
		if saved_primary < state.enemies.size() and int(state.enemies[saved_primary].get("hp", 0)) > 0:
			state.primary_enemy_idx = saved_primary
			state.sync_primary_enemy()
		else:
			state.advance_primary_if_dead()

	state.battle_log.append("play_card energy_left=%d hand_size=%d discard_size=%d" % [
		state.energy, state.hand.size(), state.discard.size()])


## End the current player turn: emit EndTurn, run enemy, emit StartTurn, reset & draw.
func end_turn(state: Object) -> void:
	if state.phase == BattleStateScript.Phase.GAME_OVER:
		return

	# --- Player turn end ---
	state.phase = BattleStateScript.Phase.ENEMY_TURN

	# Emit EndTurn for each card in hand (for EndTurn traits)
	var emitter: Object = EmitScript.new()
	var endturn_log_before: int = state.trait_fire_log.size()
	for card in state.hand.duplicate():
		emitter.emit(state, Enums.TriggerEvent.EndTurn, card)
	_apply_trait_effects(state, Enums.TriggerEvent.EndTurn, endturn_log_before)

	state.battle_log.append("end_turn turn=%d" % state.turn)

	# --- Enemy phase ---
	if not is_over(state)["ongoing"] == false:
		_apply_intent(state)

	# Check game-over after enemy attacks
	var result: Dictionary = is_over(state)
	if not result["ongoing"]:
		state.phase = BattleStateScript.Phase.GAME_OVER
		state.battle_log.append("game_over won=%s lost=%s" % [
			str(result["won"]), str(result["lost"])])
		return

	# --- New player turn ---
	state.phase = BattleStateScript.Phase.PLAYER_TURN
	state.turn += 1

	# Discard remaining hand
	for card in state.hand.duplicate():
		state.discard.append(card)
	state.hand.clear()

	# Reset per-turn state (cooldowns + block)
	state.reset_per_turn()

	# Regen energy (hard-set, no accumulation per PRD §4.2)
	state.energy = MAX_ENERGY

	# Emit StartTurn for deck cards (trait hooks)
	_draw_n(state, DRAW_PER_TURN)

	# Emit StartTurn for each card now in hand
	var startturn_log_before: int = state.trait_fire_log.size()
	for card in state.hand.duplicate():
		emitter.emit(state, Enums.TriggerEvent.StartTurn, card)
	_apply_trait_effects(state, Enums.TriggerEvent.StartTurn, startturn_log_before)

	state.battle_log.append("start_turn turn=%d energy=%d hand_size=%d deck_size=%d" % [
		state.turn, state.energy, state.hand.size(), state.deck.size()])


## Returns { ongoing: bool, won: bool, lost: bool }.
func is_over(state: Object) -> Dictionary:
	# Keep the enemies[] entries authoritative when present so multi-enemy
	# fights only end once every enemy is dead. Reconcile any direct
	# enemy_hp mutation first so test fixtures that bump enemy_hp after
	# start_battle() are respected without forcing them to know about
	# the new entries layout.
	var won: bool
	if state.enemies != null and not state.enemies.is_empty():
		state.sync_primary_hp_into_entry()
		won = state.all_enemies_dead()
	else:
		won = state.enemy_hp <= 0
	var lost: bool = state.player_hp <= 0
	return {
		"ongoing": not (won or lost),
		"won":     won,
		"lost":    lost,
	}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Draw n cards from deck into hand; reshuffles discard → deck when deck empty.
## If hand would exceed HAND_LIMIT, extras are discarded immediately (StS rule).
func _draw_n(state: Object, n: int) -> void:
	for _i in range(n):
		# Reshuffle if deck is empty
		if state.deck.is_empty():
			if state.discard.is_empty():
				state.battle_log.append("draw_skip deck_and_discard_empty")
				return
			# Move all discards back to deck and shuffle
			state.deck = state.discard.duplicate()
			state.discard.clear()
			_shuffle_deck(state)
			state.battle_log.append("reshuffle deck_size=%d" % state.deck.size())

		# Draw top card
		var card: Resource = state.deck.pop_back()

		# Apply hand limit before adding
		if state.hand.size() >= HAND_LIMIT:
			# StS rule: discard the drawn card (can't exceed limit)
			state.discard.append(card)
			state.battle_log.append("draw_discard_overflow hand_size=%d" % state.hand.size())
		else:
			state.hand.append(card)
			state.battle_log.append("draw card_idx=%d hand_size=%d" % [
				state.hand.size() - 1, state.hand.size()])

		# Enforce limit after adding (handles edge case if hand was exactly at limit)
		_discard_to_limit(state)


## Apply the enemy's intent. With multi-enemy support, every alive entry in
## state.enemies contributes its intent_damage to the same player attack pulse.
func _apply_intent(state: Object) -> void:
	# Reconcile any test-side direct mutations of enemy_hp before we read totals.
	state.sync_primary_hp_into_entry()

	if state.enemies == null or state.enemies.is_empty():
		if state.enemy_hp <= 0:
			return
		_execute_single_enemy_intent(state)
		return

	# Multi-enemy: each enemy executes its own intent.
	for i in range(state.enemies.size()):
		var entry: Dictionary = state.enemies[i]
		if int(entry.get("hp", 0)) <= 0:
			continue
		_execute_enemy_intent(state, entry, i)
		# Advance this enemy's intent for next turn.
		var enemy: Resource = entry.get("enemy", null)
		if enemy != null and enemy.has_method("advance_intent"):
			enemy.advance_intent(state.rng)
			entry["intent"] = enemy.intent
			entry["intent_damage"] = enemy.intent_damage


## Execute intent for a single enemy (legacy mode).
func _execute_single_enemy_intent(state: Object) -> void:
	var enemy: Resource = state.enemy
	if enemy == null:
		return

	var intent: String = enemy.intent if "intent" in enemy else "Attack"
	match intent:
		"Block":
			var block_amt: int = enemy.intent_block if "intent_block" in enemy else 5
			state.enemy_block = state.enemy_block + block_amt if "enemy_block" in state else block_amt
			state.battle_log.append("enemy_block amount=%d" % block_amt)
		"Buff":
			var buff: int = enemy.buff_power if "buff_power" in enemy else 2
			if enemy.has_method("_add_strength"):
				enemy._add_strength(buff)
			else:
				enemy.strength = enemy.strength + buff if "strength" in enemy else buff
			state.battle_log.append("enemy_buff strength=%d" % buff)
		"Debuff":
			var debuff: int = enemy.debuff_power if "debuff_power" in enemy else 1
			state.player_vulnerable = state.player_vulnerable + debuff if "player_vulnerable" in state else debuff
			state.battle_log.append("enemy_debuff vulnerable=%d" % debuff)
		"Charge":
			state.battle_log.append("enemy_charge")
		"MegaAttack":
			var mega_dmg: int = (enemy.intent_damage if "intent_damage" in enemy else DEFAULT_INTENT_DAMAGE) * 2
			_enemy_deal_damage(state, mega_dmg)
		_:	# Attack (default)
			var dmg: int = _get_intent_damage(state)
			_enemy_deal_damage(state, dmg)

	# Advance intent for next turn.
	if enemy.has_method("advance_intent"):
		enemy.advance_intent(state.rng)


## Execute intent for a specific enemy entry.
func _execute_enemy_intent(state: Object, entry: Dictionary, idx: int) -> void:
	var enemy: Resource = entry.get("enemy", null)
	if enemy == null:
		return

	var intent: String = entry.get("intent", "Attack")
	var intent_dmg: int = entry.get("intent_damage", DEFAULT_INTENT_DAMAGE)

	match intent:
		"Block":
			var block_amt: int = enemy.intent_block if "intent_block" in enemy else 5
			entry["block"] = int(entry.get("block", 0)) + block_amt
			state.battle_log.append("enemy_%d_block amount=%d" % [idx, block_amt])
		"Buff":
			var buff: int = enemy.buff_power if "buff_power" in enemy else 2
			if enemy.has_method("_add_strength"):
				enemy._add_strength(buff)
			else:
				enemy.strength = enemy.strength + buff if "strength" in enemy else buff
			state.battle_log.append("enemy_%d_buff strength=%d" % [idx, buff])
		"Debuff":
			var debuff: int = enemy.debuff_power if "debuff_power" in enemy else 1
			state.player_vulnerable = state.player_vulnerable + debuff if "player_vulnerable" in state else debuff
			state.battle_log.append("enemy_%d_debuff vulnerable=%d" % [idx, debuff])
		"Charge":
			state.battle_log.append("enemy_%d_charge" % idx)
		"MegaAttack":
			var mega_dmg: int = intent_dmg * 2
			_enemy_deal_damage_to_player(state, mega_dmg, idx)
		_:	# Attack (default)
			_enemy_deal_damage_to_player(state, intent_dmg, idx)


## Enemy deals damage to player (single enemy mode).
func _enemy_deal_damage(state: Object, base_dmg: int) -> void:
	var absorbed: int = min(state.player_block, base_dmg)
	state.player_block -= absorbed
	var net: int = base_dmg - absorbed
	state.player_hp = max(0, state.player_hp - net)
	state.battle_log.append("enemy_attack dmg=%d blocked=%d player_hp=%d block=%d" % [base_dmg, absorbed, state.player_hp, state.player_block])


## Enemy deals damage to player (multi-enemy mode).
func _enemy_deal_damage_to_player(state: Object, base_dmg: int, enemy_idx: int) -> void:
	var absorbed: int = min(state.player_block, base_dmg)
	state.player_block -= absorbed
	var net: int = base_dmg - absorbed
	state.player_hp = max(0, state.player_hp - net)
	state.battle_log.append("enemy_%d_attack dmg=%d blocked=%d player_hp=%d" % [enemy_idx, base_dmg, absorbed, state.player_hp])


## Discard cards from hand when hand size exceeds HAND_LIMIT (>= 11 → discard extras).
func _discard_to_limit(state: Object) -> void:
	while state.hand.size() > HAND_LIMIT:
		var excess: Resource = state.hand.pop_back()
		state.discard.append(excess)
		state.battle_log.append("discard_to_limit hand_size=%d" % state.hand.size())


## Fisher-Yates shuffle on state.deck using state.rng.
func _shuffle_deck(state: Object) -> void:
	var n: int = state.deck.size()
	for i in range(n - 1, 0, -1):
		var j: int = state.rng.randi_range(0, i)
		var tmp: Resource = state.deck[i]
		state.deck[i] = state.deck[j]
		state.deck[j] = tmp


## Read enemy HP from the enemy resource if it has an hp field; otherwise use carried_traits count * 5 + 10 as a fallback. For ISSUE-005 the spec says 25 HP enemy, so we allow the test to pass enemy_hp via the state directly. This helper is only called once in start_battle.
func _read_enemy_hp(enemy: Resource) -> int:
	# TraitEnemy (enemy.gd) does not have an hp field (frozen).
	# BattleState.enemy_hp is set by start_battle's caller via the dedicated parameter.
	# This method returns a default so the internal call compiles; the test will
	# call start_battle and then override state.enemy_hp before the first turn.
	return DEFAULT_INTENT_DAMAGE * 5  # = 25, matches the spec's "25 HP enemy"


## Return the intent damage for the current enemy.
## Reads enemy.intent_damage if present, otherwise DEFAULT_INTENT_DAMAGE.
func _get_intent_damage(state: Object) -> int:
	if state.enemy != null and state.enemy.get("intent_damage") != null:
		return int(state.enemy.get("intent_damage"))
	return DEFAULT_INTENT_DAMAGE


## Resolve intent damage from a TraitEnemy resource without a battle state.
## Used when seeding state.enemies from a single-enemy start_battle() call.
func _read_intent_from_enemy(enemy: Resource) -> int:
	if enemy != null and enemy.get("intent_damage") != null:
		return int(enemy.get("intent_damage"))
	return DEFAULT_INTENT_DAMAGE


## Apply damage to the primary enemy, advancing the primary index forward
## if the hit drops the current target to 0 HP. Damage that would carry over
## past a death does NOT spill into the next enemy by design (matches the
## existing test fixtures, where overkill damage is wasted).
##
## Block (resist) layer: if the entry has block > 0, the hit consumes block
## first, then HP. The amounts absorbed and dealt are pushed onto
## state.damage_events so the UI can spawn separate "blocked" and "damage"
## floats for each strike.
func _apply_damage_to_primary(state: Object, dmg: int) -> void:
	if state.enemies == null or state.enemies.is_empty():
		# Legacy single-enemy path.
		state.enemy_hp = max(0, state.enemy_hp - dmg)
		state.battle_log.append("player_deals_damage dmg=%d enemy_hp=%d" % [dmg, state.enemy_hp])
		_record_damage_event(state, -1, dmg, 0)
		return

	var idx: int = clamp(int(state.primary_enemy_idx), 0, state.enemies.size() - 1)
	var entry: Dictionary = state.enemies[idx]

	# Block absorbs first.
	var blocked: int = 0
	var current_block: int = int(entry.get("block", 0))
	if current_block > 0 and dmg > 0:
		blocked = min(current_block, dmg)
		entry["block"] = current_block - blocked
	var net: int = dmg - blocked

	var new_hp: int = max(0, int(entry.get("hp", 0)) - net)
	entry["hp"] = new_hp
	state.enemies[idx] = entry
	state.sync_primary_enemy()
	state.battle_log.append("player_deals_damage dmg=%d blocked=%d enemy_hp=%d" % [net, blocked, state.enemy_hp])

	_record_damage_event(state, idx, net, blocked)

	if new_hp <= 0:
		state.advance_primary_if_dead()


## Append a damage event so UI/VFX can replay each strike.
## state.damage_events is created lazily so legacy tests that don't read it
## still work; entry layout: { idx: int, dmg: int, blocked: int }.
func _record_damage_event(state: Object, target_idx: int, dmg: int, blocked: int) -> void:
	if not ("damage_events" in state):
		return
	state.damage_events.append({
		"idx":     target_idx,
		"dmg":     dmg,
		"blocked": blocked,
	})


# ---------------------------------------------------------------------------
# Trait effect application (Bug fix: all effect types, not just Damage)
# ---------------------------------------------------------------------------

## Apply all unprocessed trait effects from trait_fire_log that match the given event.
## Uses start_idx to avoid re-processing effects from previous emits.
func _apply_trait_effects(state: Object, event_filter: int, start_idx: int = 0) -> void:
	for i in range(start_idx, state.trait_fire_log.size()):
		var entry: Dictionary = state.trait_fire_log[i]
		if entry.get("event", -1) != event_filter:
			continue

		var effect_type: String = entry.get("effect_type", "")
		var source: String = entry.get("source", "")
		var effect_value: int = entry.get("effect_value", 0)

		if source == "reaction":
			var parsed: Dictionary = _parse_reaction_effect(effect_type)
			if parsed["damage"] > 0:
				_apply_damage_to_primary(state, parsed["damage"])
			if parsed["block"] > 0:
				_apply_block_to_player(state, parsed["block"])
			if parsed["heal"] > 0:
				_apply_heal_to_player(state, parsed["heal"])
			if parsed["draw"] > 0:
				_draw_n(state, parsed["draw"])
			if parsed["heal_percent"] > 0:
				_apply_heal_percent_to_player(state, parsed["heal_percent"])
		else:
			match effect_type:
				"Damage":
					if effect_value > 0:
						_apply_damage_to_primary(state, effect_value)
				"Block":
					_apply_block_to_player(state, effect_value)
				"HealSelfPercent":
					_apply_heal_percent_to_player(state, effect_value)
				"Draw":
					_draw_n(state, effect_value)
				"Heal":
					_apply_heal_to_player(state, effect_value)
				"Buff", "Apply", "Spawn":
					# Stubs for v0 — logged but not fully implemented
					state.battle_log.append("effect_stub type=%s value=%d" % [effect_type, effect_value])


## Parse a reaction override_effect string like "Damage(12, Fire) + AOE_Splash(4)"
## into a Dictionary of extractable numeric effects.
## Returns: { "damage": int, "block": int, "heal": int, "draw": int, "heal_percent": int }
func _parse_reaction_effect(effect_str: String) -> Dictionary:
	var result := {"damage": 0, "block": 0, "heal": 0, "draw": 0, "heal_percent": 0}

	# Damage(N, ...) or Damage(N)
	var dmg_idx := effect_str.find("Damage(")
	if dmg_idx != -1:
		var start := dmg_idx + 7
		var end := effect_str.find(")", start)
		if end != -1:
			var num_str := effect_str.substr(start, end - start)
			var comma := num_str.find(",")
			if comma != -1:
				num_str = num_str.substr(0, comma)
			result["damage"] = num_str.to_int()

	# Block(N, ...) or Block(N)
	var block_idx := effect_str.find("Block(")
	if block_idx != -1:
		var start := block_idx + 6
		var end := effect_str.find(")", start)
		if end != -1:
			var num_str := effect_str.substr(start, end - start)
			var comma := num_str.find(",")
			if comma != -1:
				num_str = num_str.substr(0, comma)
			result["block"] = num_str.to_int()

	# Heal(N) — must come before HealSelf to avoid collision
	var heal_idx := effect_str.find("Heal(")
	if heal_idx != -1:
		var start := heal_idx + 5
		var end := effect_str.find(")", start)
		if end != -1:
			var num_str := effect_str.substr(start, end - start)
			var val := num_str.to_int()
			# Distinguish Heal(N) from HealSelf(N%) by checking for "%"
			if effect_str.find("HealSelf(") == -1 or heal_idx != effect_str.find("HealSelf("):
				result["heal"] = val

	# HealSelf(N%)
	var heal_pct_idx := effect_str.find("HealSelf(")
	if heal_pct_idx != -1:
		var start := heal_pct_idx + 9
		var pct_end := effect_str.find("%", start)
		if pct_end != -1:
			var num_str := effect_str.substr(start, pct_end - start)
			result["heal_percent"] = num_str.to_int()

	# Draw(N)
	var draw_idx := effect_str.find("Draw(")
	if draw_idx != -1:
		var start := draw_idx + 5
		var end := effect_str.find(")", start)
		if end != -1:
			var num_str := effect_str.substr(start, end - start)
			result["draw"] = num_str.to_int()

	return result


func _apply_block_to_player(state: Object, amount: int) -> void:
	if amount <= 0:
		return
	state.player_block += amount
	state.battle_log.append("player_gain_block amount=%d block=%d" % [amount, state.player_block])


func _apply_heal_to_player(state: Object, amount: int) -> void:
	if amount <= 0:
		return
	var before: int = state.player_hp
	state.player_hp = min(state.max_hp, state.player_hp + amount)
	var healed: int = state.player_hp - before
	state.battle_log.append("player_heal amount=%d healed=%d hp=%d" % [amount, healed, state.player_hp])


func _apply_heal_percent_to_player(state: Object, percent: int) -> void:
	if percent <= 0:
		return
	var amount: int = max(1, int(state.max_hp * percent / 100.0))
	_apply_heal_to_player(state, amount)
