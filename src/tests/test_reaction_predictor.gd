## ISSUE-014a — Tests for reaction_predictor diff logic.
## Verifies before/after/added/removed/unchanged arrays for the camp
## drag-drop preview tooltip (PRD §3 US-09).
extends GdUnitTestSuite

const TraitScript    := preload("res://data/trait.gd")
const SlotScript     := preload("res://data/slot.gd")
const CardScript     := preload("res://data/card.gd")
const ReactionScript := preload("res://data/reaction.gd")
const Predictor      := preload("res://core/reaction_predictor.gd")

const ON_PLAY: int = 0
const ON_HIT: int = 4


func _trait(id: String) -> Resource:
	var t: Resource = TraitScript.new()
	t.id = id
	t.trigger = ON_PLAY
	t.effect_type = "Damage"
	t.effect_value = 1
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


func _reaction(id: String, watch: Array, timing: int = ON_PLAY) -> Resource:
	var r: Resource = ReactionScript.new()
	r.id = id
	r.watch_for = watch
	r.timing = timing
	r.override_effect = "Damage(12, Fire)"
	return r


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_diff_when_no_reactions_match() -> void:
	var p: Object = Predictor.new()
	var card: Resource = _card(_trait("alpha"), null, null)
	var newt: Resource = _trait("beta")
	var rx: Array = [_reaction("fire_oil", ["flame_brand", "oil_slick"])]

	var d: Dictionary = p.diff_for_mount(card, 1, newt, rx)
	assert_int(d["before"].size()).is_equal(0)
	assert_int(d["after"].size()).is_equal(0)
	assert_int(d["added"].size()).is_equal(0)
	assert_int(d["removed"].size()).is_equal(0)


func test_diff_added_reaction_when_mount_completes_pair() -> void:
	# Card has flame_brand only; mounting oil_slick triggers fire_oil_explosion.
	var p: Object = Predictor.new()
	var card: Resource = _card(_trait("flame_brand"), null, null)
	var newt: Resource = _trait("oil_slick")
	var rx: Array = [_reaction("fire_oil_explosion", ["flame_brand", "oil_slick"])]

	var d: Dictionary = p.diff_for_mount(card, 1, newt, rx)
	assert_array(d["added"]).contains_exactly(["fire_oil_explosion"])
	assert_int(d["removed"].size()).is_equal(0)
	assert_array(d["after"]).contains_exactly(["fire_oil_explosion"])


func test_diff_removed_reaction_when_mount_breaks_pair() -> void:
	# Card has flame_brand + oil_slick → fire_oil active.
	# Replacing oil_slick (slot 1) with charcoal breaks the pair.
	var p: Object = Predictor.new()
	var card: Resource = _card(_trait("flame_brand"), _trait("oil_slick"), null)
	var newt: Resource = _trait("charcoal")
	var rx: Array = [_reaction("fire_oil_explosion", ["flame_brand", "oil_slick"])]

	var d: Dictionary = p.diff_for_mount(card, 1, newt, rx)
	assert_array(d["removed"]).contains_exactly(["fire_oil_explosion"])
	assert_int(d["added"].size()).is_equal(0)
	assert_int(d["after"].size()).is_equal(0)


func test_diff_unchanged_reaction_persists() -> void:
	# Card has flame_brand + oil_slick → fire_oil already active.
	# Mount a third trait into slot 2 that doesn't affect fire_oil.
	var p: Object = Predictor.new()
	var card: Resource = _card(_trait("flame_brand"), _trait("oil_slick"), null)
	var newt: Resource = _trait("filler")
	var rx: Array = [_reaction("fire_oil_explosion", ["flame_brand", "oil_slick"])]

	var d: Dictionary = p.diff_for_mount(card, 2, newt, rx)
	assert_array(d["unchanged"]).contains_exactly(["fire_oil_explosion"])
	assert_int(d["added"].size()).is_equal(0)
	assert_int(d["removed"].size()).is_equal(0)


func test_diff_swap_one_reaction_for_another() -> void:
	# Card: flame_brand + oil_slick → fire_oil active.
	# Replace oil_slick with void_essence → triggers a different reaction.
	var p: Object = Predictor.new()
	var card: Resource = _card(_trait("flame_brand"), _trait("oil_slick"), null)
	var newt: Resource = _trait("void_essence")
	var rx: Array = [
		_reaction("fire_oil_explosion", ["flame_brand", "oil_slick"]),
		_reaction("flame_void_implosion", ["flame_brand", "void_essence"]),
	]

	var d: Dictionary = p.diff_for_mount(card, 1, newt, rx)
	assert_array(d["added"]).contains_exactly(["flame_void_implosion"])
	assert_array(d["removed"]).contains_exactly(["fire_oil_explosion"])


func test_diff_filters_by_event_timing() -> void:
	# Same trait pair, but reaction timing is OnHit; OnPlay diff sees nothing.
	var p: Object = Predictor.new()
	var card: Resource = _card(_trait("flame_brand"), null, null)
	var newt: Resource = _trait("oil_slick")
	var rx: Array = [_reaction("fire_oil_onhit", ["flame_brand", "oil_slick"], ON_HIT)]

	var on_play: Dictionary = p.diff_for_mount(card, 1, newt, rx, ON_PLAY)
	assert_int(on_play["added"].size()).is_equal(0)

	var on_hit: Dictionary = p.diff_for_mount(card, 1, newt, rx, ON_HIT)
	assert_array(on_hit["added"]).contains_exactly(["fire_oil_onhit"])


func test_diff_for_dismantle_removes_active_reaction() -> void:
	# Slot 1 trait is half of an active pair; dismantling breaks it.
	var p: Object = Predictor.new()
	var card: Resource = _card(_trait("flame_brand"), _trait("oil_slick"), null)
	var rx: Array = [_reaction("fire_oil_explosion", ["flame_brand", "oil_slick"])]

	var d: Dictionary = p.diff_for_dismantle(card, 1, rx)
	assert_array(d["removed"]).contains_exactly(["fire_oil_explosion"])


func test_diff_invalid_card_returns_empty() -> void:
	var p: Object = Predictor.new()
	var rx: Array = [_reaction("any", ["a", "b"])]
	var d: Dictionary = p.diff_for_mount(null, 1, _trait("a"), rx)
	assert_int(d["before"].size()).is_equal(0)
	assert_int(d["after"].size()).is_equal(0)


func test_diff_event_negative_one_disables_timing_filter() -> void:
	var p: Object = Predictor.new()
	var card: Resource = _card(_trait("flame_brand"), null, null)
	var newt: Resource = _trait("oil_slick")
	var rx: Array = [
		_reaction("fire_oil_onplay", ["flame_brand", "oil_slick"], ON_PLAY),
		_reaction("fire_oil_onhit",  ["flame_brand", "oil_slick"], ON_HIT),
	]

	var d: Dictionary = p.diff_for_mount(card, 1, newt, rx, -1)
	assert_int(d["added"].size()).is_equal(2)
