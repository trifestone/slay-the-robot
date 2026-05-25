## GdUnit4 test suite for ISSUE-008: run drop integration.
extends GdUnitTestSuite

const TraitScript  := preload("res://data/trait.gd")
const SlotScript   := preload("res://data/slot.gd")
const CardScript   := preload("res://data/card.gd")
const RunScript    := preload("res://core/run.gd")

func _make_trait(tid: String, trigger_int: int, etype: String, evalue: int) -> Resource:
	var t: Resource = TraitScript.new()
	t.id              = tid
	t.trigger         = trigger_int
	t.effect_type     = etype
	t.effect_value    = evalue
	t.cooldown_per_turn = -1
	t.axis_timing     = trigger_int
	t.axis_scope      = 0
	t.axis_school     = 0
	t.rarity          = 0
	t.removable       = true
	t.flavor          = ""
	return t


func _make_card(t0: Resource, t1, t2) -> Resource:
	var s0: Resource = SlotScript.new()
	s0.index     = 0
	s0.trait_ref = t0
	s0.locked    = true
	s0.post_load()

	var s1: Resource = SlotScript.new()
	s1.index     = 1
	s1.trait_ref = t1
	s1.locked    = false
	s1.post_load()

	var s2: Resource = SlotScript.new()
	s2.index     = 2
	s2.trait_ref = t2
	s2.locked    = false
	s2.post_load()

	var card: Resource = CardScript.new()
	card.slots = [s0, s1, s2]
	return card


func _make_sample_deck() -> Array:
	var flame_trait: Resource = _make_trait("flame_brand", 0, "Damage", 4)
	var basic_trait: Resource = _make_trait("basic_strike", 0, "Damage", 2)
	var deck: Array = []
	deck.append(_make_card(flame_trait, null, null))
	for _i in range(4):
		deck.append(_make_card(basic_trait, null, null))
	return deck


func test_run_drop_inventory_populated() -> void:
	var run: Object = RunScript.new()
	var deck: Array = _make_sample_deck()
	var rs: Dictionary = run.start_run(42, deck, 80)
	run.play_full_run(rs)

	# At least one battle won means traits_collected > 0
	assert_int(rs["traits_collected"].size()).is_greater(0)

	# inventory respects CAPACITY=5
	assert_int(rs["inventory"].size()).is_greater(0)
	assert_int(rs["inventory"].size()).is_less_equal(5)
