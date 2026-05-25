## ISSUE-012a — Tests for HoverPreview pure-logic resolver.
## Verifies preview computes step list & damage estimate WITHOUT mutating state.
extends GdUnitTestSuite

const TraitScript      := preload("res://data/trait.gd")
const SlotScript       := preload("res://data/slot.gd")
const CardScript       := preload("res://data/card.gd")
const ReactionScript   := preload("res://data/reaction.gd")
const BattleStateScript := preload("res://core/battle_state.gd")
const HoverPreview     := preload("res://ui/hover_preview.gd")

const ON_PLAY: int = 0


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _trait(id: String, trigger: int, effect: String, value: int = 0) -> Resource:
	var t: Resource = TraitScript.new()
	t.id = id
	t.trigger = trigger
	t.effect_type = effect
	t.effect_value = value
	t.cooldown_per_turn = -1
	return t


func _slot(idx: int, t: Resource, locked: bool) -> Resource:
	var s: Resource = SlotScript.new()
	s.index = idx
	s.trait_ref = t
	s.locked = locked
	s.post_load()
	return s


func _card(t0: Resource, t1: Resource, t2: Resource) -> Resource:
	var c: Resource = CardScript.new()
	c.slots = [_slot(0, t0, true), _slot(1, t1, false), _slot(2, t2, false)]
	return c


func _state() -> Object:
	var s: Object = BattleStateScript.new()
	s.reset_per_battle()
	return s


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_resolve_returns_steps_per_slot() -> void:
	var preview: Object = HoverPreview.new()
	var t0: Resource = _trait("alpha", ON_PLAY, "Damage", 4)
	var t1: Resource = _trait("beta",  ON_PLAY, "Block", 2)
	var t2: Resource = _trait("gamma", ON_PLAY, "Draw",  1)
	var card: Resource = _card(t0, t1, t2)
	var state: Object = _state()

	var result: Dictionary = preview.resolve(state, card, ON_PLAY)
	assert_int(result["steps"].size()).is_equal(3)
	assert_str(result["steps"][0]["source_trait_id"]).is_equal("alpha")
	assert_str(result["steps"][1]["source_trait_id"]).is_equal("beta")
	assert_str(result["steps"][2]["source_trait_id"]).is_equal("gamma")


func test_resolve_does_not_mutate_state_log() -> void:
	# US-04 hard requirement: hover preview must NOT change real state.
	var preview: Object = HoverPreview.new()
	var t0: Resource = _trait("alpha", ON_PLAY, "Damage", 5)
	var card: Resource = _card(t0, null, null)
	var state: Object = _state()

	var before_log: int = state.trait_fire_log.size()
	var before_depth: int = state.fire_depth
	var before_cd: int = state.cooldown_table.size()
	preview.resolve(state, card, ON_PLAY)
	assert_int(state.trait_fire_log.size()).is_equal(before_log)
	assert_int(state.fire_depth).is_equal(before_depth)
	assert_int(state.cooldown_table.size()).is_equal(before_cd)


func test_damage_estimate_sums_damage_steps() -> void:
	var preview: Object = HoverPreview.new()
	var t0: Resource = _trait("a", ON_PLAY, "Damage", 4)
	var t1: Resource = _trait("b", ON_PLAY, "Damage", 3)
	var t2: Resource = _trait("c", ON_PLAY, "Block",  2)
	var card: Resource = _card(t0, t1, t2)

	var result: Dictionary = preview.resolve(_state(), card, ON_PLAY)
	assert_int(result["damage_estimate"]).is_equal(7)


func test_reaction_override_appears_as_first_step() -> void:
	# When a reaction matches, only the override step should be present.
	var preview: Object = HoverPreview.new()
	var t0: Resource = _trait("flame_brand", ON_PLAY, "Damage", 4)
	var t1: Resource = _trait("oil_slick",   ON_PLAY, "Apply", 1)
	var card: Resource = _card(t0, t1, null)

	var rx: Resource = ReactionScript.new()
	rx.id = "fire_oil_explosion"
	rx.watch_for = ["flame_brand", "oil_slick"]
	rx.timing = ON_PLAY
	rx.override_effect = "Damage(12, Fire) + AOE_Splash(4)"

	var state: Object = _state()
	state.reactions = [rx]

	var result: Dictionary = preview.resolve(state, card, ON_PLAY)
	assert_int(result["steps"].size()).is_equal(1)
	assert_bool(result["steps"][0]["is_reaction"]).is_true()
	assert_array(result["reaction_overrides"]).contains_exactly(
		["Damage(12, Fire) + AOE_Splash(4)"]
	)
	# Damage estimate parses 12 from the override
	assert_int(result["damage_estimate"]).is_equal(12)


func test_label_format_for_trait() -> void:
	var preview: Object = HoverPreview.new()
	var t0: Resource = _trait("alpha", ON_PLAY, "Damage", 4)
	var card: Resource = _card(t0, null, null)
	var result: Dictionary = preview.resolve(_state(), card, ON_PLAY)
	assert_str(result["steps"][0]["label"]).contains("alpha")
	assert_str(result["steps"][0]["label"]).contains("Damage")
	assert_str(result["steps"][0]["label"]).contains("4")


func test_label_format_for_reaction() -> void:
	var preview: Object = HoverPreview.new()
	var t0: Resource = _trait("flame_brand", ON_PLAY, "Damage", 4)
	var t1: Resource = _trait("oil_slick",   ON_PLAY, "Apply", 1)
	var card: Resource = _card(t0, t1, null)

	var rx: Resource = ReactionScript.new()
	rx.id = "fire_oil_explosion"
	rx.watch_for = ["flame_brand", "oil_slick"]
	rx.timing = ON_PLAY
	rx.override_effect = "Damage(12, Fire)"

	var state: Object = _state()
	state.reactions = [rx]

	var result: Dictionary = preview.resolve(state, card, ON_PLAY)
	assert_str(result["steps"][0]["label"]).contains("★")
	assert_str(result["steps"][0]["label"]).contains("Damage(12, Fire)")


func test_event_mismatch_returns_empty_steps() -> void:
	var preview: Object = HoverPreview.new()
	# trigger=4 (OnHit) — won't fire for OnPlay preview
	var t0: Resource = _trait("on_hit_only", 4, "Damage", 5)
	var card: Resource = _card(t0, null, null)
	var result: Dictionary = preview.resolve(_state(), card, ON_PLAY)
	assert_int(result["steps"].size()).is_equal(0)
	assert_int(result["damage_estimate"]).is_equal(0)


func test_resolve_preserves_existing_log_entries() -> void:
	# Pre-existing log entries must be present and unchanged after preview.
	var preview: Object = HoverPreview.new()
	var t0: Resource = _trait("alpha", ON_PLAY, "Damage", 4)
	var card: Resource = _card(t0, null, null)
	var state: Object = _state()
	state.trait_fire_log.append({"source": "trait", "id": "stale", "depth": 0})

	preview.resolve(state, card, ON_PLAY)
	assert_int(state.trait_fire_log.size()).is_equal(1)
	assert_str(state.trait_fire_log[0]["id"]).is_equal("stale")


func test_null_card_returns_empty() -> void:
	var preview: Object = HoverPreview.new()
	var result: Dictionary = preview.resolve(_state(), null, ON_PLAY)
	assert_int(result["steps"].size()).is_equal(0)
	assert_int(result["damage_estimate"]).is_equal(0)
