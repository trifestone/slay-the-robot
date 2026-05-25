## emit() — trigger-stack kernel (ADR-001 §决策 1-3).
##
## Usage:
##   var emitter = preload("res://core/emit.gd").new()
##   emitter.emit(state, Enums.TriggerEvent.OnPlay, card)
##
## state   : BattleState instance (core/battle_state.gd)
## event   : int — Enums.TriggerEvent value
## card    : TraitCard Resource (data/card.gd)
##
## Rules (verbatim from ADR-001):
##   1. Reactions checked first: timing == event AND all watch_for ids on card
##      → apply_effect(reaction.override_effect) → return (no downstream, no bubble)
##   2. Slot 0 → 1 → 2 in order; skip if trait.trigger != event or cooldown exceeded
##   3. After each slot fire: if fire_depth < 2, increment depth, recurse with
##      OnTraitFired, then decrement depth.
extends RefCounted

# OnTraitFired int value — matches Enums.TriggerEvent.OnTraitFired = 7
const ON_TRAIT_FIRED: int = 7


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Main entry point.  state is a BattleState; card is a TraitCard Resource.
func emit(state: Object, event: int, card: Resource) -> void:
	# -----------------------------------------------------------------------
	# ADR-001 §决策 1: Special reaction takes highest priority.
	# Condition: reaction.timing == event AND every id in watch_for is present on card.
	# -----------------------------------------------------------------------
	for reaction in state.reactions:
		if reaction.timing == event and _card_has_all(card, reaction.watch_for):
			apply_effect(state, reaction.override_effect, "", card)
			return  # skip all downstream traits; no OnTraitFired bubble

	# -----------------------------------------------------------------------
	# ADR-001 §决策 2: Regular slot traversal, slot index 0 → 1 → 2.
	# -----------------------------------------------------------------------
	for slot_idx in range(3):
		var trait_res: Resource = card.get_trait_at(slot_idx)
		if trait_res == null:
			continue
		if trait_res.trigger != event:
			continue
		if _cooldown_exceeded(state, card, trait_res):
			continue

		# Record the fire and apply stub effect.
		_increment_cooldown(state, card, trait_res)
		apply_effect(state, trait_res.effect_type, trait_res.id, card,
				trait_res.effect_value, event, state.fire_depth)

		# -------------------------------------------------------------------
		# ADR-001 §决策 3: OnTraitFired chain — depth <= 2.
		# depth 0 = original emit, depth 1 = first bubble, depth 2 = second.
		# depth >= 2 means the NEXT call would be depth 3 → blocked silently.
		# -------------------------------------------------------------------
		if state.fire_depth < 2:
			state.fire_depth += 1
			emit(state, ON_TRAIT_FIRED, card)
			state.fire_depth -= 1
		# else: depth >= 2, silently skip (no exception, no log entry for depth 3+)


# ---------------------------------------------------------------------------
# Effect stub (ISSUE-005 will expand this)
# ---------------------------------------------------------------------------

## Stub effect application.  Pushes a log entry into state.trait_fire_log.
## For reactions the source_trait_id is "" and effect_type is the raw override string.
## For traits effect_type is the Trait.effect_type string.
func apply_effect(
		state: Object,
		effect_type: String,
		source_trait_id: String,
		card: Resource,
		effect_value: int = 0,
		event: int = -1,
		depth: int = -1) -> void:

	state.trait_fire_log.append({
		"source":          "reaction" if source_trait_id == "" else "trait",
		"id":              source_trait_id if source_trait_id != "" else effect_type,
		"card_iid":        card.get_instance_id(),
		"event":           event,
		"depth":           depth,
		"effect_type":     effect_type,
		"effect_value":    effect_value,
		"source_trait_id": source_trait_id,
	})


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Returns true when a trait's per-turn fire count has reached its limit.
## cooldown_per_turn == -1 means unlimited (no cap).
func _cooldown_exceeded(state: Object, card: Resource, trait_res: Resource) -> bool:
	if trait_res.cooldown_per_turn == -1:
		return false
	var key: String = "%d/%s" % [card.get_instance_id(), trait_res.id]
	var fired: int = state.cooldown_table.get(key, 0)
	return fired >= trait_res.cooldown_per_turn


## Increments the fire count for a (card, trait) pair in the cooldown table.
func _increment_cooldown(state: Object, card: Resource, trait_res: Resource) -> void:
	if trait_res.cooldown_per_turn == -1:
		return  # no-op for unlimited traits
	var key: String = "%d/%s" % [card.get_instance_id(), trait_res.id]
	state.cooldown_table[key] = state.cooldown_table.get(key, 0) + 1


## Returns true when every trait id in watch_for_ids is present on the card.
func _card_has_all(card: Resource, watch_for_ids: Array) -> bool:
	for tid in watch_for_ids:
		if not card.has_trait_id(tid):
			return false
	return true
